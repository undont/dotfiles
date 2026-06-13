#!/usr/bin/env bash
# Claude Code hook script: set tmux alert when Claude needs attention
# wrapper around agent-alert.sh

SCRIPT_DIR="${BASH_SOURCE%/*}/.."
"$SCRIPT_DIR/agent-alert.sh" claude
