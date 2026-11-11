#!/bin/bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
BREW_BIN="$(command -v brew)"
BREW_PREFIX="$("$BREW_BIN" --prefix)"
/bin/zsh -f -c '
  set -eu
  export PATH="/usr/bin:/bin:$1/bin"
  source "$2/zsh/init/09_homebrew.zsh"
  [[ $path[1] == "$1/bin" && $path[2] == "$1/sbin" ]]
  [[ $HOMEBREW_PREFIX == "$1" ]]
  original_path=$PATH
  source "$2/zsh/init/09_homebrew.zsh"
  [[ $PATH == $original_path ]]
  if [[ -x "$1/bin/rsync" ]]; then
    alias rsync="noglob rsync"
    [[ $(whence -p rsync) == "$1/bin/rsync" ]]
    [[ $(eval "rsync --version") == "$("$1/bin/rsync" --version)" ]]
  fi
' -- "$BREW_PREFIX" "$ROOT_DIR"
echo 'PASS: Homebrew path priority, reload, and rsync resolution'
