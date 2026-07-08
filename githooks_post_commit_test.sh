#!/bin/bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
HOOK_PATH="$ROOT_DIR/githooks/post-commit"
TMP_DIR="$(mktemp -d /tmp/dotfiles_githooks_post_commit.XXXXXX)"

cleanup() {
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

assert_file_executable() {
  local path="$1"

  if [ ! -x "$path" ]; then
    echo "FAIL: expected executable hook at $path"
    exit 1
  fi
}

init_repo() {
  local repo="$1"

  git init "$repo" >/dev/null
  git -C "$repo" config user.name Test
  git -C "$repo" config user.email test@example.com
  git -C "$repo" config commit.gpgsign false
  git -C "$repo" config core.hooksPath "$ROOT_DIR/githooks"
}

assert_staged() {
  local repo="$1"
  local path="$2"

  if ! git -C "$repo" diff --cached --name-only | grep -Fxq "$path"; then
    echo "FAIL: expected $path to stay staged"
    exit 1
  fi
}

assert_file_executable "$HOOK_PATH"

normal_repo="$TMP_DIR/normal"
init_repo "$normal_repo"
printf 'seed\n' > "$normal_repo/seed.txt"
git -C "$normal_repo" add seed.txt
git -C "$normal_repo" -c core.hooksPath=/dev/null commit -m seed --no-gpg-sign >/dev/null
seed_head="$(git -C "$normal_repo" rev-parse HEAD)"

printf 'change\n' > "$normal_repo/change.txt"
git -C "$normal_repo" add change.txt
git -C "$normal_repo" commit -m change --no-gpg-sign >/dev/null 2>&1 || true

if [ "$(git -C "$normal_repo" rev-parse HEAD)" != "$seed_head" ]; then
  echo "FAIL: unsigned commit was not reset to the previous HEAD"
  exit 1
fi
assert_staged "$normal_repo" change.txt

initial_repo="$TMP_DIR/initial"
init_repo "$initial_repo"
printf 'first\n' > "$initial_repo/first.txt"
git -C "$initial_repo" add first.txt
git -C "$initial_repo" commit -m first --no-gpg-sign >/dev/null 2>&1 || true

if git -C "$initial_repo" rev-parse --verify HEAD >/dev/null 2>&1; then
  echo "FAIL: unsigned initial commit left HEAD in place"
  exit 1
fi
assert_staged "$initial_repo" first.txt

chain_repo="$TMP_DIR/chain"
init_repo "$chain_repo"
mkdir -p "$chain_repo/.git/hooks"
printf '#!/bin/sh\nprintf local-hook-ran > "$LOCAL_HOOK_MARKER"\n' > "$chain_repo/.git/hooks/post-commit"
chmod +x "$chain_repo/.git/hooks/post-commit"

fake_bin="$TMP_DIR/fake-bin"
mkdir -p "$fake_bin"
cat > "$fake_bin/git" <<'FAKE_GIT'
#!/bin/sh

if [ "$1" = "log" ]; then
  printf 'G\n'
  exit 0
fi

if [ "$1" = "rev-parse" ] && [ "$2" = "--absolute-git-dir" ]; then
  printf '%s\n' "$FAKE_GIT_DIR"
  exit 0
fi

echo "unexpected fake git command: $*" >&2
exit 99
FAKE_GIT
chmod +x "$fake_bin/git"

FAKE_GIT_DIR="$chain_repo/.git" LOCAL_HOOK_MARKER="$TMP_DIR/local-hook-marker" PATH="$fake_bin:$PATH" "$HOOK_PATH"

if [ "$(cat "$TMP_DIR/local-hook-marker" 2>/dev/null || true)" != "local-hook-ran" ]; then
  echo "FAIL: signed commit path did not run local post-commit hook"
  exit 1
fi

echo 'PASS: githooks post-commit rejects unsigned commits and chains local hook'
