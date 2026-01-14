#!/usr/bin/env bash
# Display agent alerts for tmux status bar (Claude, OpenCode, etc.)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ALERTS_FILE="$HOME/.claude/alerts"
CURRENT_SESSION=$(tmux display-message -p '#S' 2>/dev/null)

# Source the alerts library for agent configuration
source "$SCRIPT_DIR/_lib/alerts.sh"

if [[ -f "$ALERTS_FILE" && -s "$ALERTS_FILE" ]]; then
    # Filter alerts to exclude current session
    filtered_alerts=$(grep -v "^${CURRENT_SESSION}:" "$ALERTS_FILE" 2>/dev/null | sort -u)
    count=$(echo "$filtered_alerts" | grep -c "^" | tr -d ' ')

    if [[ $count -gt 0 ]]; then
        # Build associative array: window -> agents
        declare -A window_agents
        
        while IFS=: read -r session window agent; do
            # Skip empty lines or malformed entries
            if [[ -z "$session" || -z "$window" ]]; then
                continue
            fi
            
            key="${session}:${window}"
            if [[ -z "${window_agents[$key]}" ]]; then
                window_agents[$key]="$agent"
            else
                # Append agent if not already present
                if [[ ! "${window_agents[$key]}" =~ (^|,)${agent}(,|$) ]]; then
                    window_agents[$key]="${window_agents[$key]},${agent}"
                fi
            fi
        done <<< "$filtered_alerts"
        
        # Display alerts with agent-specific icons using tmux format codes
        output=""
        i=0

        for key in "${!window_agents[@]}"; do
            ((i++))
            if [[ $i -gt 3 ]]; then break; fi

            # Build combined icon string for all agents in this window
            icons=""
            IFS=',' read -ra agents <<< "${window_agents[$key]}"
            for agent in "${agents[@]}"; do
                display=$(get_agent_display "$agent")
                icon="${display%%|*}"
                colour="${display##*|}"
                icons="${icons}#[fg=${colour},bold]${icon}"
            done

            output="${output}${icons} ${key}#[default] "
        done

        # Show overflow count if more than 3 alerts
        window_count="${#window_agents[@]}"
        if [[ $window_count -gt 3 ]]; then
            echo "${output}+ $((window_count-3)) "
        else
            echo "$output"
        fi
    fi
fi
