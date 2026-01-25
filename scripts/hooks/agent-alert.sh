#!/usr/bin/env bash
# Agent alert hook: Set tmux alert when an agent needs attention
# Usage: agent-alert.sh [agent_name]
# Called by Claude Code PostToolCall hook

AGENT="${1:-claude}"

# Source the alerts library
SCRIPT_DIR="${BASH_SOURCE%/*}"
DOTFILES_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
ALERTS_LIB="$DOTFILES_DIR/tmux/.tmux/scripts/_lib/alerts.sh"

if [[ -f "$ALERTS_LIB" ]]; then
    # shellcheck source=../../tmux/.tmux/scripts/_lib/alerts.sh
    source "$ALERTS_LIB"
    set_window_alert "$AGENT" "true"
fi
