#!/usr/bin/env bash
set -euo pipefail

# Rename current tmux window via fzf prompt

SCRIPT_DIR="${BASH_SOURCE%/*}"
source "$SCRIPT_DIR/_lib/common.sh"
source "$SCRIPT_DIR/_lib/session.sh"

require_tmux

CURRENT_SESSION=$(get_current_session)
CURRENT_NAME=$(get_window_name)

# Prompt for new name with current name as default
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

# Handle empty input (user cancelled)
if [[ -z "$newname" ]]; then
    exit 0
fi

# Sanitise window name (convert spaces and invalid chars to dashes, then trim trailing dashes)
newname=$(echo "$newname" | tr -c '[:alnum:]_.-' '-' | sed 's/-*$//')

# No change needed
if [[ "$newname" == "$CURRENT_NAME" ]]; then
    exit 0
fi

# Clear any existing alert for the old window name before renaming
ALERTS_FILE="$HOME/.claude/alerts"
if [[ -f "$ALERTS_FILE" ]]; then
    grep -vxF "${CURRENT_SESSION}:${CURRENT_NAME}" "$ALERTS_FILE" > "${ALERTS_FILE}.tmp" 2>/dev/null && \
        mv "${ALERTS_FILE}.tmp" "$ALERTS_FILE" || rm -f "${ALERTS_FILE}.tmp"
fi
tmux set-option -wt "${CURRENT_SESSION}:${CURRENT_NAME}" -u @agent_alert 2>/dev/null || true

# Rename the window and disable automatic-rename to preserve the name
if ! tmux rename-window "$newname" 2>/dev/null; then
    show_error "Failed to rename window to '$newname'"
    exit 1
fi

# Disable automatic-rename to preserve the custom name
tmux set-window-option automatic-rename off
