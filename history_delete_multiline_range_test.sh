#!/bin/bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
TMP_HISTFILE="$(mktemp /tmp/zsh_history_delete_multiline.XXXXXX)"

cleanup() {
  rm -f "$TMP_HISTFILE"
}
trap cleanup EXIT

zsh -i -c "
  source '$ROOT_DIR/zsh/init/21_functions_fzf.zsh'

  cat >| '$TMP_HISTFILE' <<'EOF'
: 1700000000:0;echo before\\
after
: 1700000001:0;echo keep
EOF

  dotfiles_history_delete_history_range '$TMP_HISTFILE' 1 2

  if grep -Fxq 'after' '$TMP_HISTFILE'; then
    echo 'FAIL: orphan continuation line remains'
    exit 1
  fi

  if grep -E '^: [0-9]+:[0-9]+;echo before' '$TMP_HISTFILE' >/dev/null; then
    echo 'FAIL: multiline header line remains'
    exit 1
  fi

  if ! grep -E '^: [0-9]+:[0-9]+;echo keep' '$TMP_HISTFILE' >/dev/null; then
    echo 'FAIL: expected remaining command missing'
    exit 1
  fi

  echo 'PASS: multiline range delete'
"
