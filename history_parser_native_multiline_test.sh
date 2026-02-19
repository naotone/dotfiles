#!/bin/bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
TMP_DIR="$(mktemp -d /tmp/zsh_history_parser_native_multiline.XXXXXX)"

cleanup() {
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

HISTFILE_PATH="$TMP_DIR/history"
OUT_PATH="$TMP_DIR/out.tsv"

cat > "$HISTFILE_PATH" <<'HISTEOF'
: 1700000000:0;echo first\
second
: 1700000001:0;echo keep
HISTEOF

zsh -c "
  set -euo pipefail
  source '$ROOT_DIR/zsh/init/40_history_sorting.zsh'
  dotfiles_history_generate_candidates '$HISTFILE_PATH' 'recent' '$OUT_PATH'
"

first_nf="$(awk -F'\t' 'NR==1 {print NF}' "$OUT_PATH")"
if [[ "$first_nf" != "5" ]]; then
  echo "FAIL: candidate field count mismatch"
  echo "Expected: 5"
  echo "Got: ${first_nf:-<empty>}"
  exit 1
fi

first_start="$(awk -F'\t' 'NR==1 {print $2}' "$OUT_PATH")"
first_end="$(awk -F'\t' 'NR==1 {print $3}' "$OUT_PATH")"
if [[ "$first_start" != "3" || "$first_end" != "3" ]]; then
  echo "FAIL: latest entry line range mismatch"
  echo "Expected: 3-3"
  echo "Got: ${first_start:-<empty>}-${first_end:-<empty>}"
  exit 1
fi

second_start="$(awk -F'\t' 'NR==2 {print $2}' "$OUT_PATH")"
second_end="$(awk -F'\t' 'NR==2 {print $3}' "$OUT_PATH")"
if [[ "$second_start" != "1" || "$second_end" != "2" ]]; then
  echo "FAIL: multiline entry line range mismatch"
  echo "Expected: 1-2"
  echo "Got: ${second_start:-<empty>}-${second_end:-<empty>}"
  exit 1
fi

second_encoded="$(awk -F'\t' 'NR==2 {print $4}' "$OUT_PATH")"
second_decoded="$(printf '%b' "$second_encoded")"

if [[ "$second_decoded" != $'echo first\nsecond' ]]; then
  echo "FAIL: multiline command decode mismatch"
  echo "Expected: echo first\\nsecond"
  echo "Got: $second_decoded"
  exit 1
fi

echo "PASS: native multiline parser"
