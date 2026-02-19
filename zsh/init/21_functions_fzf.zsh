SEARCH_BASE_DIRS=("$HOME" "/" "$HOME/Code")
EXCLUDE_DIRS=("node_modules" ".git" "cache" ".cache" "log" "logs" ".next")
# tac: brew install coreutils / brew install fzf

function refresh_history_from_file() {
  local histfile="${1:-$HISTFILE}"
  local histsize="${HISTSIZE:-10000}"
  local savehist="${SAVEHIST:-$histsize}"

  if [[ -z "$histfile" || ! -f "$histfile" ]]; then
    return 0
  fi

  if [[ "${__DOTFILES_HISTORY_REFRESH_STACK_ACTIVE:-0}" == "1" ]]; then
    fc -P 2>/dev/null || true
  fi

  # Switch current history list to HISTFILE.
  fc -p "$histfile" "$histsize" "$savehist"
  __DOTFILES_HISTORY_REFRESH_STACK_ACTIVE=1
}

function fzf-select-history() {
  local selected
  local sort_mode="${DOTFILES_CTRL_R_HISTORY_SORT_MODE:-recent}"

  # Create temporary files for history processing
  local tmpfile
  local candidate_file
  local count_file
  local mode_file
  local generator_script
  local history_deleted_flag
  local count_db="${DOTFILES_HISTORY_COUNT_DB:-}"
  local reload_cmd
  local toggle_cmd
  local preview_cmd

  tmpfile="$(mktemp /tmp/zsh_history_processed.XXXXXX)"
  candidate_file="$(mktemp /tmp/zsh_history_candidates.XXXXXX)"
  count_file="$(mktemp /tmp/zsh_history_counts.XXXXXX)"
  mode_file="$(mktemp /tmp/zsh_history_sort_mode.XXXXXX)"
  generator_script="$(mktemp /tmp/zsh_history_generator.XXXXXX)"
  history_deleted_flag="$(mktemp /tmp/zsh_history_deleted.XXXXXX)"

  if [[ "$sort_mode" != "frequency" ]]; then
    sort_mode="recent"
  fi

  rm -f "$history_deleted_flag"
  : >| "$count_file"
  print -r -- "$sort_mode" >| "$mode_file"

  if typeset -f dotfiles_history_counter_export_tsv >/dev/null 2>&1; then
    dotfiles_history_counter_export_tsv "$count_file"
  fi

  cat >| "$generator_script" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

histfile="${DOTFILES_HISTORY_HISTFILE:-}"
tmpfile="${DOTFILES_HISTORY_TMPFILE:-}"
candidate_file="${DOTFILES_HISTORY_CANDIDATE_FILE:-}"
sort_mode="${DOTFILES_HISTORY_SORT_MODE:-recent}"
count_file="${DOTFILES_HISTORY_COUNT_FILE:-}"
mode_file="${DOTFILES_HISTORY_SORT_MODE_FILE:-}"
count_db="${DOTFILES_HISTORY_COUNT_DB_FILE:-}"

if [[ -z "$histfile" || -z "$tmpfile" || -z "$candidate_file" ]]; then
  exit 1
fi

: >| "$candidate_file"

if [[ -n "$mode_file" && -f "$mode_file" ]]; then
  read -r mode_value < "$mode_file" || mode_value="$sort_mode"
  sort_mode="$mode_value"
fi

if [[ "$sort_mode" != "frequency" ]]; then
  sort_mode="recent"
fi

if [[ "$sort_mode" == "frequency" && -n "$count_file" ]]; then
  if [[ -n "$count_db" ]] && command -v sqlite3 >/dev/null 2>&1; then
    sqlite3 -separator $'\t' "$count_db" 'SELECT command, count FROM command_counts;' >| "$count_file" 2>/dev/null || : >| "$count_file"
  fi
fi

if [[ ! -f "$histfile" ]]; then
  cat "$candidate_file"
  exit 0
fi

awk '
  {
    if ($0 ~ /^: [0-9]+:[0-9]+;/) {
      cmd = substr($0, index($0, ";") + 1)
    } else {
      cmd = $0
    }

    if (cmd != "") {
      entry_num++
      display_cmd = cmd
      gsub(/__NEWLINE__/, " <NL> ", display_cmd)
      print entry_num "\t" NR "\t" cmd "\t" display_cmd
    }
  }
' "$histfile" >| "$tmpfile"

if [[ "$sort_mode" == "frequency" && -f "$count_file" ]]; then
  tac "$tmpfile" |
    awk -F'\t' '!seen[$3]++ {print $1 "\t" $3 "\t" $4}' |
    awk -F'\t' 'NR==FNR {counts[$1]=$2; next} {count = ($2 in counts ? counts[$2] : 0); print count "\t" NR "\t" $0}' "$count_file" - |
    sort -t$'\t' -k1,1nr -k2,2n |
    cut -f3- >| "$candidate_file"
else
  tac "$tmpfile" | awk -F'\t' '!seen[$3]++ {print $1 "\t" $3 "\t" $4}' >| "$candidate_file"
fi

cat "$candidate_file"
EOF
  chmod +x "$generator_script"

  reload_cmd="DOTFILES_HISTORY_HISTFILE=${(q)HISTFILE} DOTFILES_HISTORY_TMPFILE=${(q)tmpfile} DOTFILES_HISTORY_CANDIDATE_FILE=${(q)candidate_file} DOTFILES_HISTORY_SORT_MODE=${(q)sort_mode} DOTFILES_HISTORY_COUNT_FILE=${(q)count_file} DOTFILES_HISTORY_SORT_MODE_FILE=${(q)mode_file} DOTFILES_HISTORY_COUNT_DB_FILE=${(q)count_db} ${(q)generator_script}"
  toggle_cmd="if [[ \"\$(cat ${(q)mode_file} 2>/dev/null)\" == \"recent\" ]]; then echo frequency >| ${(q)mode_file}; else echo recent >| ${(q)mode_file}; fi"
  preview_cmd="echo -e \"\\033[90mSort\\033[0m: \$(cat ${(q)mode_file} 2>/dev/null || echo recent)  (toggle: Ctrl-S / Alt-S)\"; echo \"\"; echo -e \"\\033[90mOriginal\\033[0m\"; echo {2} | sed \"s/__NEWLINE__/\\n/g\"; echo \"\"; echo -e \"\\033[90mWrapped\\033[0m\"; echo {2} | sed \"s/__NEWLINE__/\\n/g\" | fold -s -w \$COLUMNS"

  # Use fzf to select history
  selected=$(
    DOTFILES_HISTORY_HISTFILE="$HISTFILE" \
      DOTFILES_HISTORY_TMPFILE="$tmpfile" \
      DOTFILES_HISTORY_CANDIDATE_FILE="$candidate_file" \
      DOTFILES_HISTORY_SORT_MODE="$sort_mode" \
      DOTFILES_HISTORY_COUNT_FILE="$count_file" \
      DOTFILES_HISTORY_SORT_MODE_FILE="$mode_file" \
      DOTFILES_HISTORY_COUNT_DB_FILE="$count_db" \
      "$generator_script" |
      fzf --query "$LBUFFER" \
        --tiebreak=index \
        --reverse \
        --multi \
        --header='Ctrl-S / Alt-S: toggle sort (recent <-> frequency)' \
        --delimiter='\t' \
        --with-nth=3 \
        --preview "$preview_cmd" \
        --bind "ctrl-s:execute-silent($toggle_cmd)+reload($reload_cmd)+refresh-preview" \
        --bind "alt-s:execute-silent($toggle_cmd)+reload($reload_cmd)+refresh-preview" \
        --bind "ctrl-x:execute-silent(
            entry_id={1}
            line_num=\$(awk -F'\t' -v id=\"\$entry_id\" '\$1 == id {print \$2; exit}' \"$tmpfile\")
            if [[ -n \"\$line_num\" ]]; then
              sed -i.bak \"\${line_num}d\" \"$HISTFILE\"
              touch \"$history_deleted_flag\"
            fi
        )+reload($reload_cmd)" \
        --bind "ctrl-q:execute-silent(
            echo {2} | sed 's/__NEWLINE__/\n/g' | pbcopy
        )"
  )

  if [[ -f "$mode_file" ]]; then
    local selected_mode
    read -r selected_mode < "$mode_file" || selected_mode="$sort_mode"
    if [[ "$selected_mode" == "recent" || "$selected_mode" == "frequency" ]]; then
      DOTFILES_CTRL_R_HISTORY_SORT_MODE="$selected_mode"
    fi
  fi

  if [[ -f "$history_deleted_flag" ]]; then
    refresh_history_from_file "$HISTFILE"
    if typeset -f dotfiles_history_counter_rebuild_from_history >/dev/null 2>&1; then
      dotfiles_history_counter_rebuild_from_history "$HISTFILE"
    fi
    zle autosuggest-clear 2>/dev/null
    zle autosuggest-fetch 2>/dev/null
  fi

  # Clean up
  rm -f "$tmpfile" "$candidate_file" "$count_file" "$mode_file" "$generator_script" "$history_deleted_flag" "${HISTFILE}.bak"

  if [[ -n "$selected" ]]; then
    # Extract original command and convert __NEWLINE__ back to newlines
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
    fzf --print-query \
      --reverse \
      --tiebreak=index \
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
