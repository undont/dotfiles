#!/bin/bash
# List tmux sessions sorted by activity (most recent first)
# Used by the session switcher (prefix + s)
# Shows ⚡ indicator for sessions with Claude alerts

SCRIPT_DIR="${BASH_SOURCE%/*}"
source "$SCRIPT_DIR/_lib/alerts.sh"

# Get sessions sorted by activity
while read -r session; do
    # Check if this session has any alerts
    # Alerts file format: SESSION:WINDOW:AGENT
    if [[ -f "$ALERTS_FILE" ]]; then
        alert_line=$(grep "^${session}:" "$ALERTS_FILE" 2>/dev/null | head -1)
        if [[ -n "$alert_line" ]]; then
            agent=$(echo "$alert_line" | cut -d: -f3)
            icon="⚡"
            if [[ "$agent" == "gemini" ]]; then
                icon="🤖"
            fi
            echo "${session} ${icon}"
        else
            echo "$session"
        fi
    else
        echo "$session"
    fi
done < <(tmux list-sessions -F '#{session_activity} #{session_name}' | sort -rn | cut -d' ' -f2-)
