# cdr, add-zsh-hook
autoload -Uz chpwd_recent_dirs cdr add-zsh-hook
add-zsh-hook chpwd chpwd_recent_dirs

#cdr
zstyle ':completion:*' recent-dirs-insert both
zstyle ':chpwd:*' recent-dirs-max 500
zstyle ':chpwd:*' recent-dirs-default true
zstyle ':chpwd:*' recent-dirs-file "$HOME/.cache/shell/chpwd-recent-dirs"
zstyle ':chpwd:*' recent-dirs-pushd true

HISTFILE=~/.zsh_history
HISTSIZE=10000
SAVEHIST=10000
setopt hist_ignore_dups
setopt hist_ignore_all_dups
setopt hist_reduce_blanks
setopt share_history

dotfiles_history_normalize_field() {
  local field="${(Q)1}"

  field="${field%$'\n'}"
  while [[ "$field" == *[\;\,] ]]; do
    field="${field[1,-2]}"
  done

  print -r -- "$field"
}

dotfiles_history_is_sensitive_name() {
  local name="${(L)1}"

  name="${name#--}"
  name="${name#-}"
  name="${name//-/_}"
  name="${name//./_}"

  [[ "$name" =~ '(^|_)(token|secret|password|passwd|passphrase|credential|credentials|auth|authorization|api_key|apikey|private_key|access_key|secret_key)($|_)' ]]
}

dotfiles_history_is_reference_name() {
  local name="${(L)1}"

  name="${name#--}"
  name="${name#-}"
  name="${name//-/_}"
  name="${name//./_}"

  [[ "$name" =~ '(^|_)(path|file|dir|directory|url|uri)($|_)' ]]
}

dotfiles_history_is_path_like() {
  local value="$1"
  local lower="${(L)value}"

  [[ "$value" == */* || "$value" == "~/"* || "$lower" == http://* || "$lower" == https://* || "$lower" == file:* || "$lower" == ssh://* || "$lower" == git@* ]]
}

dotfiles_history_is_obvious_reference_value() {
  local value="$1"
  local lower="${(L)value}"

  if [[ "$value" == '$'* || "$value" == "~/"* || "$value" == /* || "$value" == ./* || "$value" == ../* ]]; then
    return 0
  fi

  if [[ "$lower" == http://* || "$lower" == https://* || "$lower" == file:* || "$lower" == ssh://* || "$lower" == git@* ]]; then
    return 0
  fi

  [[ "$value" =~ '(^|/)[^/]+\.[A-Za-z0-9]{1,8}($|[/?#])' ]]
}

dotfiles_history_field_has_known_secret() {
  local field="$1"

  if [[ "$field" =~ '-----BEGIN[[:space:]]+[A-Z ]*PRIVATE KEY-----' ]]; then
    return 0
  fi
  if [[ "$field" =~ '(^|[^A-Za-z0-9_])sk-[A-Za-z0-9_-]{16,}' ]]; then
    return 0
  fi
  if [[ "$field" =~ '(^|[^A-Za-z0-9_])(pk|sk)_[A-Za-z0-9]{8,}' ]]; then
    return 0
  fi
  if [[ "$field" =~ '(^|[^A-Za-z0-9_])gh[pousr]_[A-Za-z0-9_]{30,}' ]]; then
    return 0
  fi
  if [[ "$field" =~ '(^|[^A-Za-z0-9_])xox[baprs]-[A-Za-z0-9-]{20,}' ]]; then
    return 0
  fi
  if [[ "$field" =~ '(^|[^A-Za-z0-9_])npm_[A-Za-z0-9]{30,}' ]]; then
    return 0
  fi
  if [[ "$field" =~ '(^|[^A-Za-z0-9_])(AKIA|ASIA)[A-Z0-9]{16}' ]]; then
    return 0
  fi
  if [[ "$field" =~ 'eyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}' ]]; then
    return 0
  fi
  if [[ "$field" =~ '(^|[[:space:]])[Bb]earer[[:space:]]+[A-Za-z0-9._~+/-]{16,}' ]]; then
    return 0
  fi
  if [[ "$field" =~ '[Aa]uthorization:[[:space:]]*[Bb]asic[[:space:]]+[A-Za-z0-9+/=]{16,}' ]]; then
    return 0
  fi
  if [[ "$field" =~ '://[^/[:space:]@]+:[^/[:space:]@]+@' ]]; then
    return 0
  fi

  return 1
}

dotfiles_history_bare_value_looks_secret() {
  local value

  value="$(dotfiles_history_normalize_field "$1")"

  if [[ -z "$value" ]]; then
    return 1
  fi
  if dotfiles_history_field_has_known_secret "$value"; then
    return 0
  fi
  if dotfiles_history_is_obvious_reference_value "$value"; then
    return 1
  fi
  if [[ "$value" =~ '^[a-fA-F0-9]{32,}$' ]]; then
    return 1
  fi
  if (( ${#value} >= 24 )) && [[ "$value" =~ '^[A-Za-z0-9+/]+={0,2}$' ]] && [[ "$value" == *[+/=]* ]]; then
    return 0
  fi
  if (( ${#value} < 32 )); then
    return 1
  fi
  if [[ ! "$value" =~ '^[A-Za-z0-9_+/.-]+={0,2}$' ]]; then
    return 1
  fi

  [[ "$value" == *[A-Z]* && "$value" == *[a-z]* && "$value" == *[0-9]* ]] || [[ "$value" == *[+/=]* ]]
}

dotfiles_history_context_value_looks_secret() {
  local value
  local lower

  value="$(dotfiles_history_normalize_field "$1")"
  lower="${(L)value}"

  if [[ -z "$value" ]]; then
    return 1
  fi
  if [[ "$lower" =~ '^(true|false|yes|no|on|off|null|none|undefined|0|1|dev|test|local|development|production)$' ]]; then
    return 1
  fi
  if dotfiles_history_field_has_known_secret "$value"; then
    return 0
  fi
  if dotfiles_history_is_obvious_reference_value "$value"; then
    return 1
  fi

  (( ${#value} >= 8 ))
}

dotfiles_history_command_has_sensitive_value() {
  local cmd="$1"
  local word
  local name
  local value
  local next
  local -a words
  local i

  if [[ "$cmd" =~ '-----BEGIN[[:space:]]+[A-Z ]*PRIVATE KEY-----' ]]; then
    return 0
  fi

  words=("${(@z)cmd}")

  for ((i = 1; i <= ${#words}; i++)); do
    word="$(dotfiles_history_normalize_field "${words[$i]}")"

    if dotfiles_history_field_has_known_secret "$word"; then
      return 0
    fi

    if [[ "$word" == *=* ]]; then
      name="${word%%=*}"
      value="${word#*=}"

      if dotfiles_history_is_sensitive_name "$name" && ! dotfiles_history_is_reference_name "$name" && dotfiles_history_context_value_looks_secret "$value"; then
        return 0
      fi
      continue
    fi

    if dotfiles_history_is_sensitive_name "$word" && ! dotfiles_history_is_reference_name "$word"; then
      next="$(dotfiles_history_normalize_field "${words[$((i + 1))]:-}")"
      if dotfiles_history_context_value_looks_secret "$next"; then
        return 0
      fi
      continue
    fi

    if dotfiles_history_bare_value_looks_secret "$word"; then
      return 0
    fi
  done

  return 1
}

zshaddhistory() {
  local cmd="${1%$'\n'}"

  # Skip empty commands or commands with only whitespace
  if [[ -z "${cmd//[[:space:]]/}" ]]; then
    return 1
  fi

  if dotfiles_history_command_has_sensitive_value "$cmd"; then
    return 1
  fi

  # Skip git commit -m commands (preserve multiline commit messages)
  if [[ "$cmd" =~ ^git[[:space:]]+commit[[:space:]]+-m ]]; then
    return 1
  fi

  if typeset -f dotfiles_history_counter_increment >/dev/null 2>&1; then
    dotfiles_history_counter_increment "$cmd"
  fi

  print -sr -- "$cmd"
  return 1
}


export FZF_DEFAULT_OPTS="
  --bind ctrl-k:kill-line
  --height=90%
  --border=none
  --margin=0
  --preview-window=down:30%
"
