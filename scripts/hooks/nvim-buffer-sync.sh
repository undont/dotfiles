#!/usr/bin/env bash
# Nvim buffer sync hook: Add edited files to paired nvim's buffer list
# Usage: Reads Claude Code hook JSON from stdin
# Called by Claude Code PostToolUse hook for Edit/Write tools
#
# Requires NVIM_SOCKET env var to be set (via nvim-pair function)

set -euo pipefail

# Skip if not configured
[[ -z "${NVIM_SOCKET:-}" ]] && exit 0
[[ ! -S "$NVIM_SOCKET" ]] && exit 0

# Parse file path from Claude Code hook JSON
file_path=$(jq -r '.tool_input.file_path // empty' 2>/dev/null) || exit 0
[[ -z "$file_path" ]] && exit 0

# Add to nvim buffer list and load it (so it shows in neo-tree buffers)
# Use fnameescape for proper path handling (handles spaces/special chars)
nvim --headless --server "$NVIM_SOCKET" --remote-expr "execute('badd ' . fnameescape('$file_path'))" 2>/dev/null || true

exit 0
