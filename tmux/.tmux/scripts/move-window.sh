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
        --header='j/k · g/G · / search · n new · q/esc back' \
        --bind 'j:down,k:up,g:first,G:last,q:abort,esc:abort' \
        --bind 'enter:accept' \
        --bind 'change:transform:[[ \$FZF_PROMPT == \": \" ]] && echo \"clear-query\"' \
        --bind '/:change-prompt(> )+unbind(j,k,g,G,q,esc,n)' \
        --bind 'ctrl-c:clear-query+change-prompt(: )+rebind(j,k,g,G,q,esc,n)' \
        --bind 'n:execute(~/.tmux/scripts/new-session.sh && echo $(tmux display-message -p \"#{session_name}\") > /tmp/tmux-move-target)+accept')

# Check if 'n' was pressed (new session created)
if [[ -z "$TARGET_SESSION" ]] && [[ -f /tmp/tmux-move-target ]]; then
    TARGET_SESSION=$(cat /tmp/tmux-move-target)
    rm -f /tmp/tmux-move-target
fi

if [[ -z "$TARGET_SESSION" ]]; then
    exit 0  # User cancelled
fi

# Move the window to the target session and switch to it
tmux move-window -s "${SOURCE_SESSION}:${WINDOW_INDEX}" -t "${TARGET_SESSION}:" \; \
     switch-client -t "${TARGET_SESSION}"

# Update alert tracking if the window had an alert
if [[ -f "$ALERTS_FILE" ]]; then
    # Find any alerts for this window and update the session name
    # Alert format: SESSION:WINDOW_NAME:AGENT
    grep "^${SOURCE_SESSION}:${WINDOW_NAME}:" "$ALERTS_FILE" 2>/dev/null | while read -r alert_line; do
        agent=$(echo "$alert_line" | cut -d: -f3)
        # Remove old alert and add updated alert with new session
        if grep -qF "${SOURCE_SESSION}:${WINDOW_NAME}:${agent}" "$ALERTS_FILE" 2>/dev/null; then
            # Create temp file without old alert
            grep -vF "${SOURCE_SESSION}:${WINDOW_NAME}:${agent}" "$ALERTS_FILE" > "${ALERTS_FILE}.tmp"
            # Add new alert with updated session
            echo "${TARGET_SESSION}:${WINDOW_NAME}:${agent}" >> "${ALERTS_FILE}.tmp"
            mv "${ALERTS_FILE}.tmp" "$ALERTS_FILE"
        fi
    done
fi

success "Moved window '${WINDOW_NAME}' from '${SOURCE_SESSION}' to '${TARGET_SESSION}'"
