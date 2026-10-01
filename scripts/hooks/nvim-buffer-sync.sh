#!/usr/bin/env bash
# nvim buffer sync hook: add edited files to paired nvim's buffer list
# called by the Claude Code PostToolUse hook for Edit/Write tools, hook JSON on
# stdin. a no-op unless NVIM_SOCKET points at a running nvim's socket

set -euo pipefail

[[ -z "${NVIM_SOCKET:-}" ]] && exit 0
[[ ! -S "$NVIM_SOCKET" ]] && exit 0

file_path=$(jq -r '.tool_input.file_path // empty' 2>/dev/null) || exit 0
[[ -z "$file_path" ]] && exit 0

# badd lists the buffer without loading it, so it shows in neo-tree buffers
nvim --headless --server "$NVIM_SOCKET" --remote-expr "execute('badd ' . fnameescape('$file_path'))" 2>/dev/null || true

exit 0
