#!/bin/bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
TMP_HISTFILE="$(mktemp /tmp/zsh_history_sensitive_filter.XXXXXX)"

cleanup() {
  rm -f "$TMP_HISTFILE"
}
trap cleanup EXIT

export ROOT_DIR
export TMP_HISTFILE

commands=(
  'pkill -x Nudge || true'
  'apps/macos/scripts/build-app.sh && open -n apps/macos/build/Nudge.app'
  'git show 0123456789abcdef0123456789abcdef01234567'
  'AWS_PROFILE=dev pnpm deploy'
  'cmd --token-file ~/.config/service/token.txt'
  'DATABASE_URL=postgres://localhost/app pnpm prisma migrate dev'
  'echo uWwS/6GVsar7flr3gguh6Lnry4Cdb2a'
  'echo sk-proj-abcdefghijklmnopqrstuvwxyz0123456789'
  'OPENAI_API_KEY=sk-proj-abcdefghijklmnopqrstuvwxyz0123456789 next build'
  'DATABASE_URL=postgres://user:pass@example.com/app pnpm prisma migrate deploy'
  'cmd --token dGhpcy1pc19mYWtlX3NlY3JldF90b2tlbg== run'
  'curl -H "Authorization: Bearer eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiJ1c2VyMTIzNDU2Nzg5MCJ9.c2lnbmF0dXJlMTIzNDU2Nzg5MA" https://example.com'
  'TURSO_AUTH_TOKEN=abc/def/ghijklmnopqrstuvwxyz0123456789 next build'
)

zsh -f -i -c '
source "$ROOT_DIR/zsh/init/80_others.zsh"

HISTFILE="$TMP_HISTFILE"
HISTSIZE=1000
SAVEHIST=1000
setopt EXTENDED_HISTORY

: >| "$TMP_HISTFILE"

for command in "$@"; do
  zshaddhistory "$command" || true
done

fc -W "$TMP_HISTFILE"
' zsh "${commands[@]}"

stripped="$(sed -n 's/^: [0-9]*:[0-9]*;//p' "$TMP_HISTFILE")"

assert_present() {
  local command="$1"

  if ! printf '%s\n' "$stripped" | grep -Fxq "$command"; then
    echo "FAIL: expected history entry missing: $command"
    exit 1
  fi
}

assert_absent() {
  local command="$1"

  if printf '%s\n' "$stripped" | grep -Fxq "$command"; then
    echo "FAIL: sensitive history entry was saved: $command"
    exit 1
  fi
}

assert_present 'pkill -x Nudge || true'
assert_present 'apps/macos/scripts/build-app.sh && open -n apps/macos/build/Nudge.app'
assert_present 'git show 0123456789abcdef0123456789abcdef01234567'
assert_present 'AWS_PROFILE=dev pnpm deploy'
assert_present 'cmd --token-file ~/.config/service/token.txt'
assert_present 'DATABASE_URL=postgres://localhost/app pnpm prisma migrate dev'

assert_absent 'echo uWwS/6GVsar7flr3gguh6Lnry4Cdb2a'
assert_absent 'echo sk-proj-abcdefghijklmnopqrstuvwxyz0123456789'
assert_absent 'OPENAI_API_KEY=sk-proj-abcdefghijklmnopqrstuvwxyz0123456789 next build'
assert_absent 'DATABASE_URL=postgres://user:pass@example.com/app pnpm prisma migrate deploy'
assert_absent 'cmd --token dGhpcy1pc19mYWtlX3NlY3JldF90b2tlbg== run'
assert_absent 'curl -H "Authorization: Bearer eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiJ1c2VyMTIzNDU2Nzg5MCJ9.c2lnbmF0dXJlMTIzNDU2Nzg5MA" https://example.com'
assert_absent 'TURSO_AUTH_TOKEN=abc/def/ghijklmnopqrstuvwxyz0123456789 next build'

echo 'PASS: zshaddhistory sensitive filter'
