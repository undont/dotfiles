#!/usr/bin/env bash
# nvim buffer sync hook: add edited files to paired nvim's buffer list
# reads Claude Code hook JSON from stdin
# called by Claude Code PostToolUse hook for Edit/Write tools
#
# requires NVIM_SOCKET env var to be set (via nvim-pair function)

set -euo pipefail

# skip if not configured
[[ -z "${NVIM_SOCKET:-}" ]] && exit 0
[[ ! -S "$NVIM_SOCKET" ]] && exit 0

# parse file path from Claude Code hook JSON
file_path=$(jq -r '.tool_input.file_path // empty' 2>/dev/null) || exit 0
[[ -z "$file_path" ]] && exit 0

# add to nvim buffer list and load it (so it shows in neo-tree buffers)
# use fnameescape for proper path handling (handles spaces/special chars)
nvim --headless --server "$NVIM_SOCKET" --remote-expr "execute('badd ' . fnameescape('$file_path'))" 2>/dev/null || true

exit 0
