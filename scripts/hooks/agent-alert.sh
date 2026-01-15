#!/usr/bin/env bash
# Agent alert hook script: Set tmux alert when an agent needs attention
# Usage: agent-alert.sh <agent_name>

AGENT="${1:-claude}"
ALERTS_DIR="$HOME/.claude"
ALERTS_FILE="$ALERTS_DIR/alerts"

# Ensure directory exists
if [[ ! -d "$ALERTS_DIR" ]]; then
    mkdir -p "$ALERTS_DIR"
    chmod 700 "$ALERTS_DIR"
fi

# Get current tmux window identifier
# Try $TMUX_PANE first, fall back to getting active window from current session
if [[ -n "$TMUX_PANE" ]]; then
    WIN=$(tmux display-message -t "$TMUX_PANE" -p '#S:#W' 2>/dev/null)
fi
# If we still don't have it, try to get the current session/window
if [[ -z "$WIN" && -n "$TMUX" ]]; then
    WIN=$(tmux display-message -p '#S:#W' 2>/dev/null)
fi

# Set the @agent_alert window option (use $WIN if available, fall back to $TMUX_PANE)
if [[ -n "$WIN" ]]; then
    tmux set-option -wt "$WIN" "@${AGENT}_alert" 1 2>/dev/null
elif [[ -n "$TMUX_PANE" ]]; then
    tmux set-option -wt "$TMUX_PANE" "@${AGENT}_alert" 1 2>/dev/null
fi

# Add window to alerts file with agent type if not already present
ENTRY="${WIN}:${AGENT}"
grep -qxF "$ENTRY" "$ALERTS_FILE" 2>/dev/null || echo "$ENTRY" >> "$ALERTS_FILE"

# Ring the terminal bell (only if /dev/tty is available)
{
    if [[ -w /dev/tty ]]; then
        printf '\a' > /dev/tty
    fi
} 2>/dev/null || true
