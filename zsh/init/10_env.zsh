. "$DOTPATH"/etc/lib/util.zsh
# export WORDCHARS='*?_-.[]~=&;!#$%^(){}<>'
export LANG="en_US.UTF-8"
export PATH=$PATH:$HOME/bin
export BREW_PATH="$(brew --prefix)/opt"

export GPG_TTY=$(tty)

if [[ "$TERM" != "screen-256color" ]]; then
  export TERM="xterm-256color"
fi

if is_macos; then
  export PATH="/usr/local/opt/curl/bin:$PATH"
  export PATH=$PATH:/usr/local/bin:/bin
  if is_appleSilicon; then
    # brew
    eval "$(/opt/homebrew/bin/brew shellenv)"
    # yarn
    # export PATH="$PATH:$(yarn global bin)"
    # puppeteer
    export PUPPETEER_SKIP_CHROMIUM_DOWNLOAD=true
    export PUPPETEER_EXECUTABLE_PATH=$(which chromium)
  else
    # cuda
    # export PATH=/Developer/NVIDIA/CUDA-7.0/bin:$PATH
    # export DYLD_LIBRARY_PATH=/Developer/NVIDIA/CUDA-7.0/lib:$DYLD_LIBRARY_PATH
  fi
fi

#libarchive
export PKG_CONFIG_PATH="/opt/homebrew/opt/libarchive/lib/pkgconfig"

#nvm
export NVM_DIR="$HOME/.config/nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"                   # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion" # This loads nvm bash_completion
# set default node version: nvm alias default VERSION

#pnpm
export PNPM_DIR="$HOME/Library/pnpm"
if [ -d "${PNPM_DIR}" ]; then
  export PATH=${PNPM_DIR}/node/bin:$PATH
fi

#pyenv
export PYENV_ROOT="${HOME}/.pyenv"
if [ -d "${PYENV_ROOT}" ]; then
  export PATH=${PYENV_ROOT}/bin:$PATH
  eval "$(pyenv init -)"
  alias python="$(pyenv which python)"
  alias pip="$(pyenv which pip)"
fi

#go
export GO_PATH="${HOME}/go"
if [ -d "${GO_PATH}" ]; then
  export PATH=${GO_PATH}/bin:$PATH
fi

#rbenv
export RBENV_ROOT="${BREW_PATH}/rbenv"
if which rbenv >/dev/null; then eval "$(rbenv init -)"; fi

#phpbrew
[[ -e ~/.phpbrew/bashrc ]] && source ~/.phpbrew/bashrc

#java open jdk
export OPENJDK_PATH="${BREW_PATH}/openjdk"
if [ -d "${OPENJDK_PATH}" ]; then
  export PATH=${OPENJDK_PATH}/bin:$PATH
fi
export PATH="/opt/homebrew/opt/openjdk/bin:$PATH"

#PostgreSQL
if [ -d "/opt/homebrew/opt/libpq" ]; then
  export PATH="/opt/homebrew/opt/libpq/bin:$PATH"
fi

#mysql
# export PATH="/usr/local/opt/mysql@5.7/bin:$PATH"
# export PATH=$HOME/.config/composer/vendor/bin:$PATH

# Google Cloud SDK.
if [ -f '/Users/naotone/google-cloud-sdk/path.zsh.inc' ]; then . '/Users/naotone/google-cloud-sdk/path.zsh.inc'; fi

# Enables shell command completion for gcloud.
if [ -f '/Users/naotone/google-cloud-sdk/completion.zsh.inc' ]; then . '/Users/naotone/google-cloud-sdk/completion.zsh.inc'; fi

# Deploy local settings
if [[ -e ${HOME}/bin_local ]]; then
  PATH="$HOME/bin_local:$PATH"
fi
if [[ -e ${HOME}/.env_local.zsh ]]; then
  source ${HOME}/.env_local.zsh
fi

if [[ -e ${HOME}/.cargo/env ]]; then
  source ${HOME}/.cargo/env
fi
