#!/usr/bin/env bash
set -euo pipefail

# rename current tmux window via fzf prompt

SCRIPT_DIR="${BASH_SOURCE%/*}"
source "$SCRIPT_DIR/../_lib/common.sh"
source "$SCRIPT_DIR/../_lib/session.sh"
source "$SCRIPT_DIR/../_lib/alerts.sh"

require_tmux

# load current theme colours for fzf
load_fzf_theme

# accept optional target window (session:index) or default to current
TARGET_WINDOW="${1:-}"
if [[ -n "$TARGET_WINDOW" ]]; then
    CURRENT_NAME=$(tmux display-message -t "$TARGET_WINDOW" -p '#{window_name}')
    SESSION_NAME=$(tmux display-message -t "$TARGET_WINDOW" -p '#{session_name}')
else
    CURRENT_NAME=$(get_window_name)
    SESSION_NAME=$(get_current_session)
fi

# prompt for new name with current name as default
newname=$(printf '' | fzf \
    --print-query \
    --query="$CURRENT_NAME" \
    --prompt='Rename window: ' \
    --height=5 \
    --layout=reverse \
    --border=rounded \
    --border-label=' ⏎ rename · esc cancel ' \
    --border-label-pos=bottom \
    --no-info \
    --no-separator \
    --pointer=' ' \
    --bind 'enter:print-query' \
    --bind 'esc:abort' \
    2>/dev/null | head -1) || true

# handle empty input (user cancelled)
if [[ -z "$newname" ]]; then
    exit 0
fi

# sanitise window name (convert spaces and invalid chars to dashes, then trim trailing dashes)
newname=$(echo "$newname" | tr -c '[:alnum:]_.-' '-' | sed 's/-*$//')

# no change needed
if [[ "$newname" == "$CURRENT_NAME" ]]; then
    exit 0
fi

# update alerts file BEFORE the rename; tmux rename-window triggers the
# after-rename-window hook asynchronously (alerts/cleanup.sh), which would
# delete entries for the old name if the file hasn't been updated yet
update_window_name_in_alerts "$SESSION_NAME" "$CURRENT_NAME" "$newname"

# rename the window and disable automatic-rename to preserve the name
if [[ -n "$TARGET_WINDOW" ]]; then
    if ! tmux rename-window -t "$TARGET_WINDOW" "$newname" 2>/dev/null; then
        # revert alert file update on failure
        update_window_name_in_alerts "$SESSION_NAME" "$newname" "$CURRENT_NAME"
        show_error "Failed to rename window to '$newname'"
        exit 1
    fi
    tmux set-window-option -t "$TARGET_WINDOW" automatic-rename off
else
    if ! tmux rename-window "$newname" 2>/dev/null; then
        # revert alert file update on failure
        update_window_name_in_alerts "$SESSION_NAME" "$newname" "$CURRENT_NAME"
        show_error "Failed to rename window to '$newname'"
        exit 1
    fi
    tmux set-window-option automatic-rename off
fi
