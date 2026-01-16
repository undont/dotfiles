#!/bin/bash
# OpenCode hook script: Set tmux alert when OpenCode needs attention
# Wrapper around agent-alert.sh

SCRIPT_DIR="${BASH_SOURCE%/*}/.."
"$SCRIPT_DIR/agent-alert.sh" opencode