#!/bin/bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
HOOK_PATH="$ROOT_DIR/githooks/pre-push"
TMP_DIR="$(mktemp -d /tmp/dotfiles_githooks_pre_push.XXXXXX)"
ZERO_SHA=0000000000000000000000000000000000000000

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
}

commit_file() {
  local repo="$1"
  local path="$2"
  local content="$3"
  local message="$4"

  printf '%s\n' "$content" > "$repo/$path"
  git -C "$repo" add "$path"
  git -C "$repo" -c core.hooksPath=/dev/null commit -m "$message" --no-gpg-sign >/dev/null
}

assert_file_executable "$HOOK_PATH"

reject_repo="$TMP_DIR/reject"
init_repo "$reject_repo"
commit_file "$reject_repo" base.txt base base
base_sha="$(git -C "$reject_repo" rev-parse HEAD)"
git -C "$reject_repo" update-ref refs/remotes/origin/main "$base_sha"
commit_file "$reject_repo" change.txt change unsigned-change
change_sha="$(git -C "$reject_repo" rev-parse HEAD)"
change_short="$(git -C "$reject_repo" rev-parse --short "$change_sha")"
reject_input="refs/heads/main $change_sha refs/heads/main $base_sha"

set +e
reject_output="$(cd "$reject_repo" && printf '%s\n' "$reject_input" | "$HOOK_PATH" origin git@example.com:repo.git 2>&1)"
reject_status=$?
set -e

if [ "$reject_status" -eq 0 ]; then
  echo "FAIL: unsigned pushed commit was not rejected"
  exit 1
fi

if ! printf '%s\n' "$reject_output" | grep -Fq "$change_short unsigned-change"; then
  echo "FAIL: rejection did not include unsigned commit summary"
  printf '%s\n' "$reject_output"
  exit 1
fi

new_branch_repo="$TMP_DIR/new-branch"
init_repo "$new_branch_repo"
commit_file "$new_branch_repo" base.txt base already-on-origin
origin_sha="$(git -C "$new_branch_repo" rev-parse HEAD)"
git -C "$new_branch_repo" update-ref refs/remotes/origin/main "$origin_sha"
new_branch_input="refs/heads/topic $origin_sha refs/heads/topic $ZERO_SHA"

set +e
new_branch_output="$(cd "$new_branch_repo" && printf '%s\n' "$new_branch_input" | "$HOOK_PATH" origin git@example.com:repo.git 2>&1)"
new_branch_status=$?
set -e

if [ "$new_branch_status" -ne 0 ]; then
  echo "FAIL: new branch push checked commits already reachable from origin"
  printf '%s\n' "$new_branch_output"
  exit 1
fi

delete_repo="$TMP_DIR/delete"
init_repo "$delete_repo"
delete_input="(delete) $ZERO_SHA refs/heads/old-topic 1234567890123456789012345678901234567890"

set +e
delete_output="$(cd "$delete_repo" && printf '%s\n' "$delete_input" | "$HOOK_PATH" origin git@example.com:repo.git 2>&1)"
delete_status=$?
set -e

if [ "$delete_status" -ne 0 ]; then
  echo "FAIL: delete push should bypass signature checks"
  printf '%s\n' "$delete_output"
  exit 1
fi

chain_repo="$TMP_DIR/chain"
init_repo "$chain_repo"
mkdir -p "$chain_repo/.git/hooks"
cat > "$chain_repo/.git/hooks/pre-push" <<'LOCAL_HOOK'
#!/bin/sh

{
  printf 'args:%s|%s\n' "$1" "$2"
  cat
} > "$LOCAL_HOOK_MARKER"
LOCAL_HOOK
chmod +x "$chain_repo/.git/hooks/pre-push"

fake_bin="$TMP_DIR/fake-bin"
mkdir -p "$fake_bin"
cat > "$fake_bin/git" <<'FAKE_GIT'
#!/bin/sh

if [ "$1" = "rev-list" ]; then
  printf '%s\n' "$SIGNED_COMMIT"
  exit 0
fi

if [ "$1" = "log" ]; then
  if [ "$2" = "-1" ] && [ "$3" = "--format=%G?" ]; then
    printf 'G\n'
    exit 0
  fi

  if [ "$2" = "-1" ] && [ "$3" = "--format=%h %s" ]; then
    printf 'abc123 signed-change\n'
    exit 0
  fi
fi

if [ "$1" = "rev-parse" ] && [ "$2" = "--absolute-git-dir" ]; then
  printf '%s\n' "$FAKE_GIT_DIR"
  exit 0
fi

echo "unexpected fake git command: $*" >&2
exit 99
FAKE_GIT
chmod +x "$fake_bin/git"

signed_input="refs/heads/main fedcba9876543210fedcba9876543210fedcba98 refs/heads/main 0123456789012345678901234567890123456789"
LOCAL_HOOK_MARKER="$TMP_DIR/local-pre-push-marker" \
  SIGNED_COMMIT=fedcba9876543210fedcba9876543210fedcba98 \
  FAKE_GIT_DIR="$chain_repo/.git" \
  PATH="$fake_bin:$PATH" \
  "$HOOK_PATH" origin git@example.com:repo.git <<EOF
$signed_input
EOF

expected_marker="$(printf 'args:origin|git@example.com:repo.git\n%s\n' "$signed_input")"
actual_marker="$(cat "$TMP_DIR/local-pre-push-marker" 2>/dev/null || true)"

if [ "$actual_marker" != "$expected_marker" ]; then
  echo "FAIL: local pre-push hook did not receive original args and stdin"
  printf 'expected:\n%s\nactual:\n%s\n' "$expected_marker" "$actual_marker"
  exit 1
fi

echo 'PASS: githooks pre-push rejects unsigned pushes and chains local hook'
