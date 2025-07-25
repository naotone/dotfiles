if [ -z "${DOTPATH:-}" ]; then
    DOTPATH=~/.dotfiles; export DOTPATH
fi

is_exists()
{
    which "$1" >/dev/null 2>&1
    return $?
}

has()
{
    is_exists "$@"
}

ostype() {
    uname | lower
}

processortype() {
    uname -m | lower
}

os_detect() {
    export PLATFORM
    case "$(ostype)" in
        *'linux'*)  PLATFORM='linux'   ;;
        *'darwin'*) PLATFORM='macos'     ;;
        *'bsd'*)    PLATFORM='bsd'     ;;
        *'cygwin'*) PLATFORM='cygwin'  ;;
        *)          PLATFORM='unknown' ;;
    esac
}

processor_detect() {
    export PROCESSOR
    case "$(processortype)" in
        *'arm64'*)  PROCESSOR='arm64'   ;;
        *'x86_64'*) PROCESSOR='x86_64'     ;;
        *)          PROCESSOR='unknown' ;;
    esac
}

distribution_detect() {
    export DISTRIBUTION
    if [ "$PLATFORM" = "linux" ]; then
        local distribution
        distribution=$(cat /etc/issue | lower)

        case "${distribution}" in
            *'centos'*) DISTRIBUTION='centos' ;;
            *'ubuntu'*) DISTRIBUTION='ubuntu' ;;
        esac
    fi

}

is_macos() {
    os_detect
    if [ "$PLATFORM" = "macos" ]; then
        return 0
    else
        return 1
    fi
}
alias is_mac=is_macos

is_appleSilicon(){
    os_detect
    processor_detect
    if [ "$PLATFORM" = "macos" ]; then
        if [ "$PROCESSOR" = "arm64" ]; then
            return 0
        else
            return 1
        fi
    fi
}

is_linux() {
    os_detect
    if [ "$PLATFORM" = "linux" ]; then
        return 0
    else
        return 1
    fi
}

is_bsd() {
    os_detect
    if [ "$PLATFORM" = "bsd" ]; then
        return 0
    else
        return 1
    fi
}

is_cygwin() {
    os_detect
    if [ "$PLATFORM" = "cygwin" ]; then
        return 0
    else
        return 1
    fi
}

is_ubuntu() {
    distribution_detect
    if [ "$DISTRIBUTION" = "ubuntu" ]; then
        return 0
    else
        return 1
    fi
}

is_centos() {
    distribution_detect
    if [ "$DISTRIBUTION" = "centos" ]; then
        return 0
    else
        return 1
    fi
}

get_os() {
    local os
    for os in macos linux bsd cygwin; do
        if is_$os; then
            echo $os
        fi
    done
}

is_screen_running() {
    [ ! -z "$STY" ]
}

is_tmux_running() {
    [ ! -z "$TMUX" ]
}

is_screen_or_tmux_running() {
    is_screen_running || is_tmux_running
}

shell_has_started_interactively() {
    [ ! -z "$PS1" ]
}

is_ssh_running() {
    [ ! -z "$SSH_CLIENT" ]
}

ink() {
    if [ "$#" -eq 0 -o "$#" -gt 2 ]; then
        echo "Usage: ink <color> <text>"
        echo "Colors:"
        echo "  black, white, red, green, yellow, blue, purple, cyan, gray"
        return 1
    fi

    local open="\033["
    local close="${open}0m"
    local black="0;30m"
    local red="1;31m"
    local green="1;32m"
    local yellow="1;33m"
    local blue="1;34m"
    local purple="1;35m"
    local cyan="1;36m"
    local gray="0;37m"
    local white="$close"

    local text="$1"
    local color="$close"

    if [ "$#" -eq 2 ]; then
        text="$2"
        case "$1" in
            black | red | green | yellow | blue | purple | cyan | gray | white)
            eval color="\$$1"
            ;;
        esac
    fi

    printf "${open}${color}${text}${close}"
}

ink256() {
    if [ "$#" -eq 0 -o "$#" -gt 2 ]; then
        echo "Usage: ink256 <color_number> <text>"
        echo "color_number:"
        echo " 0-256 "
        return 1
    fi

    local open="\033["
    local close="${open}0m"

    local text="$1"
    local color="$close"

    if [ "$#" -eq 2 ]; then
        text="$2"

        if [ $1 -ge 1 -a $1 -le 256 ]; then
            color="38;5;$1m"
        fi
    fi

    printf "${open}${color}${text}${close}"
}

logging() {
    if [ "$#" -eq 0 -o "$#" -gt 2 ]; then
        echo "Usage: ink <fmt> <msg>"
        echo "Formatting Options:"
        echo "  TITLE, ERROR, WARN, INFO, SUCCESS"
        return 1
    fi

    local color=
    local text="$2"

    case "$1" in
        TITLE)
            color=yellow
            ;;
        ERROR | WARN)
            color=red
            ;;
        INFO)
            color=blue
            ;;
        SUCCESS)
            color=green
            ;;
        *)
            text="$1"
    esac

    timestamp() {
        ink gray "["
        ink purple "$(date +%H:%M:%S)"
        ink gray "] "
    }

    timestamp; ink "$color" "$text"; echo
}

log_pass() {
    logging SUCCESS "$1"
}

log_fail() {
    logging ERROR "$1" 1>&2
}

log_fail() {
    logging WARN "$1"
}

log_info() {
    logging INFO "$1"
}

log_echo() {
    logging TITLE "$1"
}

e_newline() {
    printf "\n"
}

e_header() {
    printf " \033[37;1m%s\033[m\n" "$*"
}

e_error() {
    printf " \033[31m%s\033[m\n" "✖ $*" 1>&2
}

e_warning() {
    printf " \033[31m%s\033[m\n" "$*"
}

e_done() {
    printf " \033[37;1m%s\033[m...\033[32mOK\033[m\n" "✔ $*"
}

e_arrow() {
    printf " \033[37;1m%s\033[m\n" "➜ $*"
}

e_indent() {
    for ((i=0; i<${1:-4}; i++)); do
        echo " "
    done
    if [ -n "$2" ]; then
        echo "$2"
    else
        cat <&0
    fi
}

e_success() {
    printf " \033[37;1m%s\033[m%s...\033[32mOK\033[m\n" "✔ " "$*"
}

e_failure() {
    die "${1:-$FUNCNAME}"
}

lower() {
    if [ $# -eq 0 ]; then
        cat <&0
    elif [ $# -eq 1 ]; then
        if [ -f "$1" -a -r "$1" ]; then
            cat "$1"
        else
            echo "$1"
        fi
    else
        return 1
    fi | tr "[:upper:]" "[:lower:]"
}

upper() {
    if [ $# -eq 0 ]; then
        cat <&0
    elif [ $# -eq 1 ]; then
        if [ -f "$1" -a -r "$1" ]; then
            cat "$1"
        else
            echo "$1"
        fi
    else
        return 1
    fi | tr "[:lower:]" "[:upper:]"
}

contains() {
    string="$1"
    substring="$2"
    if [ "${string#*$substring}" != "$string" ]; then
        return 0    # $substring is in $string
    else
        return 1    # $substring is not in $string
    fi
}

install() {
    case "$(get_os)" in
        macos)
            if has "brew"; then
                log_echo "Installing ${@} with Homebrew..."
                brew install "$@"
            else
                log_fail "ERROR: Require homebrew!"
                return 1
            fi
            ;;
        linux)
            if has "yum"; then
                log_echo "Install ${@} with Yellowdog Updater Modified"
                sudo yum -y install "$@"
            elif has "apt-get"; then
                log_echo "Install ${@} with Advanced Packaging Tool"
                sudo apt-get -y install "$@"
            else
                log_fail "ERROR: Require yum or apt"
                return 1
            fi
            ;;
        cygwin)
            if has "cyg-fast"; then
                log_echo "Install ${@} with cyg-fast"
                cyg-fast -y install "$@"
            elif has "apt-cyg"; then
                log_echo "Install ${@} with Advanced Packaging Tool for Cygwin"
                apt-cyg install "$@"
            else
                log_fail "ERROR: Require cyg-fast or apt-cyg"
                return 1
            fi
            ;;
    esac
}
