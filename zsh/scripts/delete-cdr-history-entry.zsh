#!/usr/bin/env zsh

emulate -L zsh

local recent_dirs_file="${1:-}"
local selected_dir="${2:-}"
local cdr_list_file="${3:-}"
local recent_dirs_max="${4:-20}"
local deleted_list_file="${5:-}"
local dir
local found=0
local -a filtered_dirs

if [[ -z "$recent_dirs_file" || -z "$selected_dir" || -z "$cdr_list_file" ]]; then
  exit 1
fi

if [[ "$recent_dirs_max" != <-> ]]; then
  recent_dirs_max=20
fi

zstyle ':chpwd:*' recent-dirs-file "$recent_dirs_file"
zstyle ':chpwd:*' recent-dirs-max "$recent_dirs_max"
autoload -Uz chpwd_recent_filehandler
chpwd_recent_filehandler

for dir in "${reply[@]}"; do
  if [[ "$dir" == "$selected_dir" ]]; then
    found=1
    continue
  fi

  filtered_dirs+=("$dir")
done

if (( found )); then
  if (( ${#filtered_dirs} )); then
    chpwd_recent_filehandler "${filtered_dirs[@]}"
  else
    : >| "$recent_dirs_file"
  fi
fi

if [[ -n "$deleted_list_file" ]] && ! grep -Fxq -- "$selected_dir" "$deleted_list_file" 2>/dev/null; then
  print -r -- "$selected_dir" >> "$deleted_list_file"
fi

: >| "$cdr_list_file"
for dir in "${filtered_dirs[@]}"; do
  [[ "$dir" == "$PWD" ]] || print -r -- "$dir" >> "$cdr_list_file"
done
