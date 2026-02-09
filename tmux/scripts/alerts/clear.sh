#!/usr/bin/env bash
# Clear agent alerts for the current window
# Called by after-select-window hook and window/session switchers

SESSION="$1"
WINDOW="$2"
WINDOW_ID="$3"

SCRIPT_DIR="${BASH_SOURCE%/*}"
source "$SCRIPT_DIR/../_lib/alerts.sh"

# If format strings weren't expanded (display-popup doesn't expand them),
# get the values directly from tmux
if [[ "$SESSION" == '#{session_name}' ]] || [[ -z "$SESSION" ]]; then
    SESSION=$(tmux display-message -p '#S')
    WINDOW=$(tmux display-message -p '#W')
    WINDOW_ID=$(tmux display-message -p '#D')
fi

# Validate session and window names to prevent injection attacks
# Only allow alphanumeric characters, dots, underscores, and hyphens
if [[ ! "$SESSION" =~ ^[a-zA-Z0-9._-]+$ ]] || [[ ! "$WINDOW" =~ ^[a-zA-Z0-9._-]+$ ]]; then
    exit 1
fi

# Clear all agent alerts for this window
clear_window_alerts "$SESSION" "$WINDOW" "$WINDOW_ID"

# Update timestamp for window sorting
"$SCRIPT_DIR/update-timestamp.sh" "$WINDOW_ID"
