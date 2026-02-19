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

recent_first="$(awk -F'\t' 'NR==1 {print $2}' "$OUT_RECENT")"
recent_second="$(awk -F'\t' 'NR==2 {print $2}' "$OUT_RECENT")"
recent_third="$(awk -F'\t' 'NR==3 {print $2}' "$OUT_RECENT")"

if [[ "$recent_first" != "echo alpha" || "$recent_second" != "echo beta" || "$recent_third" != "echo gamma" ]]; then
  echo "FAIL: recent order mismatch"
  echo "Got: $recent_first, $recent_second, $recent_third"
  exit 1
fi

freq_first="$(awk -F'\t' 'NR==1 {print $2}' "$OUT_FREQ")"
freq_second="$(awk -F'\t' 'NR==2 {print $2}' "$OUT_FREQ")"
freq_third="$(awk -F'\t' 'NR==3 {print $2}' "$OUT_FREQ")"

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

rebuild_first="$(awk -F'\t' 'NR==1 {print $2}' "$OUT_FREQ")"
rebuild_second="$(awk -F'\t' 'NR==2 {print $2}' "$OUT_FREQ")"
rebuild_third="$(awk -F'\t' 'NR==3 {print $2}' "$OUT_FREQ")"

if [[ "$rebuild_first" != "echo alpha" || "$rebuild_second" != "echo gamma" || "$rebuild_third" != "echo beta" ]]; then
  echo "FAIL: rebuild frequency order mismatch"
  echo "Got: $rebuild_first, $rebuild_second, $rebuild_third"
  exit 1
fi

echo "PASS: history sort modes"
