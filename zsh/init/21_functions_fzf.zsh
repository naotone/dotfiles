SEARCH_BASE_DIRS=("$HOME" "/")
EXCLUDE_DIRS=("node_modules" ".git" "cache" ".cache" "log" "logs" ".next")
# gtac: brew install coreutils / brew install fzf

function fzf-select-history() {
  local cmd
  cmd=$(
    awk '
    BEGIN { cmd = ""; firstLine = ""; }
    /^: [0-9]{10,}:[01];/ {
      if (cmd != "") {
        if (firstLine == "") {
          firstLine = $0;
        }
        print cmd "\t" firstLine;
        cmd = "";
        firstLine = "";
     }
      firstLine = $0;
      cmd = substr($0, index($0, ";") + 1);
    }
    !/^: [0-9]{10,}:[01];/ {
      cmd = cmd "\\n" $0;
    }
    END {
      if (cmd != "") print cmd "\t" firstLine;
    }
  ' "$HISTFILE" |
      tac | awk -F"\t" '!seen[$1]++ && $2 != "" {print $0}' |
      fzf --query "$LBUFFER" --reverse --multi --delimiter="\t" --with-nth=1 \
        --preview "echo -e \"\033[90mCommand\033[0m\";
                   echo {1};
                   echo \"\";
                   echo -e \"\033[90mWrapped\033[0m\";
                   echo {1} | sed 's/\\\\n/\n/g' | fold -s -w $COLUMNS;
                  #  echo \"\";
                  #  echo -e \"\033[Fist Line\033[0m\";
                  #  echo {2};
                   " \
        --bind "ctrl-x:execute(
            # Debug info
            # echo \"=== Deleting entry ===\" > /tmp/fzf_history_debug.log
            # echo \"Command: {1}\" >> /tmp/fzf_history_debug.log
            # echo \"First Line: {2}\" >> /tmp/fzf_history_debug.log
            # echo \"=== Before deletion ===\" >> /tmp/fzf_history_debug.log
            # head -n 10 \"$HISTFILE\" >> /tmp/fzf_history_debug.log

            timestamp=$(date +%Y%m%d%H%M%S)
            tmpfile=\"/tmp/zsh_history.\$timestamp.tmp\"

            (awk -v target="{2}" '
              BEGIN {
                # print \"Target for deletion:  \"target >> \"/tmp/fzf_history_debug.log\"
                skip = 0;
              }
              /^: [0-9]{10,}:[01];/ {
                # print \"First Line: \"\$0 >> \"/tmp/fzf_history_debug.log\"
                # if (index(\$0, target) != 0) {
                if (\$0 == target){
                  # print \"Unmatched for deletion: \" \$0 >> \"/tmp/fzf_history_debug.log\"
                  skip = 1;
                } else {
                  # print \"Matched for deletion: \" \$0 >> \"/tmp/fzf_history_debug.log\"
                  skip = 0;
                  print;
                }
              }
              !/^: [0-9]{10,}:[01];/ {
                # print \"Deleting line: \"\$0 >> \"/tmp/fzf_history_debug.log\"
                if (!skip) print;
              }
            ' $HISTFILE > \$tmpfile && cp \$tmpfile $HISTFILE)

            # echo \"=== After deletion ===\" >> /tmp/fzf_history_debug.log
            # head -n 10 \"$HISTFILE\" >> /tmp/fzf_history_debug.log

        )+reload(awk '
          BEGIN { cmd = \"\"; firstLine = \"\"; }
          /^: [0-9]+:[0-9]+;/ {
            if (cmd != \"\") {
              if (firstLine == \"\") {
                firstLine = \$0;
              }
              print cmd \"\\t\" firstLine;
              cmd = \"\";
              firstLine = \"\";
            }
            firstLine = \$0;
            cmd = substr(\$0, index(\$0, \";\") + 1);
          }
          !/^: [0-9]+:[0-9]+;/ {
            cmd = cmd \"\\\\n\" \$0;
            firstLine = firstLine \"\\n\" \$0;
          }
          END {
            if (cmd != \"\") print cmd \"\\t\" firstLine;
          }

        ' $HISTFILE | tac | awk -F\"\\t\" \"!seen[\\\$1]++ && \\\$2 != \\\"\\\" {print \\\$0}\")" \
        --bind "ctrl-q:execute(
            echo {1} | sed 's/\\\\n/\\n/g' | pbcopy
        )"
  )
  if [[ -n "$cmd" ]]; then
    # Extract just the command part (before the tab)
    cmd=$(echo "$cmd" | cut -f1 | sed 's/\\n/\n/g')
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
