#!/bin/bash

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Electron Dev
# @raycast.mode compact

# Optional parameters:
# @raycast.icon 🤖

# Documentation:
# @raycast.author naotone
# @raycast.authorURL https://raycast.com/naotone


osascript <<EOF
tell application "Electron"
    activate
end tell
EOF


