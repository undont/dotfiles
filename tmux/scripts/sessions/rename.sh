#!/usr/bin/env bash
set -euo pipefail

# Rename current tmux session via fzf prompt

SCRIPT_DIR="${BASH_SOURCE%/*}"
source "$SCRIPT_DIR/../_lib/common.sh"
source "$SCRIPT_DIR/../_lib/session.sh"
source "$SCRIPT_DIR/../_lib/alerts.sh"

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

# Update alerts file BEFORE the rename — tmux rename-session triggers the
# session-renamed hook asynchronously (cleanup.sh), which would delete entries
# for the old name if the file hasn't been updated yet.
update_session_name_in_alerts "$current_session" "$newname"

# Rename the session
if ! tmux rename-session -t "$current_session" "$newname" 2>/dev/null; then
    # Revert alert file update on failure
    update_session_name_in_alerts "$newname" "$current_session"
    show_error "Failed to rename '$current_session' to '$newname'"
    exit 1
fi

# Output the new session name so the calling script can switch to it
echo "$newname"
