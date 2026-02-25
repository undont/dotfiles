#!/usr/bin/env bash
# Display agent alerts for tmux status bar (Claude, OpenCode, etc.)
# Shows one alert per session (aggregates all windows in that session)

SCRIPT_DIR="${BASH_SOURCE%/*}"
ALERTS_FILE="${XDG_CONFIG_HOME:-$HOME/.config}/agent-alerts/alerts"
CURRENT_SESSION=$(tmux display-message -p '#S' 2>/dev/null)

# Source the alerts library for agent configuration
source "$SCRIPT_DIR/../_lib/alerts.sh"

if [[ -f "$ALERTS_FILE" && -s "$ALERTS_FILE" ]]; then
    # Filter alerts to exclude current session
    filtered_alerts=$(grep -v "^${CURRENT_SESSION}:" "$ALERTS_FILE" 2>/dev/null | sort -u)

    if [[ -n "$filtered_alerts" ]]; then
        # Build associative array: session -> agents (aggregate across all windows)
        declare -A session_agents

        while IFS=: read -r session _window agent; do
            # Skip empty lines or malformed entries
            if [[ -z "$session" || -z "$agent" ]]; then
                continue
            fi

            if [[ -z "${session_agents[$session]}" ]]; then
                session_agents[$session]="$agent"
            else
                # Append agent if not already present
                if [[ ! "${session_agents[$session]}" =~ (^|,)${agent}(,|$) ]]; then
                    session_agents[$session]="${session_agents[$session]},${agent}"
                fi
            fi
        done <<< "$filtered_alerts"

        # Display alerts with agent-specific icons using tmux format codes
        output=""
        i=0

        for session in "${!session_agents[@]}"; do
            ((i++))
            if [[ $i -gt 3 ]]; then break; fi

            # Build combined icon string for all agents in this session
            icons=""
            IFS=',' read -ra agents <<< "${session_agents[$session]}"
            for agent in "${agents[@]}"; do
                display=$(get_agent_display "$agent")
                icon="${display%%|*}"
                colour="${display##*|}"
                icons="${icons}#[fg=${colour},bold]${icon}"
            done

            output="${output}${icons} ${session}#[default] "
        done

        # Show overflow count if more than 3 sessions
        session_count="${#session_agents[@]}"
        if [[ $session_count -gt 3 ]]; then
            echo "${output}+ $((session_count-3)) "
        else
            echo "$output"
        fi
    fi
fi
