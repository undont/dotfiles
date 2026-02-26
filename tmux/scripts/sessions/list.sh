#!/usr/bin/env bash
# List tmux sessions sorted by activity (most recent first)
# Used by the session switcher (prefix + s)
# Shows agent-specific indicators for sessions with alerts

SCRIPT_DIR="${BASH_SOURCE%/*}"
# Note: Production scripts use ${BASH_SOURCE%/*} pattern.
# Test scripts use $(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd).
# shellcheck source=tmux/scripts/_lib/common.sh
source "$SCRIPT_DIR/../_lib/common.sh"
# shellcheck source=tmux/scripts/_lib/alerts.sh
source "$SCRIPT_DIR/../_lib/alerts.sh"

load_fzf_theme
print_dotfiles_logo

# Get sessions sorted by activity
while read -r session; do
    # Check if this session has any alerts and collect unique agents
    if [[ -f "$ALERTS_FILE" ]]; then
        session_alerts=$(grep "^${session}:" "$ALERTS_FILE" 2>/dev/null)
        if [[ -n "$session_alerts" ]]; then
            # Build icon string for all alerts in this session
            icons=""
            while IFS= read -r entry; do
                IFS=':' read -r _sess _win field3 field4 field5 <<< "$entry"
                if [[ "$field3" == "exit" ]]; then
                    display=$(get_exit_code_display "$field4")
                    icon="${display%%|*}"
                    colour="${display##*|}"
                    icons="${icons}\033[38;2;$(printf '%d;%d;%d' "0x${colour:1:2}" "0x${colour:3:2}" "0x${colour:5:2}")m${icon} ${field5}\033[0m "
                else
                    display=$(get_agent_display "$field3")
                    icon="${display%%|*}"
                    icons="${icons}${icon} "
                fi
            done <<< "$session_alerts"
            printf "%s %b\n" "${session}" "${icons}"
        else
            echo "$session"
        fi
    else
        echo "$session"
    fi
done < <(tmux list-sessions -F '#{session_activity} #{session_name}' | sort -rn | cut -d' ' -f2-)
