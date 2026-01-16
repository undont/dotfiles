#!/usr/bin/env bash
# Agent alert utilities for tmux scripts
# Source this file after common.sh

# Alerts file location
readonly ALERTS_FILE="$HOME/.claude/alerts"

# Get agent icon (compatible with bash 3.2 - no associative arrays)
# Usage: get_agent_icon "agent_name"
# Returns: icon symbol
get_agent_icon() {
    local agent="$1"
    case "$agent" in
        claude) echo "⚡" ;;
        gemini) echo "🤖" ;;
        opencode) echo "🔮" ;;
        *) echo "🤖" ;;
    esac
}

# Get agent colour (compatible with bash 3.2 - no associative arrays)
# Usage: get_agent_colour "agent_name"
# Returns: hex colour code
get_agent_colour() {
    local agent="$1"
    case "$agent" in
        claude) echo "#f1fa8c" ;;      # Yellow
        gemini) echo "#8be9fd" ;;     # Cyan
        opencode) echo "#bd93f9" ;;    # Dracula purple
        *) echo "#6272a4" ;;           # Dracula blue
    esac
}

# Get agent display icon and colour
# Usage: get_agent_display "agent_name"
# Returns: "icon|colour"
get_agent_display() {
    local agent="$1"
    local icon
    local colour
    icon=$(get_agent_icon "$agent")
    colour=$(get_agent_colour "$agent")
    echo "$icon|$colour"
}

# Clear all alerts for a specific window
# Usage: clear_window_alerts "session" "window" ["window_id"]
clear_window_alerts() {
    local session="$1"
    local window="$2"
    local window_id="${3:-}"

    # Remove from alerts file (any agent)
    if [[ -f "$ALERTS_FILE" ]]; then
        local grep_exit=0
        grep -v "^${session}:${window}:" "$ALERTS_FILE" > "${ALERTS_FILE}.tmp" 2>/dev/null || grep_exit=$?
        if [[ $grep_exit -le 1 ]]; then
            mv "${ALERTS_FILE}.tmp" "$ALERTS_FILE"
        else
            rm -f "${ALERTS_FILE}.tmp"
        fi
    fi

    # Clear all agent alert options dynamically
    local target
    if [[ -n "$window_id" ]]; then
        target="$window_id"
    else
        target="${session}:${window}"
    fi

    # Clear all agent alert options dynamically
    tmux show-options -wt "$target" 2>/dev/null | \
        grep '@.*_alert' | \
        cut -d' ' -f1 | \
        xargs -I{} tmux set-option -wt "$target" -u {} 2>/dev/null || true
}

# Clear all alerts for a session
# Usage: clear_session_alerts "session"
clear_session_alerts() {
    local session="$1"

    # Remove all entries for this session from alerts file
    if [[ -f "$ALERTS_FILE" ]]; then
        local grep_exit=0
        grep -v "^${session}:" "$ALERTS_FILE" > "${ALERTS_FILE}.tmp" 2>/dev/null || grep_exit=$?
        if [[ $grep_exit -le 1 ]]; then
            mv "${ALERTS_FILE}.tmp" "$ALERTS_FILE"
        else
            rm -f "${ALERTS_FILE}.tmp"
        fi
    fi

    # Unset agent options for all windows in session
    local win
    for win in $(tmux list-windows -t "$session" -F '#D' 2>/dev/null); do
        # Clear all agent alert options dynamically
        tmux show-options -wt "$win" 2>/dev/null | \
            grep '@.*_alert' | \
            cut -d' ' -f1 | \
            xargs -I{} tmux set-option -wt "$win" -u {} 2>/dev/null || true
    done
}
