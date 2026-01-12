#!/bin/bash
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
WIN=$(tmux display-message -t "$TMUX_PANE" -p '#S:#W')

# Set the @agent_alert window option
tmux set-option -wt "$TMUX_PANE" "@${AGENT}_alert" 1 2>/dev/null

# Add window to alerts file with agent type if not already present
ENTRY="${WIN}:${AGENT}"
grep -qxF "$ENTRY" "$ALERTS_FILE" 2>/dev/null || echo "$ENTRY" >> "$ALERTS_FILE"

# Ring the terminal bell (only if /dev/tty is available)
{
    if [[ -w /dev/tty ]]; then
        printf '\a' > /dev/tty
    fi
} 2>/dev/null || true
