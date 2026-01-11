#!/usr/bin/env bash
# Update the @last-viewed timestamp for the current window
# Also clears any claude alert as a safety net

SCRIPT_DIR="${BASH_SOURCE%/*}"
source "$SCRIPT_DIR/_lib/alerts.sh"

TIMESTAMP=$(date +%s)
WINDOW_ID="$1"

tmux set-option -wt "$WINDOW_ID" @last-viewed "$TIMESTAMP" 2>/dev/null || true

# Clear any claude alert for this window (safety net)
SESSION=$(tmux display-message -t "$WINDOW_ID" -p '#S' 2>/dev/null)
WINDOW=$(tmux display-message -t "$WINDOW_ID" -p '#W' 2>/dev/null)
if [[ -n "$SESSION" && -n "$WINDOW" ]]; then
    clear_window_alert "$SESSION" "$WINDOW" "$WINDOW_ID"
fi
