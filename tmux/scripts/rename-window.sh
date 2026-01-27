#!/usr/bin/env bash
set -euo pipefail

# Rename current tmux window via fzf prompt

SCRIPT_DIR="${BASH_SOURCE%/*}"
source "$SCRIPT_DIR/_lib/common.sh"
source "$SCRIPT_DIR/_lib/session.sh"
source "$SCRIPT_DIR/_lib/alerts.sh"

require_tmux

# Load current theme colours for fzf
load_fzf_theme

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

# Rename the window and disable automatic-rename to preserve the name
# Note: Alert updates are handled by the after-rename-window hook
if ! tmux rename-window "$newname" 2>/dev/null; then
    show_error "Failed to rename window to '$newname'"
    exit 1
fi

# Disable automatic-rename to preserve the custom name
tmux set-window-option automatic-rename off
