alias q='exit'
alias crontab='crontab -i'

alias vihosts='sudo vim /etc/hosts'
alias reload='source ~/.zshrc'
alias c='clear'
alias open.='open .'

alias code.='code .'
alias subl.='subl .'
alias atom.='atom .'

alias wgetAll='wget -r -l 0 -c -t 0'
alias rsyncDownload='rsync -ahv --progress'

alias hhkb='sudo kextunload /System/Library/Extensions/AppleUSBTopCase.kext/Contents/PlugIns/AppleUSBTCKeyboard.kext/'
alias aaplkb='sudo kextload /System/Library/Extensions/AppleUSBTopCase.kext/Contents/PlugIns/AppleUSBTCKeyboard.kext/'

alias ResetLaunchPad='defaults write com.apple.dock ResetLaunchPad -bool true; killall Dock'

alias cdOF='cd ~/openFrameworks/*9*'
alias ofProj='open ~/openFrameworks/*4/projectGenerator_osx/projectGenerator.app'
alias cdDropbox='cd ~/Dropbox/'
alias cdProjects='cd ~/Dropbox/Projects/'

alias chrome="/Applications/Google\ Chrome.app/Contents/MacOS/Google\ Chrome"
alias chrome-canary="/Applications/Google\ Chrome\ Canary.app/Contents/MacOS/Google\ Chrome\ Canary"
alias chromium="/Applications/Chromium.app/Contents/MacOS/Chromium"

alias dcwp='docker-compose exec --user www-data phpfpm wp'
alias dcbash='docker-compose exec --user root phpfpm bash'

case "${OSTYPE}" in
darwin*)
    alias ls='ls -G'
    ;;
*)
    alias ls='ls --color=auto'
    ;;
esac

# alias lr='ls -R'
# alias ll='ls -alF'
# alias la='ls -A'
# alias l='ls -CF'

# alias rm='rm -v'
# alias rr='rm -r'

alias grep='grep --color=auto'
alias fgrep='fgrep --color=auto'
alias egrep='egrep --color=auto'

alias df='df -h'

alias zmv='noglob zmv -W'

if is_cygwin; then
    alias open='cygstart'
fi

if has 'tmux'; then
    alias tmux='tmux -2'
    alias tmls='tmux ls'
    alias tmat='tmux a -t'
    alias tmns='tmux new-session -s'
fi

if has 'vim'; then
    alias v='vim'
    alias vi='vim'
fi

if has 'nvim'; then
    alias n='nvim'
fi

# if has 'git'; then
#     alias ga='git add'
#     alias gaa='git add -A'
#     alias gc='git commit'
#     alias gcm='git commit -m'
#     alias gp='git push'
#     alias gs='git status'
#     alias gd='git diff'
#     alias gco='git checkout'
# fi

# if has 'vagrant'; then
#     alias vup='vagrant up'
#     alias vsh='vagrant ssh'
#     alias vhl='vagrant halt'
#     alias vre='vagrant reload'
# fi

if has 'lxterminal'; then
    alias lxterminal='lxterminal --geometry=100x35'
fi

if [[ -e ${HOME}/.local_aliases ]]; then
    source ${HOME}/.local_aliases
fi

