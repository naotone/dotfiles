#!/bin/bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
TMP_HOME="$(mktemp -d /tmp/dotfiles_deploy_hammerspoon.XXXXXX)"

cleanup() {
  rm -rf "$TMP_HOME"
}
trap cleanup EXIT

mkdir -p "$TMP_HOME/.hammerspoon"
mkdir -p "$TMP_HOME/.tmux/plugins/tpm"
printf 'legacy-config\n' > "$TMP_HOME/.hammerspoon/legacy.lua"

DOTPATH="$ROOT_DIR" HOME="$TMP_HOME" SSH_CLIENT=1 bash "$ROOT_DIR/etc/init/deploy.sh" >/dev/null

if [ ! -L "$TMP_HOME/.hammerspoon" ]; then
  echo "FAIL: ~/.hammerspoon is not a symlink after deploy"
  exit 1
fi

TARGET="$(readlink "$TMP_HOME/.hammerspoon")"
EXPECTED="$ROOT_DIR/.hammerspoon"
if [ "$TARGET" != "$EXPECTED" ]; then
  echo "FAIL: ~/.hammerspoon points to '$TARGET' (expected '$EXPECTED')"
  exit 1
fi

if [ -e "$TMP_HOME/.hammerspoon/.hammerspoon" ]; then
  echo "FAIL: deploy created nested ~/.hammerspoon/.hammerspoon link"
  exit 1
fi

BACKUP_DIR="$(find "$TMP_HOME" -maxdepth 1 -type d -name '.hammerspoon.backup.*' | head -n 1 || true)"
if [ -z "$BACKUP_DIR" ]; then
  echo "FAIL: legacy ~/.hammerspoon directory was not backed up"
  exit 1
fi

if [ ! -f "$BACKUP_DIR/legacy.lua" ]; then
  echo "FAIL: backup directory does not include previous files"
  exit 1
fi

echo "PASS: deploy replaces existing ~/.hammerspoon directory with symlink safely"
