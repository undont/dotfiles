#!/usr/bin/env bash
# Display agent alerts for tmux status bar (Claude, OpenCode, etc.)
# Shows one alert per session (aggregates all windows in that session)
# Also handles command exit alerts (session:window:exit:<code>:<label>)

SCRIPT_DIR="${BASH_SOURCE%/*}"
ALERTS_FILE="${XDG_CONFIG_HOME:-$HOME/.config}/agent-alerts/alerts"
CURRENT_SESSION=$(tmux display-message -p '#S' 2>/dev/null)

# Source the alerts library for agent configuration
source "$SCRIPT_DIR/../_lib/alerts.sh"

if [[ -f "$ALERTS_FILE" && -s "$ALERTS_FILE" ]]; then
    # Filter alerts to exclude current session
    filtered_alerts=$(grep -v "^${CURRENT_SESSION}:" "$ALERTS_FILE" 2>/dev/null | sort -u)

    if [[ -n "$filtered_alerts" ]]; then
        # Build per-session display entries
        # session_agents: session -> comma-separated agent names
        # session_exit: session -> "icon|colour|label" for exit alerts (last wins)
        declare -A session_agents
        declare -A session_exit

        while IFS= read -r line; do
            # Split on ':' — exit alerts have 5 fields, agent alerts have 3
            IFS=':' read -r session _window field3 field4 field5 <<< "$line"

            # Skip empty lines or malformed entries
            if [[ -z "$session" || -z "$field3" ]]; then
                continue
            fi

            if [[ "$field3" == "exit" ]]; then
                # Exit alert: session:window:exit:<code>:<label>
                local_code="$field4"
                local_label="$field5"
                display=$(get_exit_code_display "$local_code")
                session_exit[$session]="${display}|${local_label}"
            else
                # Agent alert: session:window:agent (field3 is the agent name)
                agent="$field3"
                if [[ -z "${session_agents[$session]}" ]]; then
                    session_agents[$session]="$agent"
                else
                    # Append agent if not already present
                    if [[ ! "${session_agents[$session]}" =~ (^|,)${agent}(,|$) ]]; then
                        session_agents[$session]="${session_agents[$session]},${agent}"
                    fi
                fi
            fi
        done <<< "$filtered_alerts"

        # Collect all unique sessions across both maps
        declare -A all_sessions
        for s in "${!session_agents[@]}" "${!session_exit[@]}"; do
            all_sessions[$s]=1
        done

        output=""
        i=0

        for session in "${!all_sessions[@]}"; do
            ((i++))
            if [[ $i -gt 3 ]]; then break; fi

            # Build combined display for this session
            icons=""

            # Agent icons first
            if [[ -n "${session_agents[$session]:-}" ]]; then
                IFS=',' read -ra agents <<< "${session_agents[$session]}"
                for agent in "${agents[@]}"; do
                    display=$(get_agent_display "$agent")
                    icon="${display%%|*}"
                    colour="${display##*|}"
                    icons="${icons}#[fg=${colour},bold]${icon}"
                done
                output="${output}${icons} ${session}#[default] "
            fi

            # Exit alert: show "icon session:label"
            if [[ -n "${session_exit[$session]:-}" ]]; then
                exit_data="${session_exit[$session]}"
                # Format: icon|colour|label
                exit_icon="${exit_data%%|*}"
                rest="${exit_data#*|}"
                exit_colour="${rest%%|*}"
                exit_label="${rest##*|}"
                output="${output}#[fg=${exit_colour},bold]${exit_icon} ${session}:${exit_label}#[default] "
            fi
        done

        # Show overflow count if more than 3 sessions
        session_count="${#all_sessions[@]}"
        if [[ $session_count -gt 3 ]]; then
            echo "${output}+ $((session_count-3)) "
        else
            echo "$output"
        fi
    fi
fi
