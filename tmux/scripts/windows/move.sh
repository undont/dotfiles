#!/bin/bash
# Move a tmux window to a different session
# Usage: move-window.sh <session:window_index>

SCRIPT_DIR="${BASH_SOURCE%/*}"
source "$SCRIPT_DIR/../_lib/common.sh"
source "$SCRIPT_DIR/../_lib/alerts.sh"

# Load current theme colours for fzf
load_fzf_theme

if [[ -z "$1" ]]; then
    error "No window specified"
    exit 1
fi

SOURCE_WINDOW="$1"

# Validate input contains colon separator (session:window format)
if [[ ! "$SOURCE_WINDOW" =~ : ]]; then
    error "Invalid format: expected 'session:window_index' (e.g., 'main:1')"
    exit 1
fi

SOURCE_SESSION="${SOURCE_WINDOW%%:*}"
WINDOW_INDEX="${SOURCE_WINDOW##*:}"

# Remove any trailing indicators (⚡, 🤖, etc.) from the window identifier
SOURCE_SESSION="${SOURCE_SESSION%% *}"
WINDOW_INDEX="${WINDOW_INDEX%% *}"

# Get the window name for display purposes
WINDOW_NAME=$(tmux display-message -p -t "${SOURCE_SESSION}:${WINDOW_INDEX}" '#{window_name}' 2>/dev/null)

if [[ -z "$WINDOW_NAME" ]]; then
    error "Window ${SOURCE_WINDOW} not found"
    exit 1
fi

# Get list of sessions excluding the source session
TARGET_SESSION=$(tmux list-sessions -F '#{session_name}' | \
    grep -v "^${SOURCE_SESSION}$" | \
    fzf --height=100% --layout=reverse --cycle --disabled \
        --prompt ': ' \
        --border=rounded \
        --border-label=" Move window '${WINDOW_NAME}' from '${SOURCE_SESSION}' to: " \
        --border-label-pos=top \
        --no-info \
        --pointer='▌' \
        --bind 'j:down,k:up,g:first,G:last,q:abort,space:accept' \
        --bind 'enter:accept' \
        --bind 'change:transform:[[ $FZF_PROMPT == ": " ]] && echo "clear-query"' \
        --bind '/:enable-search+change-prompt(> )+unbind(j,k,g,G,q,space)' \
        --bind 'esc:transform:[[ $FZF_PROMPT == "> " ]] && echo "disable-search+clear-query+change-prompt(: )+rebind(j,k,g,G,q,space)" || echo "abort"')

if [[ -z "$TARGET_SESSION" ]]; then
    exit 0  # User cancelled
fi

# Move the window to the target session
tmux move-window -s "${SOURCE_SESSION}:${WINDOW_INDEX}" -t "${TARGET_SESSION}:"

# Update alert tracking if the window had an alert
# Find agents that have alerts for this window and update the session name
if [[ -f "$ALERTS_FILE" ]]; then
    # Get list of agents with alerts for this window
    agents=()
    while IFS=: read -r sess win agent; do
        if [[ "$sess" == "$SOURCE_SESSION" && "$win" == "$WINDOW_NAME" ]]; then
            agents+=("$agent")
        fi
    done < "$ALERTS_FILE"

    # If we found any alerts, update them to the new session
    if [[ ${#agents[@]} -gt 0 ]]; then
        # Clear old alerts from source session (file only)
        # Note: Intentionally NOT passing WINDOW_ID - the tmux window options
        # move with the window and should stay set. We only need to update
        # the alerts file to reflect the new session name.
        clear_window_alerts "$SOURCE_SESSION" "$WINDOW_NAME"

        # Re-add alerts with new session name (file only, options already set on window)
        for agent in "${agents[@]}"; do
            echo "${TARGET_SESSION}:${WINDOW_NAME}:${agent}" >> "$ALERTS_FILE"
        done
    fi
fi

success "Moved window '${WINDOW_NAME}' from '${SOURCE_SESSION}' to '${TARGET_SESSION}'"
