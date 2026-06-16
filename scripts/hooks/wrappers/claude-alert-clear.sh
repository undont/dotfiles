#!/usr/bin/env bash
# Claude Code hook script: clear tmux alert when user sends a message
# wrapper around agent-alert-clear.sh

SCRIPT_DIR="${BASH_SOURCE%/*}/.."
"$SCRIPT_DIR/agent-alert-clear.sh" claude
