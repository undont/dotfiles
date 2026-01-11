#!/bin/bash
# List tmux sessions sorted by activity (most recent first)
# Used by the session switcher (prefix + s)
# Shows ⚡ indicator for sessions with Claude alerts

SCRIPT_DIR="${BASH_SOURCE%/*}"
source "$SCRIPT_DIR/_lib/alerts.sh"

# Get sessions sorted by activity
while read -r session; do
    # Check if this session has any alerts
    if [[ -f "$CLAUDE_ALERTS_FILE" ]] && grep -qF "${session}:" "$CLAUDE_ALERTS_FILE" 2>/dev/null; then
        echo "${session} ⚡"
    else
        echo "$session"
    fi
done < <(tmux list-sessions -F '#{session_activity} #{session_name}' | sort -rn | cut -d' ' -f2-)
