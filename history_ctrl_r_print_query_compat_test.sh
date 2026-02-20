#!/bin/bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
TMP_DIR="$(mktemp -d /tmp/zsh_history_ctrl_r_print_query.XXXXXX)"
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
input_file="${DOTFILES_FZF_TEST_INPUT_FILE:-}"
if [[ -z "$input_file" ]]; then
  cat >/dev/null
  exit 1
fi

cat > "$input_file"
first_candidate="$(awk 'NR == 1 { print; exit }' "$input_file")"

printf '\n'
printf '%s\n' "$first_candidate"
EOF
chmod +x "$TMP_BIN/fzf"

cat > "$TMP_SORTING" <<'EOF'
function dotfiles_history_generate_candidates() {
  local histfile="$1"
  local mode="$2"
  local outfile="$3"

  print -r -- $'1\t1\t1\techo selected\techo selected' >| "$outfile"
}
EOF

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
  print -r -- \"\$BUFFER\" > '$TMP_DIR/buffer.txt'
"

actual_buffer="$(cat "$TMP_DIR/buffer.txt")"

if [[ "$actual_buffer" != "echo selected" ]]; then
  echo "FAIL: Ctrl-R failed to restore selected command when query line exists"
  echo "Expected: echo selected"
  echo "Got: $actual_buffer"
  exit 1
fi

echo "PASS: Ctrl-R handles fzf output with query line"
