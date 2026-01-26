#!/usr/bin/env bash
# Dotfiles sync status indicator for tmux status bar
# Shows icon when local dotfiles are behind/ahead of origin
#
# Output:
#   ↓  - behind origin (updates available)
#   ↑  - ahead of origin (unpushed commits)
#   ↕  - diverged (both ahead and behind)
#   (empty) - up-to-date or error (silent fail)
#
# Caches git fetch to avoid hammering remote (default: 5 min)

set -euo pipefail

DOTFILES_DIR="${DOTFILES_DIR:-$HOME/dotfiles}"
CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/dotfiles"
CACHE_FILE="$CACHE_DIR/sync-status"
FETCH_CACHE_FILE="$CACHE_DIR/last-fetch"
CACHE_TTL_SECONDS="${DOTFILES_SYNC_CACHE_TTL:-300}"  # 5 minutes default

# Ensure cache directory exists
mkdir -p "$CACHE_DIR"

# Silent exit helper (no output on failure)
bail() {
    exit 0
}

# Check if we're in a git repo
cd "$DOTFILES_DIR" 2>/dev/null || bail
git rev-parse --git-dir &>/dev/null || bail

# Get the default remote branch (origin/main, origin/master, etc.)
get_remote_branch() {
    local ref
    # Try to get the default branch from origin
    ref=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null) || {
        # Fallback: try to detect from remote
        ref=$(git remote show origin 2>/dev/null | grep 'HEAD branch' | awk '{print $NF}')
        if [[ -n "$ref" ]]; then
            echo "origin/$ref"
            return
        fi
        # Last resort: try common names
        if git rev-parse --verify origin/main &>/dev/null; then
            echo "origin/main"
        elif git rev-parse --verify origin/master &>/dev/null; then
            echo "origin/master"
        else
            return 1
        fi
        return
    }
    # Convert refs/remotes/origin/main -> origin/main
    echo "${ref#refs/remotes/}"
}

# Fetch from origin if cache is stale
maybe_fetch() {
    local now last_fetch age

    now=$(date +%s)

    if [[ -f "$FETCH_CACHE_FILE" ]]; then
        last_fetch=$(cat "$FETCH_CACHE_FILE" 2>/dev/null || echo 0)
        age=$((now - last_fetch))

        if [[ $age -lt $CACHE_TTL_SECONDS ]]; then
            return 0  # Cache still fresh
        fi
    fi

    # Fetch in background to avoid blocking tmux
    git fetch origin --quiet 2>/dev/null &
    echo "$now" > "$FETCH_CACHE_FILE"
}

# Main logic
main() {
    local remote_branch behind ahead output=""

    remote_branch=$(get_remote_branch) || bail

    # Trigger background fetch if needed
    maybe_fetch

    # Count commits behind and ahead
    behind=$(git rev-list HEAD.."$remote_branch" --count 2>/dev/null) || behind=0
    ahead=$(git rev-list "$remote_branch"..HEAD --count 2>/dev/null) || ahead=0

    # Build output
    if [[ $behind -gt 0 && $ahead -gt 0 ]]; then
        output="↕ "
    elif [[ $behind -gt 0 ]]; then
        output="↓ "
    elif [[ $ahead -gt 0 ]]; then
        output="↑ "
    fi

    # Cache the result
    echo "$output" > "$CACHE_FILE"

    # Output for tmux
    printf "%s" "$output"
}

main
