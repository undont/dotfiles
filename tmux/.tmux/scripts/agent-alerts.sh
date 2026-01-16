#!/bin/bash
# Display agent alerts for tmux status bar (Claude, Gemini, OpenCode, etc.)

SCRIPT_DIR="${BASH_SOURCE%/*}"
source "$SCRIPT_DIR/_lib/alerts.sh"

ALERTS_FILE="$HOME/.claude/alerts"
CURRENT_SESSION=$(tmux display-message -p '#S' 2>/dev/null)

if [[ -f "$ALERTS_FILE" && -s "$ALERTS_FILE" ]]; then
    # Filter alerts to exclude current session
    filtered_alerts=$(grep -v "^${CURRENT_SESSION}:" "$ALERTS_FILE" 2>/dev/null | sort -u)
    count=$(echo "$filtered_alerts" | grep -c "^" | tr -d ' ')

    if [[ $count -gt 0 ]]; then
        output=""
        i=0
        while IFS=: read -r session window agent; do
            # Skip empty lines or malformed entries
            if [[ -z "$session" || -z "$window" ]]; then
                continue
            fi

            ((i++))
            if [[ $i -gt 3 ]]; then break; fi

            # Get agent display info using generic function
            display=$(get_agent_display "$agent")
            icon="${display%%|*}"
            color="${display##*|}"

            output="${output}#[fg=${color},bold]${icon} ${session}:${window}#[default] "
        done <<< "$filtered_alerts"

        if [[ $count -gt 3 ]]; then
            echo "${output}+ $((count-3)) "
        else
            echo "$output"
        fi
    fi
fi
