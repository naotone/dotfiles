dotfiles_configure_moshi_git_signing() {
  [[ -n "${SSH_CONNECTION-}${SSH_TTY-}" && -n "${SSH_AUTH_SOCK-}" ]] || return 0
  [[ "$SSH_AUTH_SOCK" != "$HOME/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock" ]] || return 0

  local config_file="${XDG_CONFIG_HOME:-$HOME/.config}/git/moshi-signing.conf"
  [[ -r "$config_file" ]] || return 0
  local signing_key offered_keys
  signing_key=$(git config --file "$config_file" --get user.signingkey) || return 0
  offered_keys=$(ssh-add -L 2>/dev/null) || return 0
  print -r -- "$offered_keys" | awk -v key="$signing_key" \
    '$1 " " $2 == key { found = 1 } END { exit !found }' || return 0

  local count="${GIT_CONFIG_COUNT:-0}" index key_name value_name
  [[ "$count" == <-> ]] || return 0
  for (( index = 0; index < count; index++ )); do
    key_name="GIT_CONFIG_KEY_$index"
    value_name="GIT_CONFIG_VALUE_$index"
    if [[ "${(P)key_name}" == include.path && "${(P)value_name}" == "$config_file" ]]; then
      return 0
    fi
  done

  # Inherit session settings without changing global Git defaults.
  export "GIT_CONFIG_KEY_$count=include.path"
  export "GIT_CONFIG_VALUE_$count=$config_file"
  export GIT_CONFIG_COUNT=$(( count + 1 ))
}

dotfiles_configure_moshi_git_signing
