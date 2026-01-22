#!/usr/bin/env bash
set -euo pipefail

# Rename current tmux session via fzf prompt

SCRIPT_DIR="${BASH_SOURCE%/*}"
source "$SCRIPT_DIR/_lib/common.sh"
source "$SCRIPT_DIR/_lib/session.sh"

require_tmux

# Load current theme colours for fzf
load_fzf_theme

current_session="${1:-$(get_current_session)}"

# Prompt for new name with current name as default
newname=$(printf '' | fzf \
    --print-query \
    --query="$current_session" \
    --prompt='Rename session: ' \
    --height=100% \
    --layout=reverse \
    --border=rounded \
    --border-label=' ⏎ rename · esc cancel ' \
    --border-label-pos=bottom \
    --no-info \
    --pointer=' ' \
    --bind 'enter:print-query' \
    --bind 'esc:abort' \
    2>/dev/null | head -1) || exit 130

# Handle empty input (user cancelled)
if [[ -z "$newname" ]]; then
    exit 130
fi

# Sanitise session name (convert spaces and invalid chars to dashes)
newname=$(sanitise_session_name "$newname")

# No change needed
if [[ "$newname" == "$current_session" ]]; then
    exit 130
fi

# Validate session name
if ! validate_session_name "$newname"; then
    # validate_session_name already outputs error message via error()
    exit 1
fi

# Check if target name already exists
if session_exists "$newname"; then
    show_error "Session '$newname' already exists"
    exit 1
fi

# Clear any existing alerts for the old session name before renaming
# Use awk for safe prefix matching (handles regex metacharacters in session name)
ALERTS_FILE="$HOME/.claude/alerts"
if [[ -f "$ALERTS_FILE" ]]; then
    awk -v session="$current_session" 'index($0, session ":") != 1' "$ALERTS_FILE" > "${ALERTS_FILE}.tmp" 2>/dev/null && \
        mv "${ALERTS_FILE}.tmp" "$ALERTS_FILE" || rm -f "${ALERTS_FILE}.tmp"
fi
# Clear @agent_alert options for all windows in the session
for win in $(tmux list-windows -t "$current_session" -F '#W' 2>/dev/null); do
    tmux set-option -wt "${current_session}:${win}" -u @agent_alert 2>/dev/null || true
done

# Rename the session
if ! tmux rename-session -t "$current_session" "$newname" 2>/dev/null; then
    show_error "Failed to rename '$current_session' to '$newname'"
    exit 1
fi
