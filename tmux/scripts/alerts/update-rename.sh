#!/usr/bin/env bash
set -euo pipefail
# Update agent alerts when a window is renamed
# Called by after-rename-window hook

SESSION="$1"
OLD_WINDOW="$2"
NEW_WINDOW="$3"

readonly ALERTS_FILE="${XDG_CONFIG_HOME:-$HOME/.config}/tmux-alerts/alerts"

# Source the alerts library for lock helpers
SCRIPT_DIR="${BASH_SOURCE%/*}"
# shellcheck source=../_lib/alerts.sh
source "$SCRIPT_DIR/../_lib/alerts.sh"

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
if ! grep -qF "${SESSION}:${OLD_WINDOW}:" "$ALERTS_FILE" 2>/dev/null; then
    exit 0
fi

# Update alerts file with file locking
if ! _acquire_alerts_lock; then
    exit 0
fi

# Perform the update with error handling
tmp_file=$(mktemp "${ALERTS_FILE}.tmp.XXXXXX")
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

_release_alerts_lock

exit 0
