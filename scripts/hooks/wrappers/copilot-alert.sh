#!/usr/bin/env bash
# GitHub Copilot hook script: set tmux alert when Copilot needs attention
# wrapper around agent-alert.sh

# skip when running as ACP subprocess inside nvim (e.g. codecompanion.nvim)
[[ -n "${NVIM:-}" ]] && exit 0

SCRIPT_DIR="${BASH_SOURCE%/*}/.."
"$SCRIPT_DIR/agent-alert.sh" copilot
