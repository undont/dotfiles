#!/usr/bin/env bash
set -euo pipefail

# Kill a window with undo capability
# Saves all pane states before killing for later restoration
#
# Usage: kill-window.sh [session:window]
#   If no argument provided, kills the current window

SCRIPT_DIR="${BASH_SOURCE%/*}"
source "$SCRIPT_DIR/_lib/common.sh"
source "$SCRIPT_DIR/_lib/paths.sh"
source "$SCRIPT_DIR/_lib/session.sh"
source "$SCRIPT_DIR/_lib/alerts.sh"

require_tmux

# Parse optional target argument
WINDOW_TARGET="${1:-}"

if [[ -n "$WINDOW_TARGET" ]]; then
    # Validate and parse session:window format
    TARGET_SESSION="${WINDOW_TARGET%%:*}"
    TARGET_WINDOW="${WINDOW_TARGET#*:}"

    # Verify session exists
    tmux has-session -t "$TARGET_SESSION" 2>/dev/null || {
        error "Session '$TARGET_SESSION' does not exist"
        exit 1
    }

    # Verify window exists
    tmux list-windows -t "$TARGET_SESSION" -F '#{window_index}' | grep -q "^${TARGET_WINDOW}$" || {
        error "Window '$TARGET_WINDOW' does not exist in session '$TARGET_SESSION'"
        exit 1
    }

    WINDOW_LAYOUT=$(tmux display-message -t "$WINDOW_TARGET" -p '#{window_layout}')
else
    # Use current window
    TARGET_SESSION=$(get_current_session)
    TARGET_WINDOW=$(get_current_window)
    WINDOW_TARGET="${TARGET_SESSION}:${TARGET_WINDOW}"
    WINDOW_LAYOUT=$(get_window_layout)
fi

CURRENT_SESSION=$(get_current_session)

# Get undo file paths
UNDO_FILE=$(get_window_undo_file)
UNDO_STATE=$(get_window_undo_state)
UNDO_CONTENTS_DIR=$(get_window_undo_contents_dir)

# Clear previous undo data and recreate directory
cleanup_undo_files "window"

# Tab delimiter for state file
d=$'\t'

# Save window target
echo "$WINDOW_TARGET" > "$UNDO_FILE"
chmod 600 "$UNDO_FILE"

# Get window info
WINDOW_NAME=$(tmux display-message -t "$WINDOW_TARGET" -p '#{window_name}')
WINDOW_ACTIVE=$(tmux display-message -t "$WINDOW_TARGET" -p '#{window_active}')
WINDOW_FLAGS=$(tmux display-message -t "$WINDOW_TARGET" -p '#{window_flags}')
AUTO_RENAME=$(tmux show-window-option -t "$WINDOW_TARGET" -v automatic-rename 2>/dev/null || echo "on")

# Write window line
echo "window${d}${TARGET_SESSION}${d}${TARGET_WINDOW}${d}:${WINDOW_NAME}${d}${WINDOW_ACTIVE}${d}${WINDOW_FLAGS}${d}${WINDOW_LAYOUT}${d}${AUTO_RENAME}" > "$UNDO_STATE"
chmod 600 "$UNDO_STATE"

# Get pane info for each pane
while IFS='|' read -r pane_index pane_title pane_dir pane_active pane_cmd; do
    # Escape spaces in path
    escaped_dir="${pane_dir// /\\ }"

    # Write pane line
    echo "pane${d}${TARGET_SESSION}${d}${TARGET_WINDOW}${d}${WINDOW_ACTIVE}${d}${WINDOW_FLAGS}${d}${pane_index}${d}${pane_title}${d}:${escaped_dir}${d}${pane_active}${d}${pane_cmd}${d}:" >> "$UNDO_STATE"

    # Capture pane contents
    tmux capture-pane -t "${WINDOW_TARGET}.${pane_index}" -p -S -32768 \
        > "$UNDO_CONTENTS_DIR/pane-${pane_index}.txt" 2>/dev/null || true
    chmod 600 "$UNDO_CONTENTS_DIR/pane-${pane_index}.txt"
done < <(tmux list-panes -t "$WINDOW_TARGET" -F '#{pane_index}|#{pane_title}|#{pane_current_path}|#{pane_active}|#{pane_current_command}')

# If killing the last window in our current session, switch to another session first.
# This prevents tmux from auto-exiting since killing the last window would kill the session,
# leaving the user disconnected. We only need to switch if we're in the target session.
WINDOW_COUNT=$(get_window_count "$TARGET_SESSION")
if [[ "$TARGET_SESSION" == "$CURRENT_SESSION" && "$WINDOW_COUNT" -eq 1 ]]; then
    switch_to_other_session "$TARGET_SESSION" || true
fi

# Clear any claude alert for this window before killing
clear_window_alert "$TARGET_SESSION" "$WINDOW_NAME"

# Kill the window
tmux kill-window -t "$WINDOW_TARGET"
