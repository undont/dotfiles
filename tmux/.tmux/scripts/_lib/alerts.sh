#!/usr/bin/env bash
# Agent alert utilities for tmux scripts
# Source this file after common.sh

# Alerts file location
readonly ALERTS_FILE="$HOME/.claude/alerts"

# Alert file format: session:window:agent
# Future enhancement: Add timestamp field for age-based sorting and auto-expiry
# Proposed format: session:window:agent:timestamp

# Get agent icon (compatible with bash 3.2 - no associative arrays)
# Usage: get_agent_icon "agent_name"
# Returns: icon symbol
get_agent_icon() {
    local agent="$1"
    case "$agent" in
        claude) echo "⚡" ;;
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

# Set an alert for the current window
# Usage: set_window_alert "agent_name" [ring_bell]
# Sets tmux window option and adds to alerts file
set_window_alert() {
    local agent="${1:-claude}"
    local ring_bell="${2:-true}"

    # Ensure alerts directory exists
    local alerts_dir
    alerts_dir="$(dirname "$ALERTS_FILE")"
    if [[ ! -d "$alerts_dir" ]]; then
        mkdir -p "$alerts_dir"
        chmod 700 "$alerts_dir"
    fi

    # Get current tmux window identifier
    local win=""
    if [[ -n "${TMUX_PANE:-}" ]]; then
        win=$(tmux display-message -t "$TMUX_PANE" -p '#S:#W' 2>/dev/null)
    fi
    if [[ -z "$win" && -n "${TMUX:-}" ]]; then
        win=$(tmux display-message -p '#S:#W' 2>/dev/null)
    fi

    # Set the @agent_alert window option
    if [[ -n "$win" ]]; then
        tmux set-option -wt "$win" "@${agent}_alert" 1 2>/dev/null
    elif [[ -n "${TMUX_PANE:-}" ]]; then
        tmux set-option -wt "$TMUX_PANE" "@${agent}_alert" 1 2>/dev/null
    fi

    # Add window to alerts file with agent type if not already present
    # Validate win is in format "session:window" (both non-empty, valid chars)
    if [[ "$win" =~ ^[a-zA-Z0-9._-]+:[a-zA-Z0-9._-]+$ ]]; then
        local entry="${win}:${agent}"
        grep -qxF "$entry" "$ALERTS_FILE" 2>/dev/null || echo "$entry" >> "$ALERTS_FILE"
    fi

    # Ring the terminal bell (only if requested and /dev/tty is available)
    if [[ "$ring_bell" == "true" ]]; then
        {
            if [[ -w /dev/tty ]]; then
                printf '\a' > /dev/tty
            fi
        } 2>/dev/null || true
    fi
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
