SEARCH_BASE_DIRS=("$HOME" "/" "$HOME/Code")
EXCLUDE_DIRS=("node_modules" ".git" "cache" ".cache" "log" "logs" ".next")
# gtac: brew install coreutils / brew install fzf

function fzf-select-history() {
  local selected
  local entry_id
  
  # Create temporary file for history processing
  local tmpfile="/tmp/zsh_history_processed.$$"
  
  # Process history file to create numbered entries
  # Each entry gets a unique ID based on line numbers
  awk '
    BEGIN { 
      entry_num = 0
      cmd = ""
      start_line = 0
      in_entry = 0
    }
    /^: [0-9]{10,}:[01];/ {
      if (in_entry && cmd != "") {
        # Output previous entry
        gsub(/\\/, "\\\\", cmd)  # Escape backslashes
        gsub(/\t/, "\\t", cmd)   # Escape tabs
        print entry_num "\t" start_line "\t" NR-1 "\t" cmd
      }
      # Start new entry
      entry_num++
      start_line = NR
      cmd = substr($0, index($0, ";") + 1)
      in_entry = 1
    }
    !/^: [0-9]{10,}:[01];/ {
      if (in_entry) {
        cmd = cmd "\n" $0
      }
    }
    END {
      if (in_entry && cmd != "") {
        gsub(/\\/, "\\\\", cmd)
        gsub(/\t/, "\\t", cmd)
        print entry_num "\t" start_line "\t" NR "\t" cmd
      }
    }
  ' "$HISTFILE" > "$tmpfile"
  
  # Use fzf to select history
  selected=$(
    tac "$tmpfile" | 
    awk -F'\t' '!seen[$4]++ {print $1 "\t" $4}' |
    fzf --query "$LBUFFER" \
        --reverse \
        --multi \
        --delimiter='\t' \
        --with-nth=2 \
        --preview 'echo -e "\033[90mCommand\033[0m";
                   echo {2} | sed "s/\\\\n/\n/g";
                   echo "";
                   echo -e "\033[90mWrapped\033[0m";
                   echo {2} | sed "s/\\\\n/\n/g" | fold -s -w $COLUMNS' \
        --bind "ctrl-x:execute-silent(
            entry_id={1}
            # Find the line range for this entry
            line_info=\$(awk -F'\t' -v id=\"\$entry_id\" '\$1 == id {print \$2 \"\t\" \$3; exit}' \"$tmpfile\")
            start_line=\$(echo \"\$line_info\" | cut -f1)
            end_line=\$(echo \"\$line_info\" | cut -f2)
            
            # Delete the entry from history
            if [[ -n \"\$start_line\" && -n \"\$end_line\" ]]; then
              sed -i.bak \"\${start_line},\${end_line}d\" \"$HISTFILE\"
            fi
        )+reload(
            # Reprocess history file
            awk '
              BEGIN { 
                entry_num = 0
                cmd = \"\"
                start_line = 0
                in_entry = 0
              }
              /^: [0-9]{10,}:[01];/ {
                if (in_entry && cmd != \"\") {
                  gsub(/\\\\/, \"\\\\\\\\\", cmd)
                  gsub(/\t/, \"\\\\t\", cmd)
                  print entry_num \"\t\" start_line \"\t\" NR-1 \"\t\" cmd
                }
                entry_num++
                start_line = NR
                cmd = substr(\$0, index(\$0, \";\") + 1)
                in_entry = 1
              }
              !/^: [0-9]{10,}:[01];/ {
                if (in_entry) {
                  cmd = cmd \"\\n\" \$0
                }
              }
              END {
                if (in_entry && cmd != \"\") {
                  gsub(/\\\\/, \"\\\\\\\\\", cmd)
                  gsub(/\t/, \"\\\\t\", cmd)
                  print entry_num \"\t\" start_line \"\t\" NR \"\t\" cmd
                }
              }
            ' \"$HISTFILE\" > \"$tmpfile\"
            tac \"$tmpfile\" | awk -F'\t' '!seen[\$4]++ {print \$1 \"\t\" \$4}'
        )" \
        --bind "ctrl-q:execute-silent(
            echo {2} | sed 's/\\\\n/\n/g' | pbcopy
        )"
  )
  
  # Clean up
  rm -f "$tmpfile"
  
  if [[ -n "$selected" ]]; then
    # Extract command and unescape
    local cmd=$(echo "$selected" | cut -f2 | sed 's/\\n/\n/g; s/\\t/\t/g; s/\\\\/\\/g')
    BUFFER="$cmd"
    CURSOR=$#BUFFER
    zle accept-line
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
