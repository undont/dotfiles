#!/bin/bash
# Gemini hook script: Set tmux alert when Gemini needs attention
# Wrapper around agent-alert.sh

SCRIPT_DIR="${BASH_SOURCE%/*}"
"$SCRIPT_DIR/agent-alert.sh" gemini
