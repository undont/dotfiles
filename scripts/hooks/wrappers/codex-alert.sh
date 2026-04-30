#!/usr/bin/env bash
# Codex alert wrapper
# Triggers tmux window alerts when Codex completes work

# Skip when running as ACP subprocess inside Neovim (e.g. codecompanion.nvim)
[[ -n "${NVIM:-}" ]] && exit 0

SCRIPT_DIR="${BASH_SOURCE%/*}/.."
"$SCRIPT_DIR/agent-alert.sh" codex