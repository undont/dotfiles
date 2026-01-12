#!/bin/bash
# Move a tmux window to a different session
# Usage: move-window.sh <session:window_index>

SCRIPT_DIR="${BASH_SOURCE%/*}"
source "$SCRIPT_DIR/_lib/common.sh"
source "$SCRIPT_DIR/_lib/alerts.sh"

if [[ -z "$1" ]]; then
    error "No window specified"
    exit 1
fi

SOURCE_WINDOW="$1"
SOURCE_SESSION="${SOURCE_WINDOW%%:*}"
WINDOW_INDEX="${SOURCE_WINDOW##*:}"

# Remove any trailing indicators (⚡, 🤖, etc.) from the window identifier
SOURCE_SESSION=$(echo "$SOURCE_SESSION" | sed 's/[[:space:]].*$//')
WINDOW_INDEX=$(echo "$WINDOW_INDEX" | sed 's/[[:space:]].*$//')

# Get the window name for display purposes
WINDOW_NAME=$(tmux display-message -p -t "${SOURCE_SESSION}:${WINDOW_INDEX}" '#{window_name}' 2>/dev/null)

if [[ -z "$WINDOW_NAME" ]]; then
    error "Window ${SOURCE_WINDOW} not found"
    exit 1
fi

# Get list of sessions excluding the source session
TARGET_SESSION=$(tmux list-sessions -F '#{session_name}' | \
    grep -v "^${SOURCE_SESSION}$" | \
    fzf --reverse --cycle \
        --prompt ': ' \
        --border=rounded \
        --border-label=" Move window '${WINDOW_NAME}' from '${SOURCE_SESSION}' to: " \
        --border-label-pos=top \
        --header='j/k · g/G · / search · q/esc abort' \
        --bind 'j:down,k:up,g:first,G:last,q:abort' \
        --bind 'enter:accept' \
        --bind '/:enable-search+change-prompt(> )' \
        --bind 'esc:abort')

if [[ -z "$TARGET_SESSION" ]]; then
    exit 0  # User cancelled
fi

# Move the window to the target session
tmux move-window -s "${SOURCE_SESSION}:${WINDOW_INDEX}" -t "${TARGET_SESSION}:"

# Update alert tracking if the window had an alert
ALERTS_FILE="${TMUX_TMPDIR:-/tmp}/tmux-$(id -u)/claude-alerts"
if [[ -f "$ALERTS_FILE" ]]; then
    # Find any alerts for this window and update the session name
    # Alert format: SESSION:WINDOW_NAME:AGENT
    grep "^${SOURCE_SESSION}:${WINDOW_NAME}:" "$ALERTS_FILE" 2>/dev/null | while read -r alert_line; do
        agent=$(echo "$alert_line" | cut -d: -f3)
        # Remove old alert
        sed -i '' "/^${SOURCE_SESSION}:${WINDOW_NAME}:${agent}$/d" "$ALERTS_FILE"
        # Add updated alert with new session
        echo "${TARGET_SESSION}:${WINDOW_NAME}:${agent}" >> "$ALERTS_FILE"
    done
fi

success "Moved window '${WINDOW_NAME}' from '${SOURCE_SESSION}' to '${TARGET_SESSION}'"
