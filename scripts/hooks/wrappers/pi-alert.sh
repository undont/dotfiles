#!/usr/bin/env bash
# pi alert wrapper: set tmux alert when pi finishes or waits on a prompt
# called by the agent-alerts extension in ~/.ai/pi/extensions

SCRIPT_DIR="${BASH_SOURCE%/*}/.."
"$SCRIPT_DIR/agent-alert.sh" pi
