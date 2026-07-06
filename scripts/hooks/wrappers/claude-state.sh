#!/usr/bin/env bash
# Claude Code hook script: record per-pane agent state for the tmux switcher
# wrapper around agent-state.sh (hook JSON passes through on stdin)

SCRIPT_DIR="${BASH_SOURCE%/*}/.."
"$SCRIPT_DIR/agent-state.sh" claude
