#!/bin/bash
set -euo pipefail

# @raycast.schemaVersion 1
# @raycast.title ChatGPT
# @raycast.packageName Open in Safari
# @raycast.mode silent
# @raycast.icon icons/chatgpt.png
# @raycast.description Open Safari and select the first tab of the front window
# @raycast.author naotone
# @raycast.authorURL https://raycast.com/naotone

osascript <<'EOF'
tell application "Safari"
    if (count of windows) is 0 then
        make new document
    end if
    set current tab of front window to tab 1 of front window
    activate
end tell
EOF
