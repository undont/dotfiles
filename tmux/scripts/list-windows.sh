#!/usr/bin/env bash
# List tmux windows sorted by last viewed (most recent first)
# Used by the window switcher (prefix + f)
# Shows agent-specific indicators for windows with alerts
#
# Usage: list-windows.sh [--all]
#   --all: List windows from all sessions (default: current session only)

SCRIPT_DIR="${BASH_SOURCE%/*}"
# shellcheck source=tmux/scripts/_lib/common.sh
source "$SCRIPT_DIR/_lib/common.sh"
# shellcheck source=tmux/scripts/_lib/alerts.sh
source "$SCRIPT_DIR/_lib/alerts.sh"

load_fzf_theme
print_dotfiles_logo

# Get windows sorted by last-viewed, then add alert indicator
if [[ "$1" == "--all" ]]; then
    # All sessions: session_name:window_index window_name
    FORMAT='#{?#{@last-viewed},#{@last-viewed},0} #{session_name}:#{window_index} #{window_name}'
    tmux list-windows -a -F "$FORMAT"
else
    # Current session only
    SESSION=$(tmux display-message -p '#S')
    FORMAT="#{?#{@last-viewed},#{@last-viewed},0} ${SESSION}:#{window_index} #{window_name}"
    tmux list-windows -F "$FORMAT"
fi | sort -rn | cut -d' ' -f2- | while read -r line; do
    # Line format: "session:window_index window_name"
    # Alerts file format: "session:window_name:agent"
    session_idx=$(echo "$line" | cut -d' ' -f1)      # e.g., "dotfiles:1"
    session_name="${session_idx%%:*}"                 # e.g., "dotfiles"
    window_name=$(echo "$line" | cut -d' ' -f2-)      # e.g., "dev"
    alert_key="${session_name}:${window_name}:"       # e.g., "dotfiles:dev:" (prefix match)

    # Check if this window has alerts and collect unique agents
    if [[ -f "$ALERTS_FILE" ]]; then
        agents=$(grep "^${alert_key}" "$ALERTS_FILE" 2>/dev/null | cut -d: -f3 | sort -u)
        if [[ -n "$agents" ]]; then
            # Build icon string for all agents in this window
            icons=""
            while IFS= read -r agent; do
                display=$(get_agent_display "$agent")
                icon="${display%%|*}"
                icons="${icons}${icon}"
            done <<< "$agents"
            echo "$line ${icons}"
        else
            echo "$line"
        fi
    else
        echo "$line"
    fi
done
