if [ -z "${DOTPATH:-}" ]; then
  DOTPATH="$HOME/.dotfiles"
  export DOTPATH
fi

if [ -z "${XDG_CONFIG_HOME:-}" ]; then
  XDG_CONFIG_HOME="$HOME/.config"
  export XDG_CONFIG_HOME
fi

if [ -z "${XDG_CACHE_HOME:-}" ]; then
  XDG_CACHE_HOME="$HOME/.cache"
  export XDG_CACHE_HOME
fi

. "${XDG_CONFIG_HOME}"/zsh/zplug.zsh

if [[ -s "${ZDOTDIR:-$HOME}/.zprezto/init.zsh" ]]; then
  source "${ZDOTDIR:-$HOME}/.zprezto/init.zsh"
elif [[ -s "$HOME/.zplug/repos/sorin-ionescu/prezto/init.zsh" ]]; then
  source "$HOME/.zplug/repos/sorin-ionescu/prezto/init.zsh"
fi

for file in "${XDG_CONFIG_HOME}"/zsh/init/*.zsh; do
  . "$file"
done

dotfiles_maybe_autostart_tmux

# Added by LM Studio CLI (lms)
export PATH="$PATH:/Users/naotone/.lmstudio/bin"
# End of LM Studio CLI section

eval "$(direnv hook zsh)"
eval "$(mise activate zsh)"

# pnpm
export PNPM_HOME="/Users/naotone/Library/pnpm"
case ":$PATH:" in
  *":$PNPM_HOME:"*) ;;
  *) export PATH="$PNPM_HOME:$PATH" ;;
esac
# pnpm end

# Added by Antigravity
export PATH="/Users/naotone/.antigravity/antigravity/bin:$PATH"

# opencode
export PATH=/Users/naotone/.opencode/bin:$PATH

# bun completions
[ -s "/Users/naotone/.bun/_bun" ] && source "/Users/naotone/.bun/_bun"

# bun
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"

export PATH="$HOME/.local/bin:$PATH"

# Turso
export PATH="$PATH:/Users/naotone/.turso"
