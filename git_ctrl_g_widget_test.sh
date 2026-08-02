#!/bin/bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
TMP_DIR="$(mktemp -d /tmp/zsh_git_ctrl_g_widget.XXXXXX)"
REPO_DIR="$TMP_DIR/repo"
TMP_BIN="$TMP_DIR/bin"
FZF_INPUT_FILE="$TMP_DIR/fzf-input"
FZF_ARGS_FILE="$TMP_DIR/fzf-args"
ZLE_LOG_FILE="$TMP_DIR/zle-log"
BUFFER_FILE="$TMP_DIR/buffer"

cleanup() {
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

mkdir -p "$TMP_BIN"
git init -q -b main "$REPO_DIR"
git -C "$REPO_DIR" config user.name 'Dotfiles Test'
git -C "$REPO_DIR" config user.email 'dotfiles-test@example.com'
git -C "$REPO_DIR" config commit.gpgSign false
git -C "$REPO_DIR" config core.hooksPath "$TMP_DIR/no-hooks"
printf '%s\n' 'initial' > "$REPO_DIR/tracked.txt"
git -C "$REPO_DIR" add tracked.txt
git -C "$REPO_DIR" commit -q -m 'initial'
git -C "$REPO_DIR" branch 'feature;unsafe'

cat > "$TMP_BIN/fzf" <<'EOF'
#!/bin/bash

set -euo pipefail

cat > "$DOTFILES_FZF_INPUT_FILE"
printf '%s\n' "$@" > "$DOTFILES_FZF_ARGS_FILE"

if [[ "${DOTFILES_FZF_CANCEL:-0}" == '1' ]]; then
  exit 130
fi

printf '%s\n' "$DOTFILES_FZF_SELECTION"
EOF
chmod +x "$TMP_BIN/fzf"

PATH="$TMP_BIN:$PATH" \
  DOTFILES_GIT_SWITCH_CANDIDATES_SCRIPT_PATH="$ROOT_DIR/zsh/scripts/generate-git-switch-candidates.zsh" \
  DOTFILES_FZF_INPUT_FILE="$FZF_INPUT_FILE" \
  DOTFILES_FZF_ARGS_FILE="$FZF_ARGS_FILE" \
  DOTFILES_FZF_SELECTION='feature;unsafe' \
  DOTFILES_ZLE_LOG_FILE="$ZLE_LOG_FILE" \
  DOTFILES_BUFFER_FILE="$BUFFER_FILE" \
  DOTFILES_REPO_DIR="$REPO_DIR" \
  zsh -f -c '
    function zle() {
      if [[ "${1:-}" == "-N" ]]; then
        return 0
      fi

      print -r -- "$*" >> "$DOTFILES_ZLE_LOG_FILE"
    }

    source "'$ROOT_DIR'/zsh/init/21_functions_fzf.zsh"
    cd "$DOTFILES_REPO_DIR"
    BUFFER="before"
    CURSOR=$#BUFFER
    fzf-git-switch
    print -r -- "$BUFFER" >| "$DOTFILES_BUFFER_FILE"
  '

if [[ "$(cat "$BUFFER_FILE")" != 'git switch feature\;unsafe' ]]; then
  echo 'FAIL: Ctrl-G does not shell-quote the selected branch'
  exit 1
fi

if ! grep -Fxq 'zle accept-line' "$ZLE_LOG_FILE" && ! grep -Fxq 'accept-line' "$ZLE_LOG_FILE"; then
  echo 'FAIL: Ctrl-G does not execute the selected git switch command'
  exit 1
fi

if ! grep -Fxq 'feature;unsafe' "$FZF_INPUT_FILE"; then
  echo 'FAIL: Ctrl-G does not pass local branches to fzf'
  exit 1
fi

if ! grep -Fxq -- '--no-sort' "$FZF_ARGS_FILE"; then
  echo 'FAIL: Ctrl-G does not preserve branch history order'
  exit 1
fi

accept_count_before="$(grep -Fxc 'accept-line' "$ZLE_LOG_FILE" || true)"

PATH="$TMP_BIN:$PATH" \
  DOTFILES_GIT_SWITCH_CANDIDATES_SCRIPT_PATH="$ROOT_DIR/zsh/scripts/generate-git-switch-candidates.zsh" \
  DOTFILES_FZF_INPUT_FILE="$FZF_INPUT_FILE" \
  DOTFILES_FZF_ARGS_FILE="$FZF_ARGS_FILE" \
  DOTFILES_FZF_SELECTION='feature;unsafe' \
  DOTFILES_FZF_CANCEL=1 \
  DOTFILES_ZLE_LOG_FILE="$ZLE_LOG_FILE" \
  DOTFILES_BUFFER_FILE="$BUFFER_FILE" \
  DOTFILES_REPO_DIR="$REPO_DIR" \
  zsh -f -c '
    function zle() {
      if [[ "${1:-}" == "-N" ]]; then
        return 0
      fi

      print -r -- "$*" >> "$DOTFILES_ZLE_LOG_FILE"
    }

    source "'$ROOT_DIR'/zsh/init/21_functions_fzf.zsh"
    cd "$DOTFILES_REPO_DIR"
    BUFFER="keep this"
    CURSOR=$#BUFFER
    fzf-git-switch || true
    print -r -- "$BUFFER" >| "$DOTFILES_BUFFER_FILE"
  '

if [[ "$(cat "$BUFFER_FILE")" != 'keep this' ]]; then
  echo 'FAIL: cancelling Ctrl-G changes the command buffer'
  exit 1
fi

accept_count_after="$(grep -Fxc 'accept-line' "$ZLE_LOG_FILE" || true)"
if [[ "$accept_count_after" != "$accept_count_before" ]]; then
  echo 'FAIL: cancelling Ctrl-G executes a command'
  exit 1
fi

printf '%s\n' 'not-called' > "$FZF_ARGS_FILE"

PATH="$TMP_BIN:$PATH" \
  DOTFILES_GIT_SWITCH_CANDIDATES_SCRIPT_PATH="$ROOT_DIR/zsh/scripts/generate-git-switch-candidates.zsh" \
  DOTFILES_FZF_INPUT_FILE="$FZF_INPUT_FILE" \
  DOTFILES_FZF_ARGS_FILE="$FZF_ARGS_FILE" \
  DOTFILES_FZF_SELECTION='feature;unsafe' \
  DOTFILES_ZLE_LOG_FILE="$ZLE_LOG_FILE" \
  DOTFILES_BUFFER_FILE="$BUFFER_FILE" \
  DOTFILES_NON_REPO_DIR="$TMP_DIR" \
  zsh -f -c '
    function zle() {
      if [[ "${1:-}" == "-N" ]]; then
        return 0
      fi

      print -r -- "$*" >> "$DOTFILES_ZLE_LOG_FILE"
    }

    source "'$ROOT_DIR'/zsh/init/21_functions_fzf.zsh"
    cd "$DOTFILES_NON_REPO_DIR"
    BUFFER="outside repo"
    CURSOR=$#BUFFER
    fzf-git-switch || true
    print -r -- "$BUFFER" >| "$DOTFILES_BUFFER_FILE"
  '

if [[ "$(cat "$BUFFER_FILE")" != 'outside repo' ]]; then
  echo 'FAIL: Ctrl-G changes the command buffer outside a Git repository'
  exit 1
fi

if [[ "$(cat "$FZF_ARGS_FILE")" != 'not-called' ]]; then
  echo 'FAIL: Ctrl-G launches fzf outside a Git repository'
  exit 1
fi

EMPTY_REPO_DIR="$TMP_DIR/empty-repo"
git init -q -b main "$EMPTY_REPO_DIR"
git -C "$EMPTY_REPO_DIR" config user.name 'Dotfiles Test'
git -C "$EMPTY_REPO_DIR" config user.email 'dotfiles-test@example.com'
git -C "$EMPTY_REPO_DIR" config commit.gpgSign false
git -C "$EMPTY_REPO_DIR" config core.hooksPath "$TMP_DIR/no-hooks"
printf '%s\n' 'initial' > "$EMPTY_REPO_DIR/tracked.txt"
git -C "$EMPTY_REPO_DIR" add tracked.txt
git -C "$EMPTY_REPO_DIR" commit -q -m 'initial'

PATH="$TMP_BIN:$PATH" \
  DOTFILES_GIT_SWITCH_CANDIDATES_SCRIPT_PATH="$ROOT_DIR/zsh/scripts/generate-git-switch-candidates.zsh" \
  DOTFILES_FZF_INPUT_FILE="$FZF_INPUT_FILE" \
  DOTFILES_FZF_ARGS_FILE="$FZF_ARGS_FILE" \
  DOTFILES_FZF_SELECTION='feature;unsafe' \
  DOTFILES_ZLE_LOG_FILE="$ZLE_LOG_FILE" \
  DOTFILES_BUFFER_FILE="$BUFFER_FILE" \
  DOTFILES_EMPTY_REPO_DIR="$EMPTY_REPO_DIR" \
  zsh -f -c '
    function zle() {
      if [[ "${1:-}" == "-N" ]]; then
        return 0
      fi

      print -r -- "$*" >> "$DOTFILES_ZLE_LOG_FILE"
    }

    source "'$ROOT_DIR'/zsh/init/21_functions_fzf.zsh"
    cd "$DOTFILES_EMPTY_REPO_DIR"
    BUFFER="only branch"
    CURSOR=$#BUFFER
    fzf-git-switch
    print -r -- "$BUFFER" >| "$DOTFILES_BUFFER_FILE"
  '

if [[ "$(cat "$BUFFER_FILE")" != 'only branch' ]]; then
  echo 'FAIL: Ctrl-G changes the command buffer without switch candidates'
  exit 1
fi

if [[ "$(cat "$FZF_ARGS_FILE")" != 'not-called' ]]; then
  echo 'FAIL: Ctrl-G launches fzf without switch candidates'
  exit 1
fi

binding="$(zsh -f -c "source '$ROOT_DIR/zsh/init/21_functions_fzf.zsh'; source '$ROOT_DIR/zsh/init/50_keybinds.zsh'; bindkey '^G'")"
if [[ "$binding" != *'fzf-git-switch'* ]]; then
  echo 'FAIL: Ctrl-G is not bound to fzf-git-switch'
  exit 1
fi

echo 'PASS: Ctrl-G switches the selected local branch'
