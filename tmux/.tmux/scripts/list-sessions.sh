#!/usr/bin/env bash
# List tmux sessions sorted by activity (most recent first)
# Used by the session switcher (prefix + s)
# Shows agent-specific indicators for sessions with alerts

SCRIPT_DIR="${BASH_SOURCE%/*}"
# Note: Production scripts use ${BASH_SOURCE%/*} pattern.
# Test scripts use $(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd).
source "$SCRIPT_DIR/_lib/alerts.sh"

# Get sessions sorted by activity
while read -r session; do
    # Check if this session has any alerts and collect unique agents
    if [[ -f "$ALERTS_FILE" ]]; then
        agents=$(grep "^${session}:" "$ALERTS_FILE" 2>/dev/null | cut -d: -f3 | sort -u)
        if [[ -n "$agents" ]]; then
            # Build icon string for all agents in this session
            icons=""
            while IFS= read -r agent; do
                display=$(get_agent_display "$agent")
                icon="${display%%|*}"
                icons="${icons}${icon}"
            done <<< "$agents"
            echo "${session} ${icons}"
        else
            echo "$session"
        fi
    else
        echo "$session"
    fi
done < <(tmux list-sessions -F '#{session_activity} #{session_name}' | sort -rn | cut -d' ' -f2-)
