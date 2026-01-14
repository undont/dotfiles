#!/usr/bin/env bash
# OpenCode alert wrapper for git hooks
# Triggers tmux window alerts when OpenCode makes changes

set -euo pipefail

# Get the current session and window
SESSION=$(tmux display-message -p '#{session_name}' 2>/dev/null || echo "")
WINDOW=$(tmux display-message -p '#{window_name}' 2>/dev/null || echo "")

# Only set alert if we're in a tmux session
if [[ -n "$SESSION" && -n "$WINDOW" ]]; then
    # Set alert file
    ALERTS_FILE="$HOME/.claude/alerts"
    mkdir -p "$(dirname "$ALERTS_FILE")"
    
    # Add alert entry: session:window:agent
    echo "${SESSION}:${WINDOW}:opencode" >> "$ALERTS_FILE"
    
    # Remove duplicates
    sort -u "$ALERTS_FILE" > "${ALERTS_FILE}.tmp"
    mv "${ALERTS_FILE}.tmp" "$ALERTS_FILE"
fi

exit 0
