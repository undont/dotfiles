#!/usr/bin/env bash
# Claude Code hook script: Set tmux alert when Claude needs attention
# Wrapper around agent-alert.sh

SCRIPT_DIR="${BASH_SOURCE%/*}/.."
"$SCRIPT_DIR/agent-alert.sh" claude
