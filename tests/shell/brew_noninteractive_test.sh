#!/bin/bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"

xcode-select() { :; }
sudo() { :; }
brew() {
  case "$1" in
    upgrade|install)
      case " $* " in
        *' --yes '*) ;;
        *) echo "FAIL: brew $1 requires --yes" >&2; exit 1 ;;
      esac
      ;;
    update) ;;
    *) echo "FAIL: unexpected brew command: $1" >&2; exit 1 ;;
  esac
}

source "$ROOT_DIR/brew.sh"
echo 'PASS: Homebrew upgrade and installs skip confirmation'
