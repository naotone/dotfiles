#!/bin/bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
TMP_DIR="$(mktemp -d /tmp/zsh_cdr_ctrl_u_candidates.XXXXXX)"
SEARCH_ROOT="$TMP_DIR/search root"
CDR_LIST_FILE="$TMP_DIR/cdr-list"
EXCLUDED_LIST_FILE="$TMP_DIR/excluded-list"
BASE_DIRS_FILE="$TMP_DIR/base-dirs"
EXCLUDE_NAMES_FILE="$TMP_DIR/exclude-names"
DEPTH_FILE="$TMP_DIR/depth"
ACTUAL_CANDIDATES="$TMP_DIR/actual-candidates"
EXPECTED_CANDIDATES="$TMP_DIR/expected-candidates"

cleanup() {
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

mkdir -p \
  "$SEARCH_ROOT/a-find" \
  "$SEARCH_ROOT/m-shared" \
  "$SEARCH_ROOT/z-cdr-find-history" \
  "$SEARCH_ROOT/z-find" \
  "$SEARCH_ROOT/node_modules/ignored"

cat > "$CDR_LIST_FILE" <<EOF
$SEARCH_ROOT/z-cdr-find-history
$SEARCH_ROOT/m-shared
EOF

: > "$EXCLUDED_LIST_FILE"
printf '%s\n' "$SEARCH_ROOT" > "$BASE_DIRS_FILE"
printf '%s\n' 'node_modules' > "$EXCLUDE_NAMES_FILE"
printf '%s\n' '2' > "$DEPTH_FILE"

zsh "$ROOT_DIR/zsh/scripts/generate-cdr-find-candidates.zsh" \
  "$CDR_LIST_FILE" \
  "$EXCLUDED_LIST_FILE" \
  "$DEPTH_FILE" \
  "$BASE_DIRS_FILE" \
  "$EXCLUDE_NAMES_FILE" > "$ACTUAL_CANDIDATES"

cat > "$EXPECTED_CANDIDATES" <<EOF
$SEARCH_ROOT/z-cdr-find-history
$SEARCH_ROOT/m-shared
$SEARCH_ROOT/a-find
$SEARCH_ROOT/z-find
EOF

if ! cmp -s "$EXPECTED_CANDIDATES" "$ACTUAL_CANDIDATES"; then
  echo 'FAIL: candidates are not ordered as cdr history followed by sorted find results'
  diff -u "$EXPECTED_CANDIDATES" "$ACTUAL_CANDIDATES" || true
  exit 1
fi

first_filtered_candidate="$(fzf --no-sort --filter 'find' < "$ACTUAL_CANDIDATES" | head -n 1)"
if [[ "$first_filtered_candidate" != "$SEARCH_ROOT/z-cdr-find-history" ]]; then
  echo 'FAIL: fuzzy filtering does not keep matching cdr history ahead of find results'
  exit 1
fi

printf '%s\n' "$SEARCH_ROOT/a-find" > "$EXCLUDED_LIST_FILE"

zsh "$ROOT_DIR/zsh/scripts/generate-cdr-find-candidates.zsh" \
  "$CDR_LIST_FILE" \
  "$EXCLUDED_LIST_FILE" \
  "$DEPTH_FILE" \
  "$BASE_DIRS_FILE" \
  "$EXCLUDE_NAMES_FILE" > "$ACTUAL_CANDIDATES"

if grep -Fxq "$SEARCH_ROOT/a-find" "$ACTUAL_CANDIDATES"; then
  echo 'FAIL: session-excluded find candidate remains visible'
  exit 1
fi

if [[ "$(grep -Fxc "$SEARCH_ROOT/m-shared" "$ACTUAL_CANDIDATES")" != '1' ]]; then
  echo 'FAIL: path shared by cdr and find is not deduplicated'
  exit 1
fi

echo 'PASS: Ctrl-U prioritizes cdr history over find results'
