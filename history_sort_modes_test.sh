#!/bin/bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
TMP_DIR="$(mktemp -d /tmp/zsh_history_sort_modes.XXXXXX)"

cleanup() {
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

HISTFILE_PATH="$TMP_DIR/history"
DB_PATH="$TMP_DIR/history_counts.sqlite3"
OUT_RECENT="$TMP_DIR/recent.tsv"
OUT_FREQ="$TMP_DIR/frequency.tsv"

decode_candidate_command() {
  local file="$1"
  local row="$2"
  local encoded

  encoded="$(awk -F'\t' -v n="$row" 'NR==n {print $4}' "$file")"
  printf '%b' "$encoded"
}

cat > "$HISTFILE_PATH" <<'HISTEOF'
: 1700000000:0;echo alpha
: 1700000001:0;echo beta
: 1700000002:0;echo gamma
: 1700000003:0;echo beta
: 1700000004:0;echo alpha
HISTEOF

zsh -c "
  set -euo pipefail

  HISTFILE='$HISTFILE_PATH'
  export HISTFILE
  export DOTFILES_HISTORY_COUNT_DB='$DB_PATH'

  source '$ROOT_DIR/zsh/init/40_history_sorting.zsh'

  dotfiles_history_counter_rebuild_from_history '$HISTFILE_PATH'
  dotfiles_history_counter_increment 'echo beta'
  dotfiles_history_counter_increment 'echo beta'
  dotfiles_history_counter_increment 'echo alpha'

  dotfiles_history_generate_candidates '$HISTFILE_PATH' 'recent' '$OUT_RECENT'
  dotfiles_history_generate_candidates '$HISTFILE_PATH' 'frequency' '$OUT_FREQ'
"

recent_nf="$(awk -F'\t' 'NR==1 {print NF}' "$OUT_RECENT")"
if [[ "$recent_nf" != "5" ]]; then
  echo "FAIL: recent output column mismatch"
  echo "Expected columns: 5"
  echo "Got: $recent_nf"
  exit 1
fi

recent_first="$(decode_candidate_command "$OUT_RECENT" 1)"
recent_second="$(decode_candidate_command "$OUT_RECENT" 2)"
recent_third="$(decode_candidate_command "$OUT_RECENT" 3)"

if [[ "$recent_first" != "echo alpha" || "$recent_second" != "echo beta" || "$recent_third" != "echo gamma" ]]; then
  echo "FAIL: recent order mismatch"
  echo "Got: $recent_first, $recent_second, $recent_third"
  exit 1
fi

freq_nf="$(awk -F'\t' 'NR==1 {print NF}' "$OUT_FREQ")"
if [[ "$freq_nf" != "5" ]]; then
  echo "FAIL: frequency output column mismatch"
  echo "Expected columns: 5"
  echo "Got: $freq_nf"
  exit 1
fi

freq_first="$(decode_candidate_command "$OUT_FREQ" 1)"
freq_second="$(decode_candidate_command "$OUT_FREQ" 2)"
freq_third="$(decode_candidate_command "$OUT_FREQ" 3)"

if [[ "$freq_first" != "echo beta" || "$freq_second" != "echo alpha" || "$freq_third" != "echo gamma" ]]; then
  echo "FAIL: frequency order mismatch"
  echo "Got: $freq_first, $freq_second, $freq_third"
  exit 1
fi

last_exec_column="$(sqlite3 "$DB_PATH" "SELECT COUNT(*) FROM pragma_table_info('command_counts') WHERE name = 'last_executed_at';")"
if [[ "$last_exec_column" != "1" ]]; then
  echo "FAIL: missing last_executed_at column"
  exit 1
fi

last_exec_value="$(sqlite3 "$DB_PATH" "SELECT last_executed_at FROM command_counts WHERE command = 'echo beta' LIMIT 1;")"
if [[ -z "$last_exec_value" || "$last_exec_value" == "0" ]]; then
  echo "FAIL: missing last_executed_at value"
  exit 1
fi

cat > "$HISTFILE_PATH" <<'HISTEOF'
: 1700000010:0;echo alpha
: 1700000011:0;echo beta
: 1700000012:0;echo gamma
: 1700000013:0;echo alpha
HISTEOF

zsh -c "
  set -euo pipefail

  HISTFILE='$HISTFILE_PATH'
  export HISTFILE
  export DOTFILES_HISTORY_COUNT_DB='$DB_PATH'

  source '$ROOT_DIR/zsh/init/40_history_sorting.zsh'

  dotfiles_history_counter_rebuild_from_history '$HISTFILE_PATH'
  dotfiles_history_generate_candidates '$HISTFILE_PATH' 'frequency' '$OUT_FREQ'
"

rebuild_first="$(decode_candidate_command "$OUT_FREQ" 1)"
rebuild_second="$(decode_candidate_command "$OUT_FREQ" 2)"
rebuild_third="$(decode_candidate_command "$OUT_FREQ" 3)"

if [[ "$rebuild_first" != "echo alpha" || "$rebuild_second" != "echo gamma" || "$rebuild_third" != "echo beta" ]]; then
  echo "FAIL: rebuild frequency order mismatch"
  echo "Got: $rebuild_first, $rebuild_second, $rebuild_third"
  exit 1
fi

echo "PASS: history sort modes"
