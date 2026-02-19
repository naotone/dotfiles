: "${DOTFILES_CTRL_R_HISTORY_SORT_MODE:=recent}"
: "${DOTFILES_AUTOSUGGEST_SORT_MODE:=frequency}"
: "${DOTFILES_HISTORY_COUNT_DB:=${XDG_CACHE_HOME:-$HOME/.cache}/shell/history_counts.sqlite3}"

typeset -g DOTFILES_CTRL_R_HISTORY_SORT_MODE
typeset -g DOTFILES_AUTOSUGGEST_SORT_MODE
typeset -g DOTFILES_HISTORY_COUNT_DB

typeset -g __DOTFILES_HISTORY_COUNTER_ENABLED=1
typeset -g __DOTFILES_HISTORY_COUNTER_READY=0

typeset -gA DOTFILES_HISTORY_COUNT_CACHE

function dotfiles_history_sql_quote() {
  local value="$1"
  value="$(printf '%s' "$value" | sed "s/'/''/g")"
  print -r -- "'$value'"
}

function _dotfiles_history_counter_create_schema() {
  sqlite3 "$DOTFILES_HISTORY_COUNT_DB" <<'SQL' >/dev/null 2>&1
CREATE TABLE IF NOT EXISTS command_counts (
  command TEXT PRIMARY KEY,
  count INTEGER NOT NULL,
  updated_at INTEGER NOT NULL,
  last_executed_at INTEGER NOT NULL
);

CREATE TABLE IF NOT EXISTS meta (
  key TEXT PRIMARY KEY,
  value TEXT NOT NULL
);
SQL
}

function _dotfiles_history_counter_migrate_schema() {
  local has_last_executed

  has_last_executed="$(sqlite3 "$DOTFILES_HISTORY_COUNT_DB" "SELECT COUNT(*) FROM pragma_table_info('command_counts') WHERE name = 'last_executed_at';" 2>/dev/null || echo 0)"

  if [[ "$has_last_executed" == "0" ]]; then
    sqlite3 "$DOTFILES_HISTORY_COUNT_DB" "ALTER TABLE command_counts ADD COLUMN last_executed_at INTEGER;" >/dev/null 2>&1 || true
  fi

  sqlite3 "$DOTFILES_HISTORY_COUNT_DB" "UPDATE command_counts SET last_executed_at = COALESCE(last_executed_at, updated_at, strftime('%s','now')) WHERE last_executed_at IS NULL OR last_executed_at <= 0;" >/dev/null 2>&1 || true
}

function _dotfiles_history_counter_rebuild_from_history_core() {
  local histfile="$1"
  local now_epoch

  now_epoch=$(date +%s)

  {
    print "BEGIN;"
    print "DELETE FROM command_counts;"
    if [[ -f "$histfile" ]]; then
      awk -v now="$now_epoch" '
        {
          ts = now
          if ($0 ~ /^: [0-9]+:[0-9]+;/) {
            ts_text = $0
            sub(/^: /, "", ts_text)
            split(ts_text, parts, ":")
            ts = parts[1] + 0
            cmd = substr($0, index($0, ";") + 1)
          } else {
            cmd = $0
          }

          if (cmd == "") {
            next
          }

          counts[cmd]++
          if (!(cmd in latest) || ts > latest[cmd]) {
            latest[cmd] = ts
          }
        }
        END {
          for (cmd in counts) {
            esc = cmd
            gsub(/\047/, "\047\047", esc)
            print "INSERT INTO command_counts(command, count, updated_at, last_executed_at) VALUES(\047" esc "\047, " counts[cmd] ", " now ", " latest[cmd] ");"
          }
        }
      ' "$histfile"
    fi
    print "COMMIT;"
  } | sqlite3 "$DOTFILES_HISTORY_COUNT_DB" >/dev/null 2>&1
}

function dotfiles_history_counter_load_cache() {
  local command
  local count

  DOTFILES_HISTORY_COUNT_CACHE=()

  if [[ "$__DOTFILES_HISTORY_COUNTER_ENABLED" != "1" ]]; then
    return 0
  fi

  while IFS=$'\t' read -r command count; do
    if [[ -n "$command" && -n "$count" ]]; then
      DOTFILES_HISTORY_COUNT_CACHE["$command"]="$count"
    fi
  done < <(sqlite3 -separator $'\t' "$DOTFILES_HISTORY_COUNT_DB" 'SELECT command, count FROM command_counts;')
}

function dotfiles_history_counter_init() {
  local cache_dir
  local bootstrap_done
  local bootstrap_histfile

  if [[ "$__DOTFILES_HISTORY_COUNTER_READY" == "1" ]]; then
    return 0
  fi

  if ! command -v sqlite3 >/dev/null 2>&1; then
    __DOTFILES_HISTORY_COUNTER_ENABLED=0
    __DOTFILES_HISTORY_COUNTER_READY=1
    return 1
  fi

  cache_dir="${DOTFILES_HISTORY_COUNT_DB:h}"
  mkdir -p "$cache_dir" 2>/dev/null || true

  if ! _dotfiles_history_counter_create_schema; then
    __DOTFILES_HISTORY_COUNTER_ENABLED=0
    __DOTFILES_HISTORY_COUNTER_READY=1
    return 1
  fi

  _dotfiles_history_counter_migrate_schema

  bootstrap_done="$(sqlite3 "$DOTFILES_HISTORY_COUNT_DB" "SELECT value FROM meta WHERE key = 'bootstrap_done' LIMIT 1;" 2>/dev/null || true)"
  if [[ "$bootstrap_done" != "1" ]]; then
    bootstrap_histfile="${HISTFILE:-$HOME/.zsh_history}"
    _dotfiles_history_counter_rebuild_from_history_core "$bootstrap_histfile"
    sqlite3 "$DOTFILES_HISTORY_COUNT_DB" "INSERT INTO meta(key, value) VALUES('bootstrap_done', '1') ON CONFLICT(key) DO UPDATE SET value = excluded.value;" >/dev/null 2>&1 || true
  fi

  dotfiles_history_counter_load_cache
  __DOTFILES_HISTORY_COUNTER_READY=1
  __DOTFILES_HISTORY_COUNTER_ENABLED=1
}

function dotfiles_history_counter_rebuild_from_history() {
  local histfile="${1:-${HISTFILE:-$HOME/.zsh_history}}"

  dotfiles_history_counter_init >/dev/null 2>&1 || return 0
  if [[ "$__DOTFILES_HISTORY_COUNTER_ENABLED" != "1" ]]; then
    return 0
  fi

  _dotfiles_history_counter_rebuild_from_history_core "$histfile"
  dotfiles_history_counter_load_cache
}

function dotfiles_history_counter_increment() {
  local command="$1"
  local quoted_command
  local count

  if [[ -z "$command" ]]; then
    return 0
  fi

  dotfiles_history_counter_init >/dev/null 2>&1 || return 0
  if [[ "$__DOTFILES_HISTORY_COUNTER_ENABLED" != "1" ]]; then
    return 0
  fi

  quoted_command="$(dotfiles_history_sql_quote "$command")"

  sqlite3 "$DOTFILES_HISTORY_COUNT_DB" "INSERT INTO command_counts(command, count, updated_at, last_executed_at) VALUES(${quoted_command}, 1, strftime('%s','now'), strftime('%s','now')) ON CONFLICT(command) DO UPDATE SET count = count + 1, updated_at = strftime('%s','now'), last_executed_at = strftime('%s','now');" >/dev/null 2>&1 || return 0

  count="${DOTFILES_HISTORY_COUNT_CACHE[$command]:-0}"
  DOTFILES_HISTORY_COUNT_CACHE["$command"]=$((count + 1))
}

function dotfiles_history_counter_decrement() {
  local command="$1"
  local quoted_command
  local count

  if [[ -z "$command" ]]; then
    return 0
  fi

  dotfiles_history_counter_init >/dev/null 2>&1 || return 0
  if [[ "$__DOTFILES_HISTORY_COUNTER_ENABLED" != "1" ]]; then
    return 0
  fi

  quoted_command="$(dotfiles_history_sql_quote "$command")"

  sqlite3 "$DOTFILES_HISTORY_COUNT_DB" "UPDATE command_counts SET count = CASE WHEN count > 0 THEN count - 1 ELSE 0 END, updated_at = strftime('%s','now') WHERE command = ${quoted_command}; DELETE FROM command_counts WHERE command = ${quoted_command} AND count <= 0;" >/dev/null 2>&1 || return 0

  count="${DOTFILES_HISTORY_COUNT_CACHE[$command]:-0}"
  if (( count <= 1 )); then
    unset "DOTFILES_HISTORY_COUNT_CACHE[$command]"
  else
    DOTFILES_HISTORY_COUNT_CACHE["$command"]=$((count - 1))
  fi
}

function dotfiles_history_counter_export_tsv() {
  local outfile="$1"

  dotfiles_history_counter_init >/dev/null 2>&1 || true
  : >| "$outfile"

  if [[ "$__DOTFILES_HISTORY_COUNTER_ENABLED" != "1" ]]; then
    return 0
  fi

  sqlite3 -separator $'\t' "$DOTFILES_HISTORY_COUNT_DB" 'SELECT command, count FROM command_counts;' >| "$outfile" 2>/dev/null || : >| "$outfile"
}

function dotfiles_history_counter_export_with_latest_tsv() {
  local outfile="$1"

  dotfiles_history_counter_init >/dev/null 2>&1 || true
  : >| "$outfile"

  if [[ "$__DOTFILES_HISTORY_COUNTER_ENABLED" != "1" ]]; then
    return 0
  fi

  sqlite3 -separator $'\t' "$DOTFILES_HISTORY_COUNT_DB" "SELECT command, count, last_executed_at, datetime(last_executed_at, 'unixepoch', 'localtime') FROM command_counts;" >| "$outfile" 2>/dev/null || : >| "$outfile"
}

function dotfiles_history_generate_candidates() {
  local histfile="$1"
  local mode="$2"
  local outfile="$3"
  local parsed_file
  local unique_file
  local count_file

  parsed_file="/tmp/zsh_history_parsed.$$.$RANDOM"
  unique_file="/tmp/zsh_history_unique.$$.$RANDOM"
  count_file="/tmp/zsh_history_counts.$$.$RANDOM"

  : >| "$outfile"

  if [[ -z "$histfile" || ! -f "$histfile" ]]; then
    rm -f "$parsed_file" "$unique_file" "$count_file"
    return 0
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
  ' "$histfile" >| "$parsed_file"

  tac "$parsed_file" | awk -F'\t' '!seen[$3]++ {print $1 "\t" $3 "\t" $4}' >| "$unique_file"

  if [[ "$mode" == "frequency" ]]; then
    dotfiles_history_counter_export_tsv "$count_file"
    awk -F'\t' 'NR==FNR {counts[$1]=$2; next} {count = ($2 in counts ? counts[$2] : 0); print count "\t" NR "\t" $0}' "$count_file" "$unique_file" \
      | sort -t$'\t' -k1,1nr -k2,2n \
      | cut -f3- >| "$outfile"
  else
    cat "$unique_file" >| "$outfile"
  fi

  rm -f "$parsed_file" "$unique_file" "$count_file"
}

function _zsh_autosuggest_strategy_history_frequency() {
  emulate -L zsh
  setopt EXTENDED_GLOB

  local prefix
  local pattern
  local -a history_match_keys
  local -A seen
  local key
  local command
  local count
  local best_command=""
  local best_count=-1
  local best_key=0

  dotfiles_history_counter_init >/dev/null 2>&1 || true

  prefix="${1//(#m)[\\*?[\]<>()|^~#]/\\$MATCH}"
  pattern="$prefix*"

  if [[ -n "$ZSH_AUTOSUGGEST_HISTORY_IGNORE" ]]; then
    pattern="($pattern)~($ZSH_AUTOSUGGEST_HISTORY_IGNORE)"
  fi

  history_match_keys=(${(Onk)history[(R)$~pattern]})

  for key in $history_match_keys; do
    command="${history[$key]}"
    if [[ -z "$command" || -n "${seen[$command]:-}" ]]; then
      continue
    fi
    seen["$command"]=1
    count="${DOTFILES_HISTORY_COUNT_CACHE[$command]:-0}"
    if (( count > best_count || (count == best_count && key > best_key) )); then
      best_count="$count"
      best_key="$key"
      best_command="$command"
    fi
  done

  if [[ -n "$best_command" ]]; then
    typeset -g suggestion="$best_command"
  fi
}

function dotfiles_apply_autosuggest_sort_mode() {
  local mode="${DOTFILES_AUTOSUGGEST_SORT_MODE:-frequency}"

  if [[ "$mode" == "frequency" ]]; then
    ZSH_AUTOSUGGEST_STRATEGY=(history_frequency history)
  else
    ZSH_AUTOSUGGEST_STRATEGY=(history)
  fi
}

function dotfiles_toggle_ctrl_r_history_sort_mode() {
  if [[ "${DOTFILES_CTRL_R_HISTORY_SORT_MODE:-recent}" == "recent" ]]; then
    DOTFILES_CTRL_R_HISTORY_SORT_MODE="frequency"
  else
    DOTFILES_CTRL_R_HISTORY_SORT_MODE="recent"
  fi
}

function dotfiles_toggle_autosuggest_sort_mode() {
  if [[ "${DOTFILES_AUTOSUGGEST_SORT_MODE:-frequency}" == "recent" ]]; then
    DOTFILES_AUTOSUGGEST_SORT_MODE="frequency"
  else
    DOTFILES_AUTOSUGGEST_SORT_MODE="recent"
  fi
  dotfiles_apply_autosuggest_sort_mode
}

function history-sort-toggle-ctrl-r() {
  dotfiles_toggle_ctrl_r_history_sort_mode
  zle -M "Ctrl-R sort: ${DOTFILES_CTRL_R_HISTORY_SORT_MODE}" 2>/dev/null || true
}

function history-sort-toggle-autosuggest() {
  dotfiles_toggle_autosuggest_sort_mode
  zle autosuggest-clear 2>/dev/null || true
  zle autosuggest-fetch 2>/dev/null || true
  zle -M "Autosuggest sort: ${DOTFILES_AUTOSUGGEST_SORT_MODE}" 2>/dev/null || true
}

dotfiles_history_counter_init >/dev/null 2>&1 || true
dotfiles_apply_autosuggest_sort_mode

if [[ -o interactive ]]; then
  zle -N history-sort-toggle-ctrl-r
  zle -N history-sort-toggle-autosuggest
fi
