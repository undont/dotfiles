#!/usr/bin/env bash
# Agent alert utilities for tmux scripts
# Source this file after common.sh

# Disable unbound variable check for this file since we use associative array keys
set +u

# Alerts file location
readonly ALERTS_FILE="$HOME/.claude/alerts"

# Alert file format: session:window:agent
# Future enhancement: Add timestamp field for age-based sorting and auto-expiry
# Proposed format: session:window:agent:timestamp

# Agent visual identity configuration
declare -A AGENT_ICONS=(
    ["claude"]="⚡"
    ["opencode"]="🔮"
    ["unknown"]="🤖"
)

declare -A AGENT_COLOURS=(
    ["claude"]="#f1fa8c"      # Yellow
    ["opencode"]="#bd93f9"    # Dracula purple
    ["unknown"]="#6272a4"     # Dracula blue
)

# Get agent display icon and colour
# Usage: get_agent_display "agent_name"
# Returns: "icon|colour"
get_agent_display() {
    local agent="$1"
    local icon="${AGENT_ICONS[$agent]:-${AGENT_ICONS[unknown]}}"
    local colour="${AGENT_COLOURS[$agent]:-${AGENT_COLOURS[unknown]}}"
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
        local tmp_file="${ALERTS_FILE}.tmp.$$"
        local grep_exit=0
        grep -v "^${session}:${window}:" "$ALERTS_FILE" > "$tmp_file" 2>/dev/null || grep_exit=$?
        
        # Exit code 0 or 1 are both success (0 = matches found, 1 = no matches/all filtered)
        if [[ $grep_exit -le 1 ]]; then
            mv "$tmp_file" "$ALERTS_FILE" 2>/dev/null || rm -f "$tmp_file"
        else
            # grep encountered an error - clean up
            rm -f "$tmp_file"
        fi
    fi

    # Unset all @*_alert window options (agent-agnostic wildcard clearing)
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
        local tmp_file="${ALERTS_FILE}.tmp.$$"
        local grep_exit=0
        grep -v "^${session}:" "$ALERTS_FILE" > "$tmp_file" 2>/dev/null || grep_exit=$?
        
        # Exit code 0 or 1 are both success (0 = matches found, 1 = no matches/all filtered)
        if [[ $grep_exit -le 1 ]]; then
            mv "$tmp_file" "$ALERTS_FILE" 2>/dev/null || rm -f "$tmp_file"
        else
            # grep encountered an error - clean up
            rm -f "$tmp_file"
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
