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

for file in "${XDG_CONFIG_HOME}"/zsh/init/*.zsh; do
  . "$file"
done

# Do not auto start tmux in vscode and cursor
if [[ "$TERM_PROGRAM" != "vscode" ]]; then
  if [[ -z "$TMUX" ]]; then
    # Tailscale IP（100.64.0.0/10）
    if [[ -n "$SSH_CONNECTION" ]]; then
      remote_ip=$(echo "$SSH_CONNECTION" | awk '{print $1}')
      if [[ "$remote_ip" == 100.* ]]; then
        return
      fi
    fi

    tmux attach || tmux new-session
  fi
fi

