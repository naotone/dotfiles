: "${DOTFILES_CTRL_R_HISTORY_SORT_MODE:=recent}"
: "${DOTFILES_AUTOSUGGEST_SORT_MODE:=frequency}"
: "${DOTFILES_HISTORY_COUNT_DB:=${XDG_CACHE_HOME:-$HOME/.cache}/shell/history_counts.sqlite3}"
: "${DOTFILES_HISTORY_SORTING_SCRIPT_PATH:=${DOTPATH:-$HOME/.dotfiles}/zsh/init/40_history_sorting.zsh}"
: "${DOTFILES_HISTORY_ENCODING_VERSION:=2}"

typeset -g DOTFILES_CTRL_R_HISTORY_SORT_MODE
typeset -g DOTFILES_AUTOSUGGEST_SORT_MODE
typeset -g DOTFILES_HISTORY_COUNT_DB
typeset -g DOTFILES_HISTORY_SORTING_SCRIPT_PATH
typeset -g DOTFILES_HISTORY_ENCODING_VERSION

typeset -g __DOTFILES_HISTORY_COUNTER_ENABLED=1
typeset -g __DOTFILES_HISTORY_COUNTER_READY=0

typeset -gA DOTFILES_HISTORY_COUNT_CACHE

function dotfiles_history_sql_quote() {
  local value="$1"
  value="$(printf '%s' "$value" | sed "s/'/''/g")"
  print -r -- "'$value'"
}

function dotfiles_history_encode_command_key() {
  local value="$1"

  value="${value//\\/\\\\}"
  value="${value//$'\n'/\\n}"
  value="${value//$'\t'/\\t}"
  value="${value//$'\r'/\\r}"

  print -r -- "$value"
}

function dotfiles_history_decode_command_key() {
  local value="$1"

  printf '%b' "$value"
}

function dotfiles_history_format_display_command() {
  local value="$1"

  value="${value//$'\n'/ <NL> }"
  value="${value//$'\t'/ <TAB> }"
  value="${value//$'\r'/ <CR> }"

  print -r -- "$value"
}

function _dotfiles_history_append_parsed_entry() {
  local outfile="$1"
  local entry_id="$2"
  local start_line="$3"
  local end_line="$4"
  local timestamp="$5"
  local command="$6"
  local command_key
  local display
  local separator=$'\t'

  if [[ -z "$command" ]]; then
    return 0
  fi

  command_key="$(dotfiles_history_encode_command_key "$command")"
  display="$(dotfiles_history_format_display_command "$command")"

  print -r -- "${entry_id}${separator}${start_line}${separator}${end_line}${separator}${timestamp}${separator}${command_key}${separator}${display}" >>| "$outfile"
}

function dotfiles_history_parse_entries_tsv() {
  local histfile="$1"
  local outfile="$2"
  local now_epoch

  : >| "$outfile"

  if [[ -z "$histfile" || ! -f "$histfile" ]]; then
    return 0
  fi

  now_epoch="$(date +%s)"

  awk -v now_epoch="$now_epoch" '
    function encode_key(value) {
      gsub(/\\/, "\\\\", value)
      gsub(/\n/, "\\n", value)
      gsub(/\t/, "\\t", value)
      gsub(/\r/, "\\r", value)
      return value
    }

    function display_text(value) {
      gsub(/\n/, " <NL> ", value)
      gsub(/\t/, " <TAB> ", value)
      gsub(/\r/, " <CR> ", value)
      return value
    }

    function emit_entry(command_value, key, display_value) {
      if (!in_entry || command == "") {
        return
      }

      command_value = command
      if (command_value == "") {
        return
      }

      key = encode_key(command_value)
      display_value = display_text(command_value)

      printf "%d\t%d\t%d\t%d\t%s\t%s\n", entry_id, start_line, end_line, timestamp, key, display_value
    }

    BEGIN {
      entry_id = 0
      in_entry = 0
      start_line = 0
      end_line = 0
      timestamp = 0
      command = ""
    }

    {
      if ($0 ~ /^: [0-9]+:[0-9]+;/) {
        emit_entry()

        in_entry = 1
        entry_id += 1
        start_line = NR
        end_line = NR

        ts_text = $0
        sub(/^: /, "", ts_text)
        split(ts_text, parts, ":")
        timestamp = parts[1] + 0

        command = substr($0, index($0, ";") + 1)
        next
      }

      if (!in_entry) {
        in_entry = 1
        entry_id += 1
        start_line = NR
        end_line = NR
        timestamp = now_epoch
        command = $0
        next
      }

      end_line = NR
      if (command ~ /\\$/) {
        sub(/\\$/, "", command)
      }
      command = command "\n" $0
    }

    END {
      emit_entry()
    }
  ' "$histfile" >| "$outfile"
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

function _dotfiles_history_counter_get_meta() {
  local key="$1"
  local quoted_key

  quoted_key="$(dotfiles_history_sql_quote "$key")"
  sqlite3 "$DOTFILES_HISTORY_COUNT_DB" "SELECT value FROM meta WHERE key = ${quoted_key} LIMIT 1;" 2>/dev/null || true
}

function _dotfiles_history_counter_set_meta() {
  local key="$1"
  local value="$2"
  local quoted_key
  local quoted_value

  quoted_key="$(dotfiles_history_sql_quote "$key")"
  quoted_value="$(dotfiles_history_sql_quote "$value")"

  sqlite3 "$DOTFILES_HISTORY_COUNT_DB" "INSERT INTO meta(key, value) VALUES(${quoted_key}, ${quoted_value}) ON CONFLICT(key) DO UPDATE SET value = excluded.value;" >/dev/null 2>&1 || true
}

function _dotfiles_history_counter_rebuild_from_history_core() {
  local histfile="$1"
  local now_epoch
  local parsed_file
  local entry_id
  local start_line
  local end_line
  local timestamp
  local command_key
  local display
  local quoted_command
  typeset -A counts
  typeset -A latest

  now_epoch="$(date +%s)"
  parsed_file="/tmp/zsh_history_rebuild.$$.$RANDOM"

  dotfiles_history_parse_entries_tsv "$histfile" "$parsed_file"

  while IFS=$'\t' read -r entry_id start_line end_line timestamp command_key display; do
    if [[ -z "$command_key" ]]; then
      continue
    fi

    counts["$command_key"]=$(( ${counts[$command_key]:-0} + 1 ))

    if [[ -z "${latest[$command_key]:-}" || "$timestamp" -gt "${latest[$command_key]}" ]]; then
      latest["$command_key"]="$timestamp"
    fi
  done < "$parsed_file"

  {
    print "BEGIN;"
    print "DELETE FROM command_counts;"

    for command_key in ${(k)counts}; do
      quoted_command="$(dotfiles_history_sql_quote "$command_key")"
      print "INSERT INTO command_counts(command, count, updated_at, last_executed_at) VALUES(${quoted_command}, ${counts[$command_key]}, ${now_epoch}, ${latest[$command_key]});"
    done

    print "COMMIT;"
  } | sqlite3 "$DOTFILES_HISTORY_COUNT_DB" >/dev/null 2>&1

  rm -f "$parsed_file"
}

function dotfiles_history_counter_load_cache() {
  local command_key
  local count

  DOTFILES_HISTORY_COUNT_CACHE=()

  if [[ "$__DOTFILES_HISTORY_COUNTER_ENABLED" != "1" ]]; then
    return 0
  fi

  while IFS=$'\t' read -r command_key count; do
    if [[ -n "$command_key" && -n "$count" ]]; then
      DOTFILES_HISTORY_COUNT_CACHE["$command_key"]="$count"
    fi
  done < <(sqlite3 -separator $'\t' "$DOTFILES_HISTORY_COUNT_DB" 'SELECT command, count FROM command_counts;')
}

function dotfiles_history_counter_init() {
  local cache_dir
  local bootstrap_done
  local bootstrap_histfile
  local encoding_version

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

  bootstrap_histfile="${HISTFILE:-$HOME/.zsh_history}"
  bootstrap_done="$(_dotfiles_history_counter_get_meta 'bootstrap_done')"
  encoding_version="$(_dotfiles_history_counter_get_meta 'history_encoding_version')"

  if [[ "$bootstrap_done" != "1" || "$encoding_version" != "$DOTFILES_HISTORY_ENCODING_VERSION" ]]; then
    _dotfiles_history_counter_rebuild_from_history_core "$bootstrap_histfile"
    _dotfiles_history_counter_set_meta 'bootstrap_done' '1'
    _dotfiles_history_counter_set_meta 'history_encoding_version' "$DOTFILES_HISTORY_ENCODING_VERSION"
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
  _dotfiles_history_counter_set_meta 'history_encoding_version' "$DOTFILES_HISTORY_ENCODING_VERSION"
  dotfiles_history_counter_load_cache
}

function dotfiles_history_counter_increment() {
  local command="$1"
  local command_key
  local quoted_command
  local count

  if [[ -z "$command" ]]; then
    return 0
  fi

  dotfiles_history_counter_init >/dev/null 2>&1 || return 0
  if [[ "$__DOTFILES_HISTORY_COUNTER_ENABLED" != "1" ]]; then
    return 0
  fi

  command_key="$(dotfiles_history_encode_command_key "$command")"
  quoted_command="$(dotfiles_history_sql_quote "$command_key")"

  sqlite3 "$DOTFILES_HISTORY_COUNT_DB" "INSERT INTO command_counts(command, count, updated_at, last_executed_at) VALUES(${quoted_command}, 1, strftime('%s','now'), strftime('%s','now')) ON CONFLICT(command) DO UPDATE SET count = count + 1, updated_at = strftime('%s','now'), last_executed_at = strftime('%s','now');" >/dev/null 2>&1 || return 0

  count="${DOTFILES_HISTORY_COUNT_CACHE[$command_key]:-0}"
  DOTFILES_HISTORY_COUNT_CACHE["$command_key"]=$((count + 1))
}

function dotfiles_history_counter_decrement() {
  local command="$1"
  local command_key
  local quoted_command
  local count

  if [[ -z "$command" ]]; then
    return 0
  fi

  dotfiles_history_counter_init >/dev/null 2>&1 || return 0
  if [[ "$__DOTFILES_HISTORY_COUNTER_ENABLED" != "1" ]]; then
    return 0
  fi

  command_key="$(dotfiles_history_encode_command_key "$command")"
  quoted_command="$(dotfiles_history_sql_quote "$command_key")"

  sqlite3 "$DOTFILES_HISTORY_COUNT_DB" "UPDATE command_counts SET count = CASE WHEN count > 0 THEN count - 1 ELSE 0 END, updated_at = strftime('%s','now') WHERE command = ${quoted_command}; DELETE FROM command_counts WHERE command = ${quoted_command} AND count <= 0;" >/dev/null 2>&1 || return 0

  count="${DOTFILES_HISTORY_COUNT_CACHE[$command_key]:-0}"
  if (( count <= 1 )); then
    unset "DOTFILES_HISTORY_COUNT_CACHE[$command_key]"
  else
    DOTFILES_HISTORY_COUNT_CACHE["$command_key"]=$((count - 1))
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

  dotfiles_history_parse_entries_tsv "$histfile" "$parsed_file"

  if [[ ! -s "$parsed_file" ]]; then
    rm -f "$parsed_file" "$unique_file" "$count_file"
    return 0
  fi

  tac "$parsed_file" | awk -F'\t' '!seen[$5]++ {print $1 "\t" $2 "\t" $3 "\t" $5 "\t" $6}' >| "$unique_file"

  if [[ "$mode" == "frequency" ]]; then
    dotfiles_history_counter_export_tsv "$count_file"
    awk -F'\t' 'NR==FNR {counts[$1]=$2; next} {count = ($4 in counts ? counts[$4] : 0); print count "\t" NR "\t" $0}' "$count_file" "$unique_file" \
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
  local command_key
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
    command_key="$(dotfiles_history_encode_command_key "$command")"
    count="${DOTFILES_HISTORY_COUNT_CACHE[$command_key]:-0}"

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
