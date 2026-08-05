#!/bin/bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
TMP_DIR="$(mktemp -d /tmp/zsh_cdr_ctrl_u_candidates.XXXXXX)"
TEST_HOME="$TMP_DIR/home dir"
SEARCH_ROOT="$TEST_HOME"
CDR_LIST_FILE="$TMP_DIR/cdr-list"
EXCLUDED_LIST_FILE="$TMP_DIR/excluded-list"
BASE_DIRS_FILE="$TMP_DIR/base-dirs"
EXCLUDE_NAMES_FILE="$TMP_DIR/exclude-names"
DEPTH_FILE="$TMP_DIR/depth"
ACTUAL_CANDIDATES="$TMP_DIR/actual-candidates"
EXPECTED_CANDIDATES="$TMP_DIR/expected-candidates"
WEAK_CDR_DIR="$TEST_HOME/LLM/models/deepseek-v4-flash"
OUTSIDE_CDR_DIR="$TMP_DIR/outside-cdr"

cleanup() {
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

mkdir -p \
  "$SEARCH_ROOT/a-find" \
  "$SEARCH_ROOT/m-shared" \
  "$SEARCH_ROOT/tmp/nested" \
  "$SEARCH_ROOT/z-cdr-find-history" \
  "$SEARCH_ROOT/z-find" \
  "$SEARCH_ROOT/node_modules/ignored"

cat > "$CDR_LIST_FILE" <<EOF
$WEAK_CDR_DIR
$TEST_HOME
$SEARCH_ROOT/z-cdr-find-history
$SEARCH_ROOT/m-shared
$OUTSIDE_CDR_DIR
EOF

: > "$EXCLUDED_LIST_FILE"
printf '%s\n' "$SEARCH_ROOT" > "$BASE_DIRS_FILE"
printf '%s\n' 'node_modules' > "$EXCLUDE_NAMES_FILE"
printf '%s\n' '2' > "$DEPTH_FILE"

HOME="$TEST_HOME" zsh "$ROOT_DIR/zsh/scripts/generate-cdr-find-candidates.zsh" \
  "$CDR_LIST_FILE" \
  "$EXCLUDED_LIST_FILE" \
  "$DEPTH_FILE" \
  "$BASE_DIRS_FILE" \
  "$EXCLUDE_NAMES_FILE" > "$ACTUAL_CANDIDATES"

printf '%s\t%s\t%s\n' \
  "$WEAK_CDR_DIR" '~/LLM/models/deepseek-v4-flash' 'cdr history' \
  "$TEST_HOME" '~' 'cdr history' \
  "$SEARCH_ROOT/z-cdr-find-history" '~/z-cdr-find-history' 'cdr history' \
  "$SEARCH_ROOT/m-shared" '~/m-shared' 'cdr history' \
  "$OUTSIDE_CDR_DIR" "$OUTSIDE_CDR_DIR" 'cdr history' \
  "$SEARCH_ROOT/a-find" '~/a-find' 'filesystem search' \
  "$SEARCH_ROOT/tmp" '~/tmp' 'filesystem search' \
  "$SEARCH_ROOT/tmp/nested" '~/tmp/nested' 'filesystem search' \
  "$SEARCH_ROOT/z-find" '~/z-find' 'filesystem search' > "$EXPECTED_CANDIDATES"

if ! cmp -s "$EXPECTED_CANDIDATES" "$ACTUAL_CANDIDATES"; then
  echo 'FAIL: candidates are not ordered as cdr history followed by sorted find results'
  diff -u "$EXPECTED_CANDIDATES" "$ACTUAL_CANDIDATES" || true
  exit 1
fi

first_filtered_candidate="$(
  fzf \
    --delimiter=$'\t' \
    --with-nth=2 \
    --accept-nth=1 \
    --scheme=path \
    --filter 'tmp' < "$ACTUAL_CANDIDATES" |
    head -n 1
)"
if [[ "$first_filtered_candidate" != "$SEARCH_ROOT/tmp" ]]; then
  echo 'FAIL: path relevance does not rank ~/tmp ahead of weak history matches'
  exit 1
fi

printf '%s\n' "$SEARCH_ROOT/a-find" > "$EXCLUDED_LIST_FILE"

HOME="$TEST_HOME" zsh "$ROOT_DIR/zsh/scripts/generate-cdr-find-candidates.zsh" \
  "$CDR_LIST_FILE" \
  "$EXCLUDED_LIST_FILE" \
  "$DEPTH_FILE" \
  "$BASE_DIRS_FILE" \
  "$EXCLUDE_NAMES_FILE" > "$ACTUAL_CANDIDATES"

if cut -f1 "$ACTUAL_CANDIDATES" | grep -Fxq "$SEARCH_ROOT/a-find"; then
  echo 'FAIL: session-excluded find candidate remains visible'
  exit 1
fi

if [[ "$(cut -f1 "$ACTUAL_CANDIDATES" | grep -Fxc "$SEARCH_ROOT/m-shared")" != '1' ]]; then
  echo 'FAIL: path shared by cdr and find is not deduplicated'
  exit 1
fi

echo 'PASS: Ctrl-U ranks path matches and separates display paths'
