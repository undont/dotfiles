#!/usr/bin/env bash
# Agent alert utilities for tmux scripts
# Source this file after common.sh

# Alerts file location
readonly ALERTS_FILE="$HOME/.claude/alerts"

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

    # Unset all agent window options
    local target
    if [[ -n "$window_id" ]]; then
        target="$window_id"
    else
        target="${session}:${window}"
    fi

    tmux set-option -wt "$target" -u @claude_alert 2>/dev/null || true
    tmux set-option -wt "$target" -u @gemini_alert 2>/dev/null || true
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
    for win in $(tmux list-windows -t "$session" -F '#W' 2>/dev/null); do
        tmux set-option -wt "${session}:${win}" -u @claude_alert 2>/dev/null || true
        tmux set-option -wt "${session}:${win}" -u @gemini_alert 2>/dev/null || true
    done
}
