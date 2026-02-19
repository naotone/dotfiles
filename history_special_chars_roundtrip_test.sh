#!/bin/bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
TMP_DIR="$(mktemp -d /tmp/zsh_history_special_chars_roundtrip.XXXXXX)"

cleanup() {
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

HISTFILE_PATH="$TMP_DIR/history"
OUT_PATH="$TMP_DIR/out.tsv"

{
  printf ': 1700000000:0;printf "a\tb"\n'
  printf ': 1700000001:0;echo line1\\\n'
  printf 'line2\n'
  printf ': 1700000002:0;echo literal\\ntext\n'
  printf ': 1700000003:0;echo backslash\\\\done\n'
} > "$HISTFILE_PATH"

zsh -c "
  set -euo pipefail
  source '$ROOT_DIR/zsh/init/40_history_sorting.zsh'
  dotfiles_history_generate_candidates '$HISTFILE_PATH' 'recent' '$OUT_PATH'
"

row_count="$(wc -l < "$OUT_PATH" | tr -d ' ')"
if [[ "$row_count" != "4" ]]; then
  echo "FAIL: candidate row count mismatch"
  echo "Expected: 4"
  echo "Got: ${row_count:-<empty>}"
  exit 1
fi

row1="$(printf '%b' "$(awk -F'\t' 'NR==1 {print $4}' "$OUT_PATH")")"
row2="$(printf '%b' "$(awk -F'\t' 'NR==2 {print $4}' "$OUT_PATH")")"
row3="$(printf '%b' "$(awk -F'\t' 'NR==3 {print $4}' "$OUT_PATH")")"
row4="$(printf '%b' "$(awk -F'\t' 'NR==4 {print $4}' "$OUT_PATH")")"

if [[ "$row1" != 'echo backslash\\done' ]]; then
  echo "FAIL: backslash round-trip mismatch"
  echo "Got: $row1"
  exit 1
fi

if [[ "$row2" != 'echo literal\ntext' ]]; then
  echo "FAIL: literal backslash-n round-trip mismatch"
  echo "Got: $row2"
  exit 1
fi

if [[ "$row3" != $'echo line1\nline2' ]]; then
  echo "FAIL: newline round-trip mismatch"
  echo "Got: $row3"
  exit 1
fi

if [[ "$row4" != $'printf "a\tb"' ]]; then
  echo "FAIL: tab round-trip mismatch"
  echo "Got: $row4"
  exit 1
fi

echo "PASS: special character round-trip"
