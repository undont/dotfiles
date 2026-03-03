#!/usr/bin/env bash
# OpenCode alert wrapper
# Triggers tmux window alerts when OpenCode completes work

# Skip when running as ACP subprocess inside Neovim (e.g. codecompanion.nvim)
[[ -n "${NVIM:-}" ]] && exit 0

SCRIPT_DIR="${BASH_SOURCE%/*}/.."
"$SCRIPT_DIR/agent-alert.sh" opencode
