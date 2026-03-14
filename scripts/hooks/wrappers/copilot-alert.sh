#!/usr/bin/env bash
# GitHub Copilot hook script: Set tmux alert when Copilot needs attention
# Wrapper around agent-alert.sh

# Skip when running as ACP subprocess inside Neovim (e.g. codecompanion.nvim)
[[ -n "${NVIM:-}" ]] && exit 0

SCRIPT_DIR="${BASH_SOURCE%/*}/.."
"$SCRIPT_DIR/agent-alert.sh" copilot
