#!/bin/bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
GIT_CONFIG_FILE="$ROOT_DIR/.gitconfig"
BREW_FILE="$ROOT_DIR/brew.sh"

fail() {
  echo "FAIL: $1"
  exit 1
}

if [[ "$(git config --file "$GIT_CONFIG_FILE" --get core.pager)" != 'hunk pager' ]]; then
  fail 'Git core pager is not configured for Hunk'
fi

if git config --file "$GIT_CONFIG_FILE" --get interactive.diffFilter >/dev/null 2>&1; then
  fail 'delta interactive diff filter remains configured'
fi

if git config --file "$GIT_CONFIG_FILE" --get-regexp '^delta\.' >/dev/null 2>&1; then
  fail 'delta configuration remains in .gitconfig'
fi

if ! rg -q '^  hunk$' "$BREW_FILE"; then
  fail 'Homebrew package list does not include hunk'
fi

if rg -q '^  git-delta$' "$BREW_FILE"; then
  fail 'Homebrew package list still includes git-delta'
fi

bash -n "$BREW_FILE"
git config --file "$GIT_CONFIG_FILE" --list >/dev/null

echo 'PASS: Hunk Git integration is configured'
