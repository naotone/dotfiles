alias q='exit'
alias crontab='crontab -i'

alias vihosts='sudo vim /etc/hosts'
alias reload='source ~/.zshrc'
alias c='clear'

alias wgetAll='wget -r -l 0 -c -t 0'
alias rsyncDownload='rsync -ahv --progress'

alias ResetLaunchPad='defaults write com.apple.dock ResetLaunchPad -bool true; killall Dock'
alias airport='/System/Library/PrivateFrameworks/Apple80211.framework/Versions/Current/Resources/airport'

alias chrome="/Applications/Google\ Chrome.app/Contents/MacOS/Google\ Chrome"
alias chrome-canary="/Applications/Google\ Chrome\ Canary.app/Contents/MacOS/Google\ Chrome\ Canary"
alias chromium="/Applications/Chromium.app/Contents/MacOS/Chromium"

alias awsdo='aws --endpoint=https://nyc3.digitaloceanspaces.com'

alias grep='grep --color=auto'
alias fgrep='fgrep --color=auto'
alias egrep='egrep --color=auto'

alias df='df -h'

if has 'exa'; then
    alias l='exa -h1 --git --time-style=iso --group-directories-first --icons'
    alias ll='exa -hl --git --time-style=iso --group-directories-first --icons'
    alias la='ll -a'
    alias lt='l -T'
    alias llt='ll -T'
    alias lat='la -T'
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

alias yolo="claude --dangerously-skip-permissions"
