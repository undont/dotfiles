#!/usr/bin/env bash
# Create git checkpoint before Claude Code edits
# This is a PreToolUse hook for Edit/Write operations
set -euo pipefail

# Exit silently if NVIM_SOCKET not configured
[[ -z "${NVIM_SOCKET:-}" ]] && exit 0
[[ ! -S "$NVIM_SOCKET" ]] && exit 0

# Check if we're in a git repository
if ! git rev-parse --is-inside-work-tree &>/dev/null; then
    # Not a git repo, exit cleanly
    exit 0
fi

# Check if checkpoint already exists (for batch edits)
# Use RPC to check plugin state
checkpoint_exists=$(nvim --server "$NVIM_SOCKET" --remote-expr \
    "luaeval('require(\"claude-diff\").has_checkpoint()')" 2>/dev/null || echo "false")

if [[ "$checkpoint_exists" == "true" || "$checkpoint_exists" == "1" ]]; then
    # Checkpoint already exists (batch edit in progress)
    # Skip creating new checkpoint, exit cleanly
    exit 0
fi

# Create stash with timestamp message
timestamp=$(date +%s)
if git stash push -u -m "claude-code-checkpoint-$timestamp" &>/dev/null; then
    # Notify Neovim that checkpoint is ready
    nvim --server "$NVIM_SOCKET" --remote-expr \
        "luaeval('require(\"claude-diff\").checkpoint_created()')" \
        2>/dev/null || true
fi

exit 0
