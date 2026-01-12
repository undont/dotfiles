#!/bin/bash
# Display agent alerts for tmux status bar (Claude, etc.)

ALERTS_FILE="$HOME/.claude/alerts"
CURRENT_SESSION=$(tmux display-message -p '#S' 2>/dev/null)

if [[ -f "$ALERTS_FILE" && -s "$ALERTS_FILE" ]]; then
    # Filter alerts to exclude current session
    filtered_alerts=$(grep -v "^${CURRENT_SESSION}:" "$ALERTS_FILE" 2>/dev/null | sort -u)
    count=$(echo "$filtered_alerts" | grep -c "^" | tr -d ' ')

    if [[ $count -gt 0 ]]; then
        output=""
        i=0
        seen=""

        # Build unique list of session:window (ignoring agent)
        while IFS=: read -r session window agent; do
            # Skip empty lines or malformed entries
            if [[ -z "$session" || -z "$window" ]]; then
                continue
            fi

            # Skip if we've already seen this session:window combination
            key="${session}:${window}"
            if [[ "$seen" == *"|${key}|"* ]]; then
                continue
            fi
            seen="${seen}|${key}|"

            ((i++))
            if [[ $i -gt 3 ]]; then break; fi

            # Display with icon
            icon="⚡"
            color="#f1fa8c" # Yellow

            output="${output}#[fg=${color},bold]${icon} ${session}:${window}#[default] "
        done <<< "$filtered_alerts"

        if [[ $count -gt 3 ]]; then
            echo "${output}+ $((count-3)) "
        else
            echo "$output"
        fi
    fi
fi
