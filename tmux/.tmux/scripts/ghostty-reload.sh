#!/bin/bash
set -euo pipefail

# ══════════════════════════════════════════════════════════════
# Ghostty Config Reload Helper
# ══════════════════════════════════════════════════════════════
# Reloads Ghostty config using multiple methods for reliability:
# 1. Touch config file (triggers auto-reload if enabled)
# 2. Send reload keystroke without activation
# 3. Fallback: activate + keystroke

# Only run on macOS if Ghostty is running
if [[ "$(uname)" != "Darwin" ]] || ! pgrep -x ghostty >/dev/null 2>&1; then
    exit 0
fi

GHOSTTY_CONFIG="$HOME/Library/Application Support/com.mitchellh.ghostty/config"

# Method 1: Touch config file to trigger auto-reload (if watch is enabled)
# This is non-disruptive and instant if Ghostty has file watching enabled
if [[ -f "$GHOSTTY_CONFIG" ]]; then
    touch "$GHOSTTY_CONFIG"
    # Give it a moment to detect the change
    sleep 0.1
fi

# Method 2: Send reload keystroke without activation (less disruptive)
reload_result=$(osascript <<EOF 2>/dev/null
tell application "System Events"
    if exists process "Ghostty" then
        tell process "Ghostty"
            try
                keystroke "," using {command down, shift down}
                return "success"
            on error
                return "failed"
            end try
        end tell
    end if
end tell
EOF
)

# If method 2 succeeded, we're done
if [[ "$reload_result" == "success" ]]; then
    exit 0
fi

# Method 3: Fallback - activate briefly then send keystroke
osascript <<EOF >/dev/null 2>&1
tell application "Ghostty"
    activate
end tell
delay 0.2
tell application "System Events"
    tell process "Ghostty"
        keystroke "," using {command down, shift down}
    end tell
end tell
EOF
