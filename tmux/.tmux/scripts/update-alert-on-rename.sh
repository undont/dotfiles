#!/bin/bash
# Update Claude alerts when a window is renamed
# Called by after-rename-window hook

SESSION="$1"
OLD_WINDOW="$2"
NEW_WINDOW="$3"

ALERTS_FILE="$HOME/.claude/alerts"

# If format strings weren't expanded, get the values directly from tmux
if [[ "$SESSION" == '#{session_name}' ]] || [[ -z "$SESSION" ]]; then
    SESSION=$(tmux display-message -p '#S')
    NEW_WINDOW=$(tmux display-message -p '#W')
fi

# Validate session and window names
if [[ ! "$SESSION" =~ ^[a-zA-Z0-9._-]+$ ]] || [[ ! "$NEW_WINDOW" =~ ^[a-zA-Z0-9._-]+$ ]]; then
    exit 1
fi

# Update alerts file if it exists and contains an alert for this window
if [[ -f "$ALERTS_FILE" ]] && [[ -n "$OLD_WINDOW" ]]; then
    OLD_TARGET="${SESSION}:${OLD_WINDOW}"
    NEW_TARGET="${SESSION}:${NEW_WINDOW}"

    # Replace old window name with new window name in alerts file
    if grep -Fxq "$OLD_TARGET" "$ALERTS_FILE" 2>/dev/null; then
        sed "s|^${OLD_TARGET}$|${NEW_TARGET}|" "$ALERTS_FILE" > "${ALERTS_FILE}.tmp" && \
            mv "${ALERTS_FILE}.tmp" "$ALERTS_FILE"
    fi
fi
