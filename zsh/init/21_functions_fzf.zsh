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

function dotfiles_history_delete_history_range() {
  local histfile="${1:-}"
  local start_line="${2:-}"
  local end_line="${3:-}"

  if [[ -z "$histfile" || ! -f "$histfile" ]]; then
    return 1
  fi

  if [[ "$start_line" != <-> || "$end_line" != <-> ]]; then
    return 1
  fi

  if (( end_line < start_line )); then
    return 1
  fi

  sed -i.bak "${start_line},${end_line}d" "$histfile"
}

function fzf-select-history() {
  local selected
  local sort_mode="recent"

  # Create temporary files for history processing
  local candidate_file
  local mode_file
  local generator_script
  local history_deleted_flag
  local reload_cmd
  local toggle_cmd
  local preview_cmd
  local history_sorting_file

  candidate_file="$(mktemp /tmp/zsh_history_candidates.XXXXXX)"
  mode_file="$(mktemp /tmp/zsh_history_sort_mode.XXXXXX)"
  generator_script="$(mktemp /tmp/zsh_history_generator.XXXXXX)"
  history_deleted_flag="$(mktemp /tmp/zsh_history_deleted.XXXXXX)"

  if [[ "$sort_mode" != "frequency" ]]; then
    sort_mode="recent"
  fi

  rm -f "$history_deleted_flag"
  print -r -- "$sort_mode" >| "$mode_file"
  history_sorting_file="${DOTFILES_HISTORY_SORTING_SCRIPT_PATH:-${DOTPATH:-$HOME/.dotfiles}/zsh/init/40_history_sorting.zsh}"

  cat >| "$generator_script" <<'EOF'
#!/usr/bin/env zsh
set -euo pipefail

histfile="${DOTFILES_HISTORY_HISTFILE:-}"
candidate_file="${DOTFILES_HISTORY_CANDIDATE_FILE:-}"
sort_mode="${DOTFILES_HISTORY_SORT_MODE:-recent}"
mode_file="${DOTFILES_HISTORY_SORT_MODE_FILE:-}"
history_sorting_file="${DOTFILES_HISTORY_SORTING_FILE:-}"

if [[ -z "$histfile" || -z "$candidate_file" || -z "$history_sorting_file" || ! -f "$history_sorting_file" ]]; then
  exit 1
fi

if [[ -n "$mode_file" && -f "$mode_file" ]]; then
  read -r mode_value < "$mode_file" || mode_value="$sort_mode"
  sort_mode="$mode_value"
fi

if [[ "$sort_mode" != "frequency" ]]; then
  sort_mode="recent"
fi

if [[ ! -f "$histfile" ]]; then
  : >| "$candidate_file"
  exit 0
fi

source "$history_sorting_file"
dotfiles_history_generate_candidates "$histfile" "$sort_mode" "$candidate_file"

cat "$candidate_file"
EOF
  chmod +x "$generator_script"

  reload_cmd="DOTFILES_HISTORY_HISTFILE=${(q)HISTFILE} DOTFILES_HISTORY_CANDIDATE_FILE=${(q)candidate_file} DOTFILES_HISTORY_SORT_MODE=${(q)sort_mode} DOTFILES_HISTORY_SORT_MODE_FILE=${(q)mode_file} DOTFILES_HISTORY_SORTING_FILE=${(q)history_sorting_file} ${(q)generator_script}"
  toggle_cmd="if [[ \"\$(cat ${(q)mode_file} 2>/dev/null)\" == \"recent\" ]]; then print -r -- frequency >| ${(q)mode_file}; else print -r -- recent >| ${(q)mode_file}; fi"
  preview_cmd="printf '\\033[90mSort\\033[0m: %s  (toggle: Ctrl-S / Alt-S)\\n\\n' \"\$(cat ${(q)mode_file} 2>/dev/null || echo recent)\"; printf '\\033[90mOriginal\\033[0m\\n'; printf '%b\\n' {4}; printf '\\n\\033[90mWrapped\\033[0m\\n'; printf '%b\\n' {4} | fold -s -w \${COLUMNS:-80}"

  # Use fzf to select history
  selected=$(
    DOTFILES_HISTORY_HISTFILE="$HISTFILE" \
      DOTFILES_HISTORY_CANDIDATE_FILE="$candidate_file" \
      DOTFILES_HISTORY_SORT_MODE="$sort_mode" \
      DOTFILES_HISTORY_SORT_MODE_FILE="$mode_file" \
      DOTFILES_HISTORY_SORTING_FILE="$history_sorting_file" \
      "$generator_script" |
      fzf --query "$LBUFFER" \
        --tiebreak=index \
        --reverse \
        --multi \
        --header='Ctrl-S / Alt-S: toggle sort (recent <-> frequency)' \
        --delimiter='\t' \
        --with-nth=5 \
        --preview "$preview_cmd" \
        --bind "ctrl-s:execute-silent($toggle_cmd)+reload($reload_cmd)+refresh-preview" \
        --bind "alt-s:execute-silent($toggle_cmd)+reload($reload_cmd)+refresh-preview" \
        --bind "ctrl-x:execute-silent(
            start_line={2}
            end_line={3}
            if [[ \"\$start_line\" == <-> && \"\$end_line\" == <-> ]]; then
              if (( end_line < start_line )); then
                tmp=\"\$start_line\"
                start_line=\"\$end_line\"
                end_line=\"\$tmp\"
              fi
              sed -i.bak \"\${start_line},\${end_line}d\" \"$HISTFILE\"
              touch \"$history_deleted_flag\"
            fi
        )+reload($reload_cmd)" \
        --bind "ctrl-q:execute-silent(
            printf '%b' {4} | pbcopy
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
  rm -f "$candidate_file" "$mode_file" "$generator_script" "$history_deleted_flag" "${HISTFILE}.bak"

  if [[ -n "$selected" ]]; then
    local first_selected
    local -a selected_fields
    local encoded_cmd
    local cmd

    first_selected="${selected%%$'\n'*}"
    selected_fields=("${(@s:$'\t':)first_selected}")
    encoded_cmd="${selected_fields[4]:-}"
    cmd="$(printf '%b' "$encoded_cmd")"

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
