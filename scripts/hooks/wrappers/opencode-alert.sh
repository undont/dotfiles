#!/usr/bin/env bash
# OpenCode alert wrapper
# triggers tmux window alerts when OpenCode completes work

# skip when running as ACP subprocess inside nvim
[[ -n "${NVIM:-}" ]] && exit 0

SCRIPT_DIR="${BASH_SOURCE%/*}/.."
"$SCRIPT_DIR/agent-alert.sh" opencode
