#!/bin/bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
TMP_DIR="$(mktemp -d /tmp/zsh_history_ctrl_r_recent.XXXXXX)"
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
awk 'NR == 1 { print; exit }' "$input_file"
EOF
chmod +x "$TMP_BIN/fzf"

cat > "$TMP_SORTING" <<'EOF'
function dotfiles_history_generate_candidates() {
  local histfile="$1"
  local mode="$2"
  local outfile="$3"

  if [[ "$mode" == "recent" ]]; then
    print -r -- $'1\t1\t1\trecent_cmd\trecent_cmd' >| "$outfile"
  else
    print -r -- $'1\t1\t1\tfrequency_cmd\tfrequency_cmd' >| "$outfile"
  fi
}
EOF

zsh -f -c "
  set -euo pipefail

  export PATH='$TMP_BIN':\$PATH
  export HISTFILE='$TMP_HISTFILE'
  export DOTFILES_HISTORY_SORTING_SCRIPT_PATH='$TMP_SORTING'
  export DOTFILES_CTRL_R_HISTORY_SORT_MODE='frequency'
  export DOTFILES_FZF_TEST_INPUT_FILE='$TMP_DIR/fzf_input.tsv'

  source '$ROOT_DIR/zsh/init/21_functions_fzf.zsh'

  BUFFER=''
  LBUFFER=''

  fzf-select-history >/dev/null
"

first_candidate="$(awk 'NR == 1 { print; exit }' "$TMP_DIR/fzf_input.tsv")"

if [[ -z "$first_candidate" ]]; then
  echo "FAIL: no candidate was passed to fzf"
  exit 1
fi

if [[ "$first_candidate" != *$'\trecent_cmd\trecent_cmd' ]]; then
  echo "FAIL: Ctrl-R initial sort is not recent"
  echo "Expected candidate suffix: recent_cmd"
  echo "Got: $first_candidate"
  exit 1
fi

echo "PASS: Ctrl-R starts in recent mode"
