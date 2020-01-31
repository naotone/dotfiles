. "$DOTPATH"/etc/lib/util.zsh

# export WORDCHARS='*?_-.[]~=&;!#$%^(){}<>'
export LANG="en_US.UTF-8"
export PATH=$PATH:$HOME/bin


if is_osx; then
    export PATH=$PATH:/usr/local/bin:/bin
fi

#nvm
export NVM_DIR=~/.nvm
source $(brew --prefix nvm)/nvm.sh
# nvm use 10

#phpbrew
[[ -e ~/.phpbrew/bashrc ]] && source ~/.phpbrew/bashrc

# pyenv
export PYENV_ROOT="${HOME}/.pyenv"
if [ -d "${PYENV_ROOT}" ]; then
    export PATH=${PYENV_ROOT}/bin:$PATH
    eval "$(pyenv init -)"
fi

export PATH="/usr/local/opt/mysql@5.7/bin:$PATH"
export PATH=$HOME/.config/composer/vendor/bin:$PATH

#rbenv
export RBENV_ROOT=/usr/local/var/rbenv
if which rbenv > /dev/null; then eval "$(rbenv init -)"; fi

# cuda
# export PATH=/Developer/NVIDIA/CUDA-7.0/bin:$PATH
# export DYLD_LIBRARY_PATH=/Developer/NVIDIA/CUDA-7.0/lib:$DYLD_LIBRARY_PATH

# The next line updates PATH for the Google Cloud SDK.
if [ -f '/Users/naotone/google-cloud-sdk/path.zsh.inc' ]; then . '/Users/naotone/google-cloud-sdk/path.zsh.inc'; fi

# The next line enables shell command completion for gcloud.
if [ -f '/Users/naotone/google-cloud-sdk/completion.zsh.inc' ]; then . '/Users/naotone/google-cloud-sdk/completion.zsh.inc'; fi

# Deploy local settings
if [[ -e ${HOME}/bin_local ]]; then
    PATH="$HOME/bin_local:$PATH"
fi
if [[ -e ${HOME}/.env_local.zsh ]]; then
    source ${HOME}/.env_local.zsh
fi

