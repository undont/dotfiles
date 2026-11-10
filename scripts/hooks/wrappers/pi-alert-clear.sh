#!/usr/bin/env bash
# pi hook script: clear tmux alert when a run starts or the session ends
# wrapper around agent-alert-clear.sh

SCRIPT_DIR="${BASH_SOURCE%/*}/.."
"$SCRIPT_DIR/agent-alert-clear.sh" pi
