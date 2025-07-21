SEARCH_BASE_DIRS=("$HOME" "/" "$HOME/Code")
EXCLUDE_DIRS=("node_modules" ".git" "cache" ".cache" "log" "logs" ".next")
# tac: brew install coreutils / brew install fzf

function fzf-select-history() {
  local selected
  local entry_id

  # Create temporary file for history processing
  local tmpfile="/tmp/zsh_history_processed.$$"

  # Process history file to create numbered entries
  awk '
    /^: [0-9]{10,}:[01];/ {
      entry_num++
      cmd = substr($0, index($0, ";") + 1)
      display_cmd = cmd
      gsub(/__NEWLINE__/, " <NL> ", display_cmd)
      print entry_num "\t" NR "\t" cmd "\t" display_cmd
    }
  ' "$HISTFILE" > "$tmpfile"

  # Use fzf to select history
  selected=$(
    tac "$tmpfile" |
      awk -F'\t' '!seen[$3]++ {print $1 "\t" $3 "\t" $4}' |
      fzf --query "$LBUFFER" \
        --tiebreak=index \
        --reverse \
        --multi \
        --delimiter='\t' \
        --with-nth=3 \
        --preview 'echo -e "\033[90mCommand\033[0m";
                   echo {2} | sed "s/__NEWLINE__/\n/g";
                   echo "";
                   echo -e "\033[90mWrapped\033[0m";
                   echo {2} | sed "s/__NEWLINE__/\n/g" | fold -s -w $COLUMNS' \
        --bind "ctrl-x:execute-silent(
            entry_id={1}
            line_num=\$(awk -F'\t' -v id=\"\$entry_id\" '\$1 == id {print \$2; exit}' \"$tmpfile\")
            if [[ -n \"\$line_num\" ]]; then
              sed -i.bak \"\${line_num}d\" \"$HISTFILE\"
            fi
        )+reload(
            awk '
              /^: [0-9]{10,}:[01];/ {
                entry_num++
                cmd = substr(\$0, index(\$0, \";\") + 1)
                display_cmd = cmd
                gsub(/__NEWLINE__/, \" <NL> \", display_cmd)
                print entry_num \"\t\" NR \"\t\" cmd \"\t\" display_cmd
              }
            ' \"$HISTFILE\" > \"$tmpfile\"
            tac \"$tmpfile\" | awk -F'\t' '!seen[\$3]++ {print \$1 \"\t\" \$3 \"\t\" \$4}'
        )" \
        --bind "ctrl-q:execute-silent(
            echo {2} | sed 's/__NEWLINE__/\n/g' | pbcopy
        )"
  )

  # Clean up
  rm -f "$tmpfile"

  if [[ -n "$selected" ]]; then
    # Extract original command and convert __RETURN__ back to newlines
    local cmd=$(echo "$selected" | cut -f2 | sed 's/__NEWLINE__/\n/g')
    BUFFER="$cmd"
    CURSOR=$#BUFFER
    # zle accept-line
  fi
}
zle -N fzf-select-history

function incremental-find() {
  local max_depth="$1"

  for base_dir in "${SEARCH_BASE_DIRS[@]}"; do
    if [[ -d "$base_dir" ]]; then
      local prune_expr=()
      for exclude in "${EXCLUDE_DIRS[@]}"; do
        prune_expr+=(-name "$exclude" -o)
      done
      prune_expr=("${prune_expr[@]::-1}")
      stdbuf -oL find "$base_dir" -mindepth 1 -maxdepth "$max_depth" -type d \
        \( "${prune_expr[@]}" \) -prune -o -type d -print 2>/dev/null &
    fi
  done

  wait # Wait for find processes to finish
}

function fzf-combined-cdr-find() {
  rm -f /tmp/fzf-depth
  rm -f /tmp/fzf-cdr-list
  cdr_list=$(cdr -l | sed -E 's/^[0-9]+[[:space:]]+//')
  echo "2" >/tmp/fzf-depth
  echo "$cdr_list" >/tmp/fzf-cdr-list

  local base_dirs=""
  for dir in "${SEARCH_BASE_DIRS[@]}"; do
    base_dirs="${base_dirs} ${dir}"
  done
  base_dirs="${base_dirs:1}"

  local exclude_pattern=""
  for dir in "${EXCLUDE_DIRS[@]}"; do
    exclude_pattern="${exclude_pattern} -name \"${dir}\" -o"
  done
  exclude_pattern="${exclude_pattern% -o}"

  local FIND_PREFIX='find_cmd() {
    depth=$(cat /tmp/fzf-depth 2>/dev/null || echo 1)
    [[ $depth -lt 1 ]] && depth=1
    search_query={q}

    (cat /tmp/fzf-cdr-list
     for base_dir in '$base_dirs'; do
       if [[ -d "$base_dir" ]]; then
         find "$base_dir" -mindepth 1 -maxdepth $depth -type d \
           \( '$exclude_pattern' \) -prune -o -type d -print 2>/dev/null
       fi
     done)
  }'

  selected=$(
    fzf --print-query --no-sort --reverse \
      --bind "start:reload($FIND_PREFIX; find_cmd)+unbind(ctrl-b)" \
      --bind "change:reload:sleep 0.1; $FIND_PREFIX; find_cmd || true" \
      --bind 'left:execute-silent(
      depth=$(cat /tmp/fzf-depth);
      new_depth=$((depth - 1));
      [[ $new_depth -lt 1 ]] && new_depth=1;
      echo $new_depth > /tmp/fzf-depth
    )+reload('$FIND_PREFIX'; find_cmd || true)+refresh-preview' \
      --bind 'right:execute-silent(
      depth=$(cat /tmp/fzf-depth);
      new_depth=$((depth + 1));
      echo $new_depth > /tmp/fzf-depth
    )+reload('$FIND_PREFIX'; find_cmd || true)+refresh-preview' \
      --color "hl:-1:underline,hl+:-1:underline:reverse" \
      --preview 'echo "{}" | fold -s -w $COLUMNS; echo -e "Current Depth(← →): $(cat /tmp/fzf-depth 2>/dev/null)\n\n{}"' \
      --preview-window 'down,2,border-top' \
      --bind 'enter:accept' \
      --bind 'esc:abort'
  )

  if [[ $? -eq 130 ]]; then # Esc or Ctrl-C is pressed
    return
  fi

  query=$(echo "$selected" | head -n 1) # First line is the query
  selected_dir=$(echo "$selected" | tail -n +2)

  if [[ -n "$selected_dir" && "$selected_dir" != "Searching directories..."* ]]; then
    BUFFER="cd $selected_dir"
    zle accept-line
    return
  fi
}
zle -N fzf-combined-cdr-find
