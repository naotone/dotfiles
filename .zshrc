# # Start TMUX
# if [[ -x ~/bin/tmuxx ]]; then
#     ~/bin/tmuxx
# fi

# if [ -z "${DOTPATH:-}" ]; then
#     DOTPATH=~/.dotfiles; export DOTPATH
# fi

# if [ -z "${XDG_CONFIG_HOME:-}" ]; then
#     XDG_CONFIG_HOME=~/.config; export XDG_CONFIG_HOME
# fi

# if [ -z "${XDG_CACHE_HOME:-}" ]; then
#     XDG_CACHE_HOME=~/.cache; export XDG_CACHE_HOME
# fi

# # Load zplug only in tmux
# # if [[ -n "$TMUX" ]]; then
#     . "${XDG_CONFIG_HOME}"/zsh/zplug.zsh
# # fi

# # Load config files
# for file in "${XDG_CONFIG_HOME}"/zsh/init/*.zsh; do
#     . "$file"
# done

if [ -z "${DOTPATH:-}" ]; then
    DOTPATH=~/.dotfiles; export DOTPATH
fi

if [ -z "${XDG_CONFIG_HOME:-}" ]; then
    XDG_CONFIG_HOME=~/.config; export XDG_CONFIG_HOME
fi

if [ -z "${XDG_CACHE_HOME:-}" ]; then
    XDG_CACHE_HOME=~/.cache; export XDG_CACHE_HOME
fi

# Load zplug only in tmux
if [[ -n "$TMUX" ]]; then
    . "${XDG_CONFIG_HOME}"/zsh/zplug.zsh
fi

# Load config files
for file in "${XDG_CONFIG_HOME}"/zsh/init/*.zsh; do
    . "$file"
done


# if (which zprof > /dev/null); then
#   zprof | less
# fi

# Start TMUX
if has tmux; then
    tmuxx
    zplug load
fi

# Added by Krypton
export GPG_TTY=$(tty)
