#!/usr/bin/env zsh

emulate -L zsh

local cdr_list_file="${1:-}"
local excluded_list_file="${2:-}"
local depth_file="${3:-}"
local base_dirs_file="${4:-}"
local exclude_names_file="${5:-}"
local depth=1
local dir
local base_dir
local exclude_name
local -a exclude_expression
local -A excluded_dirs
local -A seen_dirs

if [[ -z "$cdr_list_file" || -z "$excluded_list_file" || -z "$depth_file" || -z "$base_dirs_file" || -z "$exclude_names_file" ]]; then
  exit 1
fi

if [[ -r "$depth_file" ]]; then
  read -r depth < "$depth_file" || depth=1
fi

if [[ "$depth" != <-> ]] || (( depth < 1 )); then
  depth=1
fi

if [[ -r "$excluded_list_file" ]]; then
  while IFS= read -r dir || [[ -n "$dir" ]]; do
    [[ -n "$dir" ]] && excluded_dirs[$dir]=1
  done < "$excluded_list_file"
fi

function emit_candidate() {
  local absolute_dir="$1"
  local source_label="$2"
  local display_dir="$absolute_dir"

  if [[ "$absolute_dir" == "$HOME" ]]; then
    display_dir='~'
  elif [[ "$absolute_dir" == "$HOME/"* ]]; then
    display_dir="~/${absolute_dir#${HOME}/}"
  fi

  print -r -- "$absolute_dir"$'\t'"$display_dir"$'\t'"$source_label"
}

if [[ -r "$cdr_list_file" ]]; then
  while IFS= read -r dir || [[ -n "$dir" ]]; do
    [[ -z "$dir" ]] && continue
    [[ -n "${excluded_dirs[$dir]:-}" ]] && continue
    [[ -n "${seen_dirs[$dir]:-}" ]] && continue

    seen_dirs[$dir]=1
    emit_candidate "$dir" 'cdr history'
  done < "$cdr_list_file"
fi

if [[ -r "$exclude_names_file" ]]; then
  while IFS= read -r exclude_name || [[ -n "$exclude_name" ]]; do
    [[ -n "$exclude_name" ]] && exclude_expression+=(-name "$exclude_name" -o)
  done < "$exclude_names_file"
fi

if (( ${#exclude_expression} )); then
  exclude_expression[-1]=()
fi

function emit_find_candidates() {
  [[ -r "$base_dirs_file" ]] || return 0

  while IFS= read -r base_dir || [[ -n "$base_dir" ]]; do
    [[ -d "$base_dir" ]] || continue

    if (( ${#exclude_expression} )); then
      find "$base_dir" -mindepth 1 -maxdepth "$depth" -type d \
        \( "${exclude_expression[@]}" \) -prune -o -type d -print 2>/dev/null
    else
      find "$base_dir" -mindepth 1 -maxdepth "$depth" -type d -print 2>/dev/null
    fi
  done < "$base_dirs_file"
}

while IFS= read -r dir || [[ -n "$dir" ]]; do
  [[ -z "$dir" ]] && continue
  [[ -n "${excluded_dirs[$dir]:-}" ]] && continue
  [[ -n "${seen_dirs[$dir]:-}" ]] && continue

  seen_dirs[$dir]=1
  emit_candidate "$dir" 'filesystem search'
done < <(emit_find_candidates | LC_ALL=C sort -u)
