#!/usr/bin/env bash
# Claude alert utilities for tmux scripts
# Source this file after common.sh

# Alerts file location
readonly CLAUDE_ALERTS_FILE="$HOME/.claude/alerts"

# Clear claude alert for a specific window
# Usage: clear_window_alert "session" "window" ["window_id"]
clear_window_alert() {
    local session="$1"
    local window="$2"
    local window_id="${3:-}"

    # Remove from alerts file
    # grep -v exit codes: 0=lines remain, 1=no lines (all filtered), 2+=error
    # Use || true to prevent errexit from triggering on exit code 1
    if [[ -f "$CLAUDE_ALERTS_FILE" ]]; then
        local grep_exit=0
        grep -v "^${session}:${window}$" "$CLAUDE_ALERTS_FILE" > "${CLAUDE_ALERTS_FILE}.tmp" 2>/dev/null || grep_exit=$?
        if [[ $grep_exit -le 1 ]]; then
            mv "${CLAUDE_ALERTS_FILE}.tmp" "$CLAUDE_ALERTS_FILE"
        else
            rm -f "${CLAUDE_ALERTS_FILE}.tmp"
        fi
    fi

    # Unset window option
    if [[ -n "$window_id" ]]; then
        tmux set-option -wt "$window_id" -u @claude_alert 2>/dev/null || true
    else
        tmux set-option -wt "${session}:${window}" -u @claude_alert 2>/dev/null || true
    fi
}

# Clear all claude alerts for a session
# Usage: clear_session_alerts "session"
clear_session_alerts() {
    local session="$1"

    # Remove all entries for this session from alerts file
    # grep -v exit codes: 0=lines remain, 1=no lines (all filtered), 2+=error
    # Use || true to prevent errexit from triggering on exit code 1
    if [[ -f "$CLAUDE_ALERTS_FILE" ]]; then
        local grep_exit=0
        grep -vF "${session}:" "$CLAUDE_ALERTS_FILE" > "${CLAUDE_ALERTS_FILE}.tmp" 2>/dev/null || grep_exit=$?
        if [[ $grep_exit -le 1 ]]; then
            mv "${CLAUDE_ALERTS_FILE}.tmp" "$CLAUDE_ALERTS_FILE"
        else
            rm -f "${CLAUDE_ALERTS_FILE}.tmp"
        fi
    fi

    # Unset @claude_alert for all windows in session
    local win
    for win in $(tmux list-windows -t "$session" -F '#W' 2>/dev/null); do
        tmux set-option -wt "${session}:${win}" -u @claude_alert 2>/dev/null || true
    done
}
