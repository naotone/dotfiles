# cdr, add-zsh-hook
autoload -Uz chpwd_recent_dirs cdr add-zsh-hook
add-zsh-hook chpwd chpwd_recent_dirs

#cdr
zstyle ':completion:*' recent-dirs-insert both
zstyle ':chpwd:*' recent-dirs-max 500
zstyle ':chpwd:*' recent-dirs-default true
zstyle ':chpwd:*' recent-dirs-file "$HOME/.cache/shell/chpwd-recent-dirs"
zstyle ':chpwd:*' recent-dirs-pushd true

zle -N peco-select-history
zle -N peco-go-to-dir
zle -N peco-select-gitadd

# # --------------------------------------------------------------------
# #  Completion settings
# # --------------------------------------------------------------------

# autoload predict-on
# #predict-on

# # ls command
# export LS_COLORS='no=00:fi=00:di=01;36:ln=36:pi=31:so=33:bd=44;37:cd=44;37:ex=01;32:mi=00:or=36'
# export LSCOLORS=GxgxdxbxCxegedabagacad
# zstyle ':completion:*' list-colors ${(s.:.)LS_COLORS}

# # Ignore upper/lower cases
# zstyle ':completion:*' matcher-list '' 'm:{a-z}={A-Z}' '+m:{a-z}={A-Z}'

# # Complete PID for killing
# zstyle ':completion:*:processes' command "ps au"
# zstyle ':completion:*:processes' menu yes select=2

# # Set separator between lists and descriptions
# zstyle ':completion:*' list-separator '-->'

# # Suggest typoed commands
# setopt correct

# # Pack lists
# setopt list_packed

# # Enable complete for arguments
# setopt magic_equal_subst

# # Enable brace expansion
# setopt brace_ccl

# # --------------------------------------------------------------------
# #  Delimiter settings
# # --------------------------------------------------------------------

# autoload -Uz select-word-style
# select-word-style default

# # Set delimiter characters
# zstyle ':zle:*' word-chars ' /=;@:{}[]()<>,|.'
# zstyle ':zle:*' word-style unspecified

# # --------------------------------------------------------------------
# #  Command history
# # --------------------------------------------------------------------
# unsetopt EXTENDED_HISTORY

HISTFILE=~/.zsh_history
HISTSIZE=10000
SAVEHIST=10000
setopt hist_ignore_dups
setopt hist_ignore_all_dups
setopt hist_reduce_blanks
setopt share_history

zshaddhistory() {
    whence ${${(z)1}[1]} >| /dev/null || return 1
}

# # --------------------------------------------------------------------
# #  Make cd comfortable
# # --------------------------------------------------------------------

# setopt auto_cd
# setopt auto_pushd
# setopt pushd_ignore_dups

# # --------------------------------------------------------------------
# #  Others
# # --------------------------------------------------------------------

# # Enable hook functions
# autoload -Uz add-zsh-hook
# #add-zsh-hook preexec complete_action

# # Prevent alert
# setopt no_beep

# # Enable keymap 'Ctrl+q' on Vim
# stty -ixon

# unsetopt bg_nice

# autoload -Uz zmv
