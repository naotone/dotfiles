if [ -z "${DOTPATH:-}" ]; then
    DOTPATH=~/.dotfiles
    export DOTPATH
fi

if [ -z "${XDG_CONFIG_HOME:-}" ]; then
    XDG_CONFIG_HOME=~/.config
    export XDG_CONFIG_HOME
fi

if [ -z "${XDG_CACHE_HOME:-}" ]; then
    XDG_CACHE_HOME=~/.cache
    export XDG_CACHE_HOME
fi

# Load zplug only in tmux
# if [[ -n "$TMUX" ]]; then
. "${XDG_CONFIG_HOME}"/zsh/zplug.zsh
# fi

# Load config files
for file in "${XDG_CONFIG_HOME}"/zsh/init/*.zsh; do
    . "$file"
done

# Do not auto start tmux in vscode
if [[ "$TERM_PROGRAM" != "vscode" ]]; then
    if [[ -z "$TMUX" ]]; then
        tmux attach || tmux new-session
    fi
fi

# pnpm
export PNPM_HOME="/Users/naotone/Library/pnpm"
case ":$PATH:" in
*":$PNPM_HOME:"*) ;;
*) export PATH="$PNPM_HOME:$PATH" ;;
esac

export PATH="/opt/homebrew/opt/curl/bin:$PATH"

# The next line updates PATH for the Google Cloud SDK.
if [ -f '/Users/naotone/Downloads/google-cloud-sdk/path.zsh.inc' ]; then . '/Users/naotone/Downloads/google-cloud-sdk/path.zsh.inc'; fi

# The next line enables shell command completion for gcloud.
if [ -f '/Users/naotone/Downloads/google-cloud-sdk/completion.zsh.inc' ]; then . '/Users/naotone/Downloads/google-cloud-sdk/completion.zsh.inc'; fi

export NVM_DIR="$HOME/.config/nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"                   # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion" # This loads nvm bash_completion

# Added by LM Studio CLI (lms)
export PATH="$PATH:/Users/naotone/.lmstudio/bin"

. "$HOME/.local/bin/env"

# Added by Windsurf
export PATH="/Users/naotone/.codeium/windsurf/bin:$PATH"

export FZF_DEFAULT_OPTS="
  --bind ctrl-k:kill-line
  --height=60%
  --border=none
  --margin=0
  --preview-window=down:40%
"
