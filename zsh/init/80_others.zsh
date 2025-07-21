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

zshaddhistory() {
    local cmd="${1}"

    # Skip rm commands with f option (force delete)
    if [[ "$cmd" =~ ^rm[[:space:]]+.*-f ]]; then
        return 1
    fi

   # Skip git commit -m commands (preserve multiline commit messages)
    if [[ "$cmd" =~ ^git[[:space:]]+commit[[:space:]]+-m ]]; then
        return 1
    fi

    # Skip commands with potential API keys or tokens (long alphanumeric strings)
    if [[ "$cmd" =~ [A-Za-z0-9]{32,} ]]; then
        return 1
    fi

    # Skip commands with suspicious patterns (base64-like, hex-like long strings)
    if [[ "$cmd" =~ [A-Za-z0-9+/]{20,}={0,2} ]] || [[ "$cmd" =~ [a-fA-F0-9]{40,} ]]; then
        return 1
    fi

    # Skip export commands with sensitive-looking values
    if [[ "$cmd" =~ ^export[[:space:]]+[A-Z_]*[Kk][Ee][Yy][A-Z_]*= ]] || \
       [[ "$cmd" =~ ^export[[:space:]]+[A-Z_]*[Tt][Oo][Kk][Ee][Nn][A-Z_]*= ]] || \
       [[ "$cmd" =~ ^export[[:space:]]+[A-Z_]*[Ss][Ee][Cc][Rr][Ee][Tt][A-Z_]*= ]] || \
       [[ "$cmd" =~ ^export[[:space:]]+[A-Z_]*[Pp][Aa][Ss][Ss][Ww][Oo][Rr][Dd][A-Z_]*= ]] || \
       [[ "$cmd" =~ ^export[[:space:]]+[A-Z_]*[Aa][Uu][Tt][Hh][A-Z_]*= ]] || \
       [[ "$cmd" =~ ^export[[:space:]]+.*=(pk_|sk_|[A-Za-z0-9]{20,}) ]]; then
        return 1
    fi

    local first_word="${cmd%% *}"

    # Skip empty commands or commands with only whitespace
    if [[ -z "${first_word// }" ]]; then
        return 1
    fi

    # Check if command exists (builtin, function, or executable)
    if ! command -v "$first_word" >/dev/null 2>&1; then
        return 1
    fi

    cmd="${cmd//$'\t'/'  '}"
    cmd="${cmd//$'\n'/__NEWLINE__}"
    cmd="${cmd%$'__NEWLINE__'}"

    if tail -n 100 "$HISTFILE" 2>/dev/null | sed -n 's/^: [0-9]*:[0-9]*;//p' | grep -Fxq "$cmd"; then
      return 1
    fi

    print -sr -- "$cmd"
    return 1
}

