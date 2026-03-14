#!/usr/bin/env bash
# GitHub Copilot hook script: Clear tmux alert when user sends a message
# Wrapper around agent-alert-clear.sh

# Skip when running as ACP subprocess inside Neovim (e.g. codecompanion.nvim)
[[ -n "${NVIM:-}" ]] && exit 0

SCRIPT_DIR="${BASH_SOURCE%/*}/.."
"$SCRIPT_DIR/agent-alert-clear.sh"
