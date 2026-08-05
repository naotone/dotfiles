#!/bin/bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
TMP_DIR="$(mktemp -d /tmp/zsh_cdr_ctrl_u_delete.XXXXXX)"
RECENT_DIRS_FILE="$TMP_DIR/recent-dirs"
CDR_LIST_FILE="$TMP_DIR/cdr-list"
DELETED_LIST_FILE="$TMP_DIR/deleted-list"
TMP_BIN="$TMP_DIR/bin"
STALE_DIR='/Users/naotone/Downloads/Nudge Build 2 Build Products for Nudge on macOS'
FIND_ONLY_DIR="$TMP_DIR/find only directory"

cleanup() {
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

mkdir -p "$TMP_BIN"
mkdir -p "$FIND_ONLY_DIR"

cat > "$RECENT_DIRS_FILE" <<EOF
'$STALE_DIR'
'/tmp/cdr keep with spaces'
'/tmp/cdr-[keep]'
EOF

for index in $(seq 1 25); do
  printf "'/tmp/cdr-keep-%s'\n" "$index" >> "$RECENT_DIRS_FILE"
done

zsh "$ROOT_DIR/zsh/scripts/delete-cdr-history-entry.zsh" \
  "$RECENT_DIRS_FILE" \
  "$STALE_DIR" \
  "$CDR_LIST_FILE" \
  500 \
  "$DELETED_LIST_FILE"

zsh -fc "
  zstyle ':chpwd:*' recent-dirs-file '$RECENT_DIRS_FILE'
  zstyle ':chpwd:*' recent-dirs-max 500
  autoload -Uz chpwd_recent_filehandler
  chpwd_recent_filehandler

  if (( \${reply[(Ie)$STALE_DIR]} )); then
    echo 'FAIL: stale directory containing spaces remains in recent directories'
    exit 1
  fi

  if (( ! \${reply[(Ie)/tmp/cdr keep with spaces]} )); then
    echo 'FAIL: directory containing spaces was not preserved'
    exit 1
  fi

  if (( ! \${reply[(Ie)/tmp/cdr-[keep]]} )); then
    echo 'FAIL: directory containing glob characters was not preserved'
    exit 1
  fi

  if (( ! \${reply[(Ie)/tmp/cdr-keep-25]} )); then
    echo 'FAIL: history beyond the default 20-entry limit was not preserved'
    exit 1
  fi
"

if grep -Fxq "$STALE_DIR" "$CDR_LIST_FILE"; then
  echo 'FAIL: stale directory remains in refreshed Ctrl-U list'
  exit 1
fi

if ! grep -Fxq '/tmp/cdr keep with spaces' "$CDR_LIST_FILE"; then
  echo 'FAIL: refreshed Ctrl-U list is missing a preserved directory'
  exit 1
fi

if ! grep -Fxq "$STALE_DIR" "$DELETED_LIST_FILE"; then
  echo 'FAIL: deleted stale directory was not suppressed for the current Ctrl-U session'
  exit 1
fi

recent_dirs_checksum="$(cksum < "$RECENT_DIRS_FILE")"

zsh "$ROOT_DIR/zsh/scripts/delete-cdr-history-entry.zsh" \
  "$RECENT_DIRS_FILE" \
  "$FIND_ONLY_DIR" \
  "$CDR_LIST_FILE" \
  500 \
  "$DELETED_LIST_FILE"

if [[ "$(cksum < "$RECENT_DIRS_FILE")" != "$recent_dirs_checksum" ]]; then
  echo 'FAIL: deleting a find-only candidate changed cdr history'
  exit 1
fi

if ! grep -Fxq "$FIND_ONLY_DIR" "$DELETED_LIST_FILE"; then
  echo 'FAIL: find-only candidate was not hidden for the current Ctrl-U session'
  exit 1
fi

cat > "$TMP_BIN/fzf" <<'EOF'
#!/bin/bash
set -euo pipefail

printf '%s\n' "$@" > "$DOTFILES_FZF_ARGS_FILE"

temp_dir="$(printf '%s\n' "$@" | sed -n 's#.*\(/tmp/zsh_cdr_find\.[^ /)]*\).*#\1#p' | head -n 1)"
if [[ -n "$temp_dir" ]]; then
  printf '%s\n' "$temp_dir" >> "$DOTFILES_FZF_TEMP_DIR_FILE"
  cp "$temp_dir/cdr-list" "$DOTFILES_FZF_CDR_CAPTURE_FILE"
fi
EOF
chmod +x "$TMP_BIN/fzf"

zsh -f -c "
  set -euo pipefail

  export PATH='$TMP_BIN':\$PATH
  export DOTFILES_CDR_DELETE_SCRIPT_PATH='$ROOT_DIR/zsh/scripts/delete-cdr-history-entry.zsh'
  export DOTFILES_CDR_GENERATOR_SCRIPT_PATH='$ROOT_DIR/zsh/scripts/generate-cdr-find-candidates.zsh'
  export DOTFILES_FZF_ARGS_FILE='$TMP_DIR/fzf-args.txt'
  export DOTFILES_FZF_TEMP_DIR_FILE='$TMP_DIR/fzf-temp-dir.txt'
  export DOTFILES_FZF_CDR_CAPTURE_FILE='$TMP_DIR/fzf-cdr-list.txt'

  function cdr() {
    if [[ "\${1:-}" == '-r' ]]; then
      reply=('$STALE_DIR')
    else
      print -r -- '1    ~/Downloads/Nudge\\ Build\\ 2\\ Build\\ Products\\ for\\ Nudge\\ on\\ macOS'
    fi
  }

  zstyle ':chpwd:*' recent-dirs-file '$RECENT_DIRS_FILE'
  source '$ROOT_DIR/zsh/init/21_functions_fzf.zsh'
  fzf-combined-cdr-find >/dev/null
  fzf-combined-cdr-find >/dev/null
"

if ! grep -Fxq "$STALE_DIR" "$TMP_DIR/fzf-cdr-list.txt"; then
  echo 'FAIL: Ctrl-U does not use the raw cdr path for deletion'
  exit 1
fi

if [[ "$(sort -u "$TMP_DIR/fzf-temp-dir.txt" | wc -l | tr -d ' ')" != '2' ]]; then
  echo 'FAIL: Ctrl-U invocations share a temporary directory'
  exit 1
fi

while IFS= read -r temp_dir; do
  if [[ -e "$temp_dir" ]]; then
    echo 'FAIL: Ctrl-U temporary directory remains after fzf exits'
    exit 1
  fi
done < "$TMP_DIR/fzf-temp-dir.txt"

if grep -Fxq -- '--no-sort' "$TMP_DIR/fzf-args.txt"; then
  echo 'FAIL: Ctrl-U disables relevance sorting'
  exit 1
fi

if ! grep -Fxq -- '--scheme=path' "$TMP_DIR/fzf-args.txt"; then
  echo 'FAIL: Ctrl-U does not use path relevance sorting'
  exit 1
fi

if ! grep -Fq 'ctrl-s:execute-silent(' "$TMP_DIR/fzf-args.txt" ||
  ! grep -Fq 'alt-s:execute-silent(' "$TMP_DIR/fzf-args.txt" ||
  [[ "$(grep -Fc '+toggle-sort+refresh-preview' "$TMP_DIR/fzf-args.txt")" != '2' ]]; then
  echo 'FAIL: Ctrl-U does not register Ctrl-S and Alt-S sort toggles'
  exit 1
fi

if ! grep -Fq 'Ctrl-S / Alt-S: toggle sort (path relevance <-> recent)' "$TMP_DIR/fzf-args.txt"; then
  echo 'FAIL: Ctrl-U header does not explain sort toggling'
  exit 1
fi

if ! grep -Fq "Sort\\033[0m: %s" "$TMP_DIR/fzf-args.txt" ||
  ! grep -Fq 'path relevance' "$TMP_DIR/fzf-args.txt" ||
  ! grep -Fq 'recent' "$TMP_DIR/fzf-args.txt"; then
  echo 'FAIL: Ctrl-U preview does not show the current sort mode'
  exit 1
fi

if ! grep -Fxq -- $'--delimiter=\t' "$TMP_DIR/fzf-args.txt" ||
  ! grep -Fxq -- '--with-nth=2' "$TMP_DIR/fzf-args.txt" ||
  ! grep -Fxq -- '--accept-nth=1' "$TMP_DIR/fzf-args.txt"; then
  echo 'FAIL: Ctrl-U does not separate display and absolute path fields'
  exit 1
fi

if ! grep -Fq 'ctrl-x:execute-silent(' "$TMP_DIR/fzf-args.txt"; then
  echo 'FAIL: Ctrl-U does not register a Ctrl-X bind'
  exit 1
fi

if ! grep -Fq "$ROOT_DIR/zsh/scripts/delete-cdr-history-entry.zsh" "$TMP_DIR/fzf-args.txt"; then
  echo 'FAIL: Ctrl-X bind does not invoke the cdr history deletion script'
  exit 1
fi

if ! grep -Fq "$ROOT_DIR/zsh/scripts/generate-cdr-find-candidates.zsh" "$TMP_DIR/fzf-args.txt"; then
  echo 'FAIL: Ctrl-U does not reload ordered cdr and find candidates'
  exit 1
fi

if ! grep -Fq "{3}" "$TMP_DIR/fzf-args.txt" || ! grep -Fq "{2}" "$TMP_DIR/fzf-args.txt"; then
  echo 'FAIL: Ctrl-U preview does not use display path and source fields'
  exit 1
fi

if ! grep -Fq "{1}" "$TMP_DIR/fzf-args.txt"; then
  echo 'FAIL: Ctrl-U actions do not use the absolute path field'
  exit 1
fi

if ! grep -Fq 'Ctrl-X: remove history / hide search result for this menu' "$TMP_DIR/fzf-args.txt"; then
  echo 'FAIL: Ctrl-U header does not explain source-specific Ctrl-X behavior'
  exit 1
fi

echo 'PASS: Ctrl-U deletes the selected cdr history entry'
