#!/bin/bash
# List tmux windows sorted by last viewed (most recent first)
# Used by the window switcher (prefix + f)
# Shows ⚡ indicator for windows with Claude alerts
#
# Usage: list-windows.sh [--all]
#   --all: List windows from all sessions (default: current session only)

SCRIPT_DIR="${BASH_SOURCE%/*}"
source "$SCRIPT_DIR/_lib/alerts.sh"

# Get windows sorted by last-viewed, then add alert indicator
if [[ "$1" == "--all" ]]; then
    # All sessions: session_name:window_index window_name
    FORMAT='#{?#{@last-viewed},#{@last-viewed},0} #{session_name}:#{window_index} #{window_name}'
    tmux list-windows -a -F "$FORMAT"
else
    # Current session only
    SESSION=$(tmux display-message -p '#S')
    FORMAT="#{?#{@last-viewed},#{@last-viewed},0} ${SESSION}:#{window_index} #{window_name}"
    tmux list-windows -F "$FORMAT"
fi | sort -rn | cut -d' ' -f2- | while read -r line; do
    # Line format: "session:window_index window_name"
    # Alerts file format: "session:window_name"
    session_idx=$(echo "$line" | cut -d' ' -f1)      # e.g., "dotfiles:1"
    session_name="${session_idx%%:*}"                 # e.g., "dotfiles"
    window_name=$(echo "$line" | cut -d' ' -f2-)      # e.g., "dev"
    alert_key="${session_name}:${window_name}:"       # e.g., "dotfiles:dev:" (prefix match)

    # Check if this window has an alert (any agent)
    if [[ -f "$ALERTS_FILE" ]] && grep -qF "$alert_key" "$ALERTS_FILE" 2>/dev/null; then
        echo "$line ⚡"
    else
        echo "$line"
    fi
done
