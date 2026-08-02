#!/bin/bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
TMP_DIR="$(mktemp -d /tmp/zsh_git_ctrl_g_candidates.XXXXXX)"
REPO_DIR="$TMP_DIR/repo"
WORKTREE_DIR="$TMP_DIR/occupied-worktree"
ACTUAL_CANDIDATES="$TMP_DIR/actual-candidates"
EXPECTED_CANDIDATES="$TMP_DIR/expected-candidates"

cleanup() {
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

git init -q -b main "$REPO_DIR"
git -C "$REPO_DIR" config user.name 'Dotfiles Test'
git -C "$REPO_DIR" config user.email 'dotfiles-test@example.com'
git -C "$REPO_DIR" config commit.gpgSign false
git -C "$REPO_DIR" config core.hooksPath "$TMP_DIR/no-hooks"

printf '%s\n' 'initial' > "$REPO_DIR/tracked.txt"
git -C "$REPO_DIR" add tracked.txt
GIT_AUTHOR_DATE='2022-01-01T00:00:00Z' \
  GIT_COMMITTER_DATE='2022-01-01T00:00:00Z' \
  git -C "$REPO_DIR" commit -q -m 'initial'

base_commit="$(git -C "$REPO_DIR" rev-parse HEAD)"
tree="$(git -C "$REPO_DIR" rev-parse 'HEAD^{tree}')"

old_commit="$(
  printf '%s\n' 'old unseen branch' |
    GIT_AUTHOR_NAME='Dotfiles Test' \
      GIT_AUTHOR_EMAIL='dotfiles-test@example.com' \
      GIT_COMMITTER_NAME='Dotfiles Test' \
      GIT_COMMITTER_EMAIL='dotfiles-test@example.com' \
      GIT_AUTHOR_DATE='2023-01-01T00:00:00Z' \
      GIT_COMMITTER_DATE='2023-01-01T00:00:00Z' \
      git -C "$REPO_DIR" commit-tree "$tree" -p "$base_commit"
)"
new_commit="$(
  printf '%s\n' 'new unseen branch' |
    GIT_AUTHOR_NAME='Dotfiles Test' \
      GIT_AUTHOR_EMAIL='dotfiles-test@example.com' \
      GIT_COMMITTER_NAME='Dotfiles Test' \
      GIT_COMMITTER_EMAIL='dotfiles-test@example.com' \
      GIT_AUTHOR_DATE='2024-01-01T00:00:00Z' \
      GIT_COMMITTER_DATE='2024-01-01T00:00:00Z' \
      git -C "$REPO_DIR" commit-tree "$tree" -p "$old_commit"
)"

git -C "$REPO_DIR" branch unseen-old "$old_commit"
git -C "$REPO_DIR" branch unseen-new "$new_commit"
git -C "$REPO_DIR" branch recent-a "$base_commit"
git -C "$REPO_DIR" branch recent-b "$base_commit"
git -C "$REPO_DIR" branch occupied "$base_commit"
git -C "$REPO_DIR" worktree add -q "$WORKTREE_DIR" occupied

git -C "$REPO_DIR" switch -q recent-b
git -C "$REPO_DIR" switch -q recent-a
git -C "$REPO_DIR" switch -q recent-b
git -C "$REPO_DIR" switch -q recent-a

(
  cd "$REPO_DIR"
  zsh "$ROOT_DIR/zsh/scripts/generate-git-switch-candidates.zsh"
) > "$ACTUAL_CANDIDATES"

if grep -Fxq 'occupied' "$ACTUAL_CANDIDATES"; then
  echo 'FAIL: branch checked out in another worktree remains selectable'
  exit 1
fi

cat > "$EXPECTED_CANDIDATES" <<'EOF'
recent-b
unseen-new
unseen-old
main
EOF

if ! cmp -s "$EXPECTED_CANDIDATES" "$ACTUAL_CANDIDATES"; then
  echo 'FAIL: Ctrl-G candidates are not ordered by switch history and commit recency'
  diff -u "$EXPECTED_CANDIDATES" "$ACTUAL_CANDIDATES" || true
  exit 1
fi

if grep -Fxq 'recent-a' "$ACTUAL_CANDIDATES"; then
  echo 'FAIL: current branch remains in Ctrl-G candidates'
  exit 1
fi

if [[ "$(grep -Fxc 'recent-b' "$ACTUAL_CANDIDATES")" != '1' ]]; then
  echo 'FAIL: repeated switch history is not deduplicated'
  exit 1
fi

echo 'PASS: Ctrl-G prioritizes recent local branch switches'
