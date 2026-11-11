#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
TEST_DIR="$(mktemp -d)"
trap 'rm -rf "$TEST_DIR"' EXIT

cat > "$TEST_DIR/osascript" <<'EOF'
#!/bin/bash
cat > "$CAPTURE_FILE"
exit "${MOCK_EXIT_CODE:-0}"
EOF
chmod +x "$TEST_DIR/osascript"
export PATH="$TEST_DIR:$PATH"
export CAPTURE_FILE="$TEST_DIR/script.applescript"

bash "$ROOT_DIR/raycast/chatgpt.sh"
test -s "$CAPTURE_FILE"
grep -q 'tell application "Safari"' "$CAPTURE_FILE"
grep -q 'set current tab of front window to tab 1 of front window' "$CAPTURE_FILE"

status=0
MOCK_EXIT_CODE=42 bash "$ROOT_DIR/raycast/chatgpt.sh" || status=$?
test "$status" -eq 42
echo 'PASS: Safari script dispatch and error propagation'
