dotfiles_should_skip_tmux_autostart() {
  local term_program="${TERM_PROGRAM-}"

  if [[ -n "${VSCODE_IPC_HOOK_CLI-}" || -n "${CURSOR_TRACE_ID-}" ]]; then
    return 0
  fi

  case "$term_program" in
    vscode|cursor|codex|Codex)
      return 0
      ;;
  esac

  if [[ -z "$term_program" || "$term_program" == "null" ]]; then
    if [[ "${CODEX_SHELL-}" == "1" || "${__CFBundleIdentifier-}" == "com.openai.codex" ]]; then
      return 0
    fi
  fi

  return 1
}

dotfiles_is_tailscale_ssh_session() {
  local remote_ip

  if [[ -z "${SSH_CONNECTION-}" ]]; then
    return 1
  fi

  remote_ip="${SSH_CONNECTION%% *}"
  [[ "$remote_ip" == 100.* ]]
}

dotfiles_maybe_autostart_tmux() {
  if dotfiles_should_skip_tmux_autostart; then
    return 0
  fi

  if [[ -n "${TMUX-}" ]]; then
    return 0
  fi

  if dotfiles_is_tailscale_ssh_session; then
    return 0
  fi

  tmux attach || tmux new-session
}
