#!/bin/bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
SOURCE_FILE="${1:-$ROOT_DIR/zsh/init/12_moshi_git_signing.zsh}"
TEST_DIR="$(mktemp -d)"
trap 'rm -rf "$TEST_DIR"' EXIT
mkdir -p "$TEST_DIR/git"
printf '[user]\n signingkey = ssh-ed25519 MOSHI_TEST_KEY\n[gpg "ssh"]\n program = /usr/bin/ssh-keygen\n' > "$TEST_DIR/git/moshi-signing.conf"
printf '[user]\n signingkey = LOCAL_KEY\n[gpg "ssh"]\n program = LOCAL_SIGNER\n' > "$TEST_DIR/global"
XDG_CONFIG_HOME="$TEST_DIR" GIT_CONFIG_GLOBAL="$TEST_DIR/global" GIT_CONFIG_NOSYSTEM=1 zsh -f -s -- "$SOURCE_FILE" <<'ZSH'
set -eu
source_file="$1"
reset_env() {
  unset SSH_CONNECTION SSH_TTY SSH_AUTH_SOCK GIT_CONFIG_COUNT
  export GIT_CONFIG_COUNT=0
  offered='ssh-ed25519 MOSHI_TEST_KEY phone'
  agent_status=0
}
ssh-add() { print -r -- "$offered"; return "$agent_status"; }
check() { [[ "$1" == "$2" ]] || { print -u2 -- "FAIL: $3: $1 != $2"; exit 1; }; }
reset_env
source "$source_file"
check "$(git config user.signingkey)" LOCAL_KEY local
check "$(git config gpg.ssh.program)" LOCAL_SIGNER local_signer
reset_env
export SSH_CONNECTION='100.1.2.3 123 100.96.4.46 22' SSH_AUTH_SOCK=/tmp/forwarded
source "$source_file"
check "$(git config user.signingkey)" 'ssh-ed25519 MOSHI_TEST_KEY' forwarded
check "$(git config gpg.ssh.program)" /usr/bin/ssh-keygen forwarded_signer
source "$source_file"
check "$GIT_CONFIG_COUNT" 1 idempotent
check "$(git -c user.signingkey=EXPLICIT config user.signingkey)" EXPLICIT explicit_override
reset_env
export SSH_TTY=/dev/ttys099 SSH_AUTH_SOCK=/tmp/forwarded
export GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0=core.editor GIT_CONFIG_VALUE_0=existing-editor
source "$source_file"
check "$GIT_CONFIG_COUNT" 2 preserve_count
check "$(git config core.editor)" existing-editor preserve_config
check "$(git config user.signingkey)" 'ssh-ed25519 MOSHI_TEST_KEY' tty_only
reset_env
export SSH_CONNECTION=remote
source "$source_file"
check "$GIT_CONFIG_COUNT" 0 missing_socket
reset_env
export SSH_CONNECTION=remote SSH_AUTH_SOCK=/tmp/forwarded
agent_status=2
source "$source_file"
check "$GIT_CONFIG_COUNT" 0 disconnected_agent
reset_env
export SSH_CONNECTION=remote SSH_AUTH_SOCK=/tmp/forwarded
offered='ssh-ed25519 OTHER_KEY phone'
source "$source_file"
check "$GIT_CONFIG_COUNT" 0 other_key
reset_env
export SSH_CONNECTION=remote SSH_AUTH_SOCK="$HOME/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock"
ssh-add() { print -u2 'FAIL: queried local agent'; return 99; }
source "$source_file"
check "$GIT_CONFIG_COUNT" 0 local_agent
print 'PASS: Moshi Git signing environment (13 assertions)'
ZSH
