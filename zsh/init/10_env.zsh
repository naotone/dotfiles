. "$DOTPATH"/etc/lib/util.zsh
# export WORDCHARS='*?_-.[]~=&;!#$%^(){}<>'
export LANG="en_US.UTF-8"
export PATH=$PATH:$HOME/bin
export BREW_PATH="$(brew --prefix)/opt"

export GPG_TTY=$(tty)

if [[ "$TERM" != "screen-256color" ]]; then
  export TERM="xterm-256color"
fi

export SSH_AUTH_SOCK="$HOME/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock"

#nvm
export NVM_DIR="$HOME/.nvm"
[ -s "/opt/homebrew/opt/nvm/nvm.sh" ] && \. "/opt/homebrew/opt/nvm/nvm.sh"  # This loads nvm
[ -s "/opt/homebrew/opt/nvm/etc/bash_completion.d/nvm" ] && \. "/opt/homebrew/opt/nvm/etc/bash_completion.d/nvm"  # This loads nvm bash_completion

#pnpm
export PNPM_HOME="$HOME/Library/pnpm"
if [ -d "${PNPM_HOME}" ]; then
  export PATH=${PNPM_HOME}/node/bin:$PATH
  case ":$PATH:" in
    *":$PNPM_HOME:"*) ;;
    *) export PATH="$PNPM_HOME:$PATH" ;;
  esac

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

# React Native Android SDK
export JAVA_HOME=/Library/Java/JavaVirtualMachines/zulu-17.jdk/Contents/Home
export ANDROID_HOME=$HOME/Library/Android/sdk
export PATH=$PATH:$ANDROID_HOME/emulator
export PATH=$PATH:$ANDROID_HOME/platform-tools

[[ "$TERM_PROGRAM" == "kiro" ]] && . "$(kiro --locate-shell-integration-path zsh)"


# Added by LM Studio CLI (lms)
export PATH="$PATH:/Users/naotone/.lmstudio/bin"

# Added by Windsurf
export PATH="/Users/naotone/.codeium/windsurf/bin:$PATH"

export PATH="/opt/homebrew/opt/llvm/bin:$PATH"
export PATH="/opt/homebrew/opt/curl/bin:$PATH"

# Added by LM Studio CLI (lms)
export PATH="$PATH:/Users/naotone/.lmstudio/bin"

# Cursor Agent CLI
export PATH="$HOME/.local/bin:$PATH"

eval "$(direnv hook zsh)"
