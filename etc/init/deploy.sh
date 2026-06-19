#!/bin/bash

. "$DOTPATH"/etc/lib/util.zsh

inclusion_dirs=(bin)
rc_files=(.vimrc .zshrc .zshenv .zpreztorc .gitconfig .hammerspoon)
config_dirs=(vim zsh ghostty)

XDG_CONFIG_HOME=$HOME/.config
TMUX_PLUGIN_DIR=$HOME/.tmux/plugins
TPM_DIR=$TMUX_PLUGIN_DIR/tpm
TPM_REPOSITORY=https://github.com/tmux-plugins/tpm

safe_symlink() {
    local source_path="$1"
    local target_path="$2"

    if [ -e "$target_path" ] && [ ! -L "$target_path" ]; then
        local backup_path="${target_path}.backup.$(date +%Y%m%d%H%M%S).$$"
        log_echo "WARN: $target_path already exists; moving to $backup_path"
        mv "$target_path" "$backup_path"
    fi

    ln -sfnv "$source_path" "$target_path"
}

if [ ! -d $XDG_CONFIG_HOME ]; then
    mkdir -p $XDG_CONFIG_HOME
fi

log_info "Make symbolic links"

for f in "$DOTPATH"/.*; do
    if [ -f "$f" ] || [ -d "$f" ]; then
        dotfile="${f##*/}"
        if [[ " ${rc_files[@]} " =~ " ${dotfile} " ]]; then
            log_echo ${dotfile}
            safe_symlink "$f" "$HOME/$dotfile"
        fi
    fi
done

for f in "$DOTPATH"/*; do
    if [ -d "$f" ]; then
        dir="${f##*/}"
        if [[ " ${inclusion_dirs[@]} " =~ " ${dir} " ]]; then
            log_echo "${dir}"
            safe_symlink "$f" "$HOME/${dir}"
        elif [[ " ${config_dirs[@]} " =~ " ${dir} " ]]; then
            log_echo ${dir}
            safe_symlink "$f" "$XDG_CONFIG_HOME/${dir}"
        fi
    fi
done

if is_ssh_running; then
    safe_symlink "$DOTPATH/.tmux.remote.conf" "$HOME/.tmux.conf"
else
    safe_symlink "$DOTPATH/.tmux.conf" "$HOME/.tmux.conf"
fi

if [ ! -d "$TPM_DIR" ]; then
    log_info "Install tmux plugin manager"
    mkdir -p "$TMUX_PLUGIN_DIR"
    git clone "$TPM_REPOSITORY" "$TPM_DIR"
fi
