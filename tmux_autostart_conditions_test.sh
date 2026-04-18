#!/bin/bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"

zsh -c "
  set -euo pipefail

  source '$ROOT_DIR/zsh/init/15_tmux_autostart.zsh'

  assert_skip() {
    local label=\"\$1\"
    shift

    unset TERM_PROGRAM CODEX_SHELL __CFBundleIdentifier VSCODE_IPC_HOOK_CLI CURSOR_TRACE_ID
    eval \"\$*\"

    if ! dotfiles_should_skip_tmux_autostart; then
      echo \"FAIL: expected skip for \$label\"
      exit 1
    fi
  }

  assert_continue() {
    local label=\"\$1\"
    shift

    unset TERM_PROGRAM CODEX_SHELL __CFBundleIdentifier VSCODE_IPC_HOOK_CLI CURSOR_TRACE_ID
    eval \"\$*\"

    if dotfiles_should_skip_tmux_autostart; then
      echo \"FAIL: expected continue for \$label\"
      exit 1
    fi
  }

  assert_skip 'vscode' 'TERM_PROGRAM=vscode'
  assert_skip 'cursor' 'TERM_PROGRAM=cursor'
  assert_skip 'codex term program' 'TERM_PROGRAM=codex'
  assert_skip 'vscode env' 'VSCODE_IPC_HOOK_CLI=/tmp/vscode.sock'
  assert_skip 'cursor env' 'CURSOR_TRACE_ID=cursor-session'
  assert_skip 'empty term program in codex' 'TERM_PROGRAM=; CODEX_SHELL=1'
  assert_skip 'null term program in codex bundle' 'TERM_PROGRAM=null; __CFBundleIdentifier=com.openai.codex'

  assert_continue 'empty term program outside codex' 'TERM_PROGRAM='
  assert_continue 'apple terminal' 'TERM_PROGRAM=Apple_Terminal'

  echo 'PASS: tmux autostart conditions'
"
