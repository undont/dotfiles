#!/usr/bin/env bash
# Gemini CLI hook script: Clear tmux alert when user sends a message
# Wrapper around agent-alert-clear.sh

SCRIPT_DIR="${BASH_SOURCE%/*}/.."
"$SCRIPT_DIR/agent-alert-clear.sh" gemini
