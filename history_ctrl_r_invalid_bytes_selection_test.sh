#!/bin/bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
TMP_DIR="$(mktemp -d /tmp/zsh_history_ctrl_r_invalid_bytes.XXXXXX)"
TMP_HISTFILE="$TMP_DIR/history"
TMP_BIN="$TMP_DIR/bin"
TMP_SORTING="$TMP_DIR/history_sorting_stub.zsh"

cleanup() {
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

mkdir -p "$TMP_BIN"

cat > "$TMP_HISTFILE" <<'EOF'
: 1700000000:0;echo seed
EOF

cat > "$TMP_BIN/fzf" <<'EOF'
#!/bin/bash
set -euo pipefail

input_file="${DOTFILES_FZF_TEST_INPUT_FILE:-}"
if [[ -z "$input_file" ]]; then
  cat >/dev/null
  exit 1
fi

cat > "$input_file"
IFS= read -r first_candidate < "$input_file" || true
printf '%s\n' "$first_candidate"
EOF
chmod +x "$TMP_BIN/fzf"

cat > "$TMP_SORTING" <<'EOF'
function dotfiles_history_generate_candidates() {
  local histfile="$1"
  local mode="$2"
  local outfile="$3"

  printf '1\t1\t1\t\377\376 pnpm android:device \t\377\376 pnpm android:device \n' > "$outfile"
}
EOF

printf '\377\376 pnpm android:device ' > "$TMP_DIR/expected.bin"

zsh -f -c "
  set -euo pipefail

  export PATH='$TMP_BIN':\$PATH
  export HISTFILE='$TMP_HISTFILE'
  export DOTFILES_HISTORY_SORTING_SCRIPT_PATH='$TMP_SORTING'
  export DOTFILES_FZF_TEST_INPUT_FILE='$TMP_DIR/fzf_input.tsv'

  source '$ROOT_DIR/zsh/init/21_functions_fzf.zsh'

  BUFFER=''
  LBUFFER=''

  fzf-select-history >/dev/null
  printf '%s' \"\$BUFFER\" > '$TMP_DIR/actual.bin'
"

if ! cmp -s "$TMP_DIR/expected.bin" "$TMP_DIR/actual.bin"; then
  echo "FAIL: Ctrl-R did not restore the selected command with invalid bytes"
  echo "Expected hex: $(xxd -p -c 256 "$TMP_DIR/expected.bin")"
  echo "Actual hex:   $(xxd -p -c 256 "$TMP_DIR/actual.bin")"
  exit 1
fi

echo "PASS: Ctrl-R restores a selected command with invalid bytes"
