#!/usr/bin/env bash
# OpenCode alert wrapper
# Triggers tmux window alerts when OpenCode completes work

SCRIPT_DIR="${BASH_SOURCE%/*}/.."
"$SCRIPT_DIR/agent-alert.sh" opencode
