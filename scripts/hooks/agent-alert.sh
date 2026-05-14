#!/usr/bin/env bash
# Agent alert hook: Set tmux alert when an agent needs attention
# Usage: agent-alert.sh [agent_name]
# Called from agent hook wrappers when the agent needs attention
# (e.g. Claude Code Stop / PostToolUse, codex agentStop)

[[ -z "$TMUX" ]] && exit 0

AGENT="${1:-claude}"

# Source the alerts library
SCRIPT_DIR="${BASH_SOURCE%/*}"
DOTFILES_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
ALERTS_LIB="$DOTFILES_DIR/tmux/scripts/_lib/alerts.sh"

if [[ -f "$ALERTS_LIB" ]]; then
    # shellcheck source=../../tmux/scripts/_lib/alerts.sh
    source "$ALERTS_LIB"
    set_window_alert "$AGENT" "true"
fi
