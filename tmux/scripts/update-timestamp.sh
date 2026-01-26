#!/usr/bin/env bash
# Update the @last-viewed timestamp for the current window
# Also clears any agent alert as a safety net

SCRIPT_DIR="${BASH_SOURCE%/*}"
source "$SCRIPT_DIR/_lib/alerts.sh"

TIMESTAMP=$(date +%s)
WINDOW_ID="$1"

# Validate window ID (should be like @123 or session:window format)
if [[ -z "$WINDOW_ID" ]] || [[ ! "$WINDOW_ID" =~ ^[@a-zA-Z0-9._:-]+$ ]]; then
    exit 0
fi

# Acquire lock to prevent concurrent runs from racing (portable mkdir-based lock)
LOCK_DIR="$HOME/.claude/update-timestamp.lock"
PARENT_DIR="$(dirname "$LOCK_DIR")"
[[ ! -d "$PARENT_DIR" ]] && mkdir -p "$PARENT_DIR" && chmod 700 "$PARENT_DIR"

# Try to acquire lock (mkdir is atomic)
if ! mkdir "$LOCK_DIR" 2>/dev/null; then
    # Lock held by another process, skip to avoid racing
    exit 0
fi

# Ensure lock is released on exit
trap 'rmdir "$LOCK_DIR" 2>/dev/null || true' EXIT INT TERM

# Update timestamp
tmux set-option -wt "$WINDOW_ID" @last-viewed "$TIMESTAMP" 2>/dev/null || true

# Clear any agent alerts for this window (safety net)
SESSION=$(tmux display-message -t "$WINDOW_ID" -p '#S' 2>/dev/null)
WINDOW=$(tmux display-message -t "$WINDOW_ID" -p '#W' 2>/dev/null)

# Validate session/window names before using
if [[ -n "$SESSION" && -n "$WINDOW" ]] && \
   [[ "$SESSION" =~ ^[a-zA-Z0-9._-]+$ ]] && \
   [[ "$WINDOW" =~ ^[a-zA-Z0-9._-]+$ ]]; then
    clear_window_alerts "$SESSION" "$WINDOW" "$WINDOW_ID"
fi
