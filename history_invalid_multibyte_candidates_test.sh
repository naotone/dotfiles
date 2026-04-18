#!/bin/bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
TMP_DIR="$(mktemp -d /tmp/zsh_history_invalid_multibyte_candidates.XXXXXX)"

cleanup() {
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

HISTFILE_PATH="$TMP_DIR/history"
OUT_PATH="$TMP_DIR/out.tsv"

printf ': 1700000000:0;echo ok\n' > "$HISTFILE_PATH"
printf ': 1700000001:0;' >> "$HISTFILE_PATH"
printf '\377\376 pnpm android:device \n' >> "$HISTFILE_PATH"

zsh -c "
  set -euo pipefail
  source '$ROOT_DIR/zsh/init/40_history_sorting.zsh'
  dotfiles_history_generate_candidates '$HISTFILE_PATH' 'recent' '$OUT_PATH'
"

row_count="$(wc -l < "$OUT_PATH" | tr -d ' ')"
if [[ "$row_count" != "2" ]]; then
  echo "FAIL: invalid multibyte entries should still produce candidates"
  echo "Expected: 2"
  echo "Got: ${row_count:-<empty>}"
  exit 1
fi

if ! LC_ALL=C grep -aFq $'\techo ok\techo ok' "$OUT_PATH"; then
  echo "FAIL: valid entries disappeared after parsing invalid bytes"
  exit 1
fi

echo "PASS: invalid multibyte entries do not break candidate generation"
