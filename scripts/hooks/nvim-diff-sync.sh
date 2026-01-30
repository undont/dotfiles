#!/usr/bin/env bash
# Sync Claude Code edits to Neovim with diff tracking
# This is a PostToolUse hook for Edit/Write operations
set -euo pipefail

# Exit silently if NVIM_SOCKET not configured
[[ -z "${NVIM_SOCKET:-}" ]] && exit 0
[[ ! -S "$NVIM_SOCKET" ]] && exit 0

# Read hook data from stdin (Claude Code provides JSON)
hook_data=$(cat)

# Parse file path from Claude Code hook JSON
# Try both file_path (Edit tool) and filePath (Write tool) fields
file_path=$(echo "$hook_data" | jq -r '.tool_input.file_path // .tool_input.filePath // empty' 2>/dev/null) || exit 0
[[ -z "$file_path" ]] && exit 0

# Make path absolute
if [[ ! "$file_path" = /* ]]; then
    file_path="$(pwd)/$file_path"
fi

# Check if file is git-tracked
if git ls-files --error-unmatch "$file_path" &>/dev/null; then
    # Get diff against HEAD
    diff_content=$(git diff HEAD -- "$file_path" 2>/dev/null || echo "")

    # Create JSON payload with file path and diff
    json_payload=$(jq -n \
        --arg path "$file_path" \
        --arg diff "$diff_content" \
        '{path: $path, diff: $diff}')

    # Escape for shell
    escaped_json=$(printf '%s' "$json_payload" | sed "s/'/'\\\\''/g")

    # Send to Neovim plugin via RPC using JSON
    nvim --server "$NVIM_SOCKET" --remote-expr \
        "luaeval('require(\"claude-diff\").notify_edit_json(vim.fn.json_decode([[$escaped_json]]))')" \
        2>/dev/null || true
else
    # Non-git file: just add to buffer list
    nvim --server "$NVIM_SOCKET" --remote-expr \
        "execute('badd ' . fnameescape('$file_path'))" \
        2>/dev/null || true
fi

exit 0
