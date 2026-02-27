#!/usr/bin/env bash
set -euo pipefail
# Update agent alerts when a window is renamed
# Called by after-rename-window hook

SESSION="$1"
OLD_WINDOW="$2"
NEW_WINDOW="$3"

readonly ALERTS_FILE="${XDG_CONFIG_HOME:-$HOME/.config}/tmux-alerts/alerts"

# If format strings weren't expanded, get the values directly from tmux
if [[ "$SESSION" == '#{session_name}' ]] || [[ -z "$SESSION" ]]; then
    SESSION=$(tmux display-message -p '#S' 2>/dev/null) || exit 1
    NEW_WINDOW=$(tmux display-message -p '#W' 2>/dev/null) || exit 1
fi

# Validate session and window names
if [[ ! "$SESSION" =~ ^[a-zA-Z0-9._-]+$ ]] || [[ ! "$NEW_WINDOW" =~ ^[a-zA-Z0-9._-]+$ ]]; then
    exit 1
fi

# Exit early if no old window name or no alerts file
if [[ -z "$OLD_WINDOW" ]] || [[ ! -f "$ALERTS_FILE" ]]; then
    exit 0
fi

# Exit early if old window name is invalid
if [[ ! "$OLD_WINDOW" =~ ^[a-zA-Z0-9._-]+$ ]]; then
    exit 0
fi

# Check if there are any alerts for this window before attempting update
if ! grep -q "^${SESSION}:${OLD_WINDOW}:" "$ALERTS_FILE" 2>/dev/null; then
    exit 0
fi

# Update alerts file with proper file locking
# Use the same locking pattern as clear_window_alerts in alerts.sh
readonly LOCK_DIR="${ALERTS_FILE}.lock"
lock_acquired=0

# Try to acquire lock (with timeout to prevent deadlock)
for _ in {1..10}; do
    if mkdir "$LOCK_DIR" 2>/dev/null; then
        lock_acquired=1
        break
    fi
    sleep 0.1
done

# If we couldn't acquire lock, exit gracefully (don't block tmux)
if [[ $lock_acquired -eq 0 ]]; then
    exit 0
fi

# Perform the update with error handling
tmp_file="${ALERTS_FILE}.tmp.$$"
update_success=0

if sed "s|^${SESSION}:${OLD_WINDOW}:|${SESSION}:${NEW_WINDOW}:|" "$ALERTS_FILE" > "$tmp_file" 2>/dev/null; then
    if mv "$tmp_file" "$ALERTS_FILE" 2>/dev/null; then
        update_success=1
    fi
fi

# Clean up temp file if update failed
if [[ $update_success -eq 0 ]]; then
    rm -f "$tmp_file"
fi

# Release lock
rmdir "$LOCK_DIR" 2>/dev/null || true

exit 0
