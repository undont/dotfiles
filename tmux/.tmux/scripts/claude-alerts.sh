#!/bin/bash
# Display agent alerts for tmux status bar (Claude, Gemini, etc.)

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

            # Default icon and color
            icon="⚡"
            color="#f1fa8c" # Yellow

            if [[ "$agent" == "gemini" ]]; then
                icon="🤖"
                color="#8be9fd" # Dracula Cyan (Blue-ish)
            fi

            output="${output}#[fg=${color},bold]${icon} ${session}:${window}#[default] "
        done <<< "$filtered_alerts"

        if [[ $count -gt 3 ]]; then
            echo "${output}+ $((count-3)) "
        else
            echo "$output"
        fi
    fi
fi
