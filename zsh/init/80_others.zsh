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

   # Skip git commit -m commands (preserve multiline commit messages)
    if [[ "$cmd" =~ ^git[[:space:]]+commit[[:space:]]+-m ]]; then
        return 1
    fi

    # Skip commands containing sensitive information
    # Skip commands with pk_ or sk_ prefixed environment variables/keys
    if [[ "$cmd" =~ (pk_|sk_)[A-Za-z0-9_]+ ]]; then
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
    whence "$first_word" >|/dev/null || return 1
    cmd="${cmd//$'\t'/' '}"
    cmd="${cmd//$'\n'/__NEWLINE__}"
    cmd="${cmd%$'__NEWLINE__'}"

    print -sr -- "$cmd"
    return 1
}

