#!/bin/bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
TMP_HISTFILE="$(mktemp /tmp/zsh_history_prefixes.XXXXXX)"

cleanup() {
  rm -f "$TMP_HISTFILE"
}
trap cleanup EXIT

zsh -f -i -c "
  source '$ROOT_DIR/zsh/init/80_others.zsh'

  HISTFILE='$TMP_HISTFILE'
  HISTSIZE=1000
  SAVEHIST=1000
  setopt EXTENDED_HISTORY

  : >| '$TMP_HISTFILE'

  zshaddhistory 'echo plain' || true
  zshaddhistory 'VAR=1 echo prefixed' || true
  zshaddhistory 'noglob echo wrapped' || true

  fc -W '$TMP_HISTFILE'

  stripped=\$(sed -n 's/^: [0-9]*:[0-9]*;//p' '$TMP_HISTFILE')

  if ! printf '%s\n' \"\$stripped\" | grep -Fxq 'echo plain'; then
    echo 'FAIL: plain command missing'
    exit 1
  fi

  if ! printf '%s\n' \"\$stripped\" | grep -Fxq 'VAR=1 echo prefixed'; then
    echo 'FAIL: prefixed command missing'
    exit 1
  fi

  if ! printf '%s\n' \"\$stripped\" | grep -Fxq 'noglob echo wrapped'; then
    echo 'FAIL: command-prefix keyword entry missing'
    exit 1
  fi

  echo 'PASS: zshaddhistory prefixes'
"
