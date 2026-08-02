#!/usr/bin/env zsh

set -euo pipefail

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  exit 0
fi

local current_branch
local branch
local refs
local reflog_message
local destination
local -a branches
local -A local_branches
local -A seen

current_branch="$(git symbolic-ref --quiet --short HEAD 2>/dev/null || true)"
refs="$(git for-each-ref --sort=-committerdate --format='%(if)%(worktreepath)%(then)%(else)%(refname:short)%(end)' refs/heads)"
branches=("${(@f)refs}")

for branch in "${branches[@]}"; do
  [[ -n "$branch" ]] && local_branches[$branch]=1
done

while IFS= read -r reflog_message; do
  if [[ "$reflog_message" != 'checkout: moving from '* ]]; then
    continue
  fi

  destination="${reflog_message##* to }"
  if [[ -z "$destination" || "$destination" == "$current_branch" ]]; then
    continue
  fi

  if [[ -n "${local_branches[$destination]:-}" && -z "${seen[$destination]:-}" ]]; then
    print -r -- "$destination"
    seen[$destination]=1
  fi
done < <(git reflog show --format='%gs' HEAD 2>/dev/null || true)

for branch in "${branches[@]}"; do
  if [[ -n "$branch" && "$branch" != "$current_branch" && -z "${seen[$branch]:-}" ]]; then
    print -r -- "$branch"
  fi
done
