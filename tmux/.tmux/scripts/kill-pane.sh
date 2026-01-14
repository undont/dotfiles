#!/usr/bin/env bash
set -euo pipefail

# Kill current pane with undo capability
# Saves pane state before killing for later restoration

SCRIPT_DIR="${BASH_SOURCE%/*}"
source "$SCRIPT_DIR/_lib/common.sh"
source "$SCRIPT_DIR/_lib/paths.sh"
source "$SCRIPT_DIR/_lib/session.sh"
source "$SCRIPT_DIR/_lib/ui.sh"

require_tmux

# DEBUG LOGGING
LOG_FILE="$HOME/kill-pane-debug.log"
log_debug() {
    echo "[$(date '+%H:%M:%S')] $1" >> "$LOG_FILE"
}

log_debug "Starting kill-pane.sh"

# Get current state
CURRENT_SESSION=$(get_current_session)
log_debug "Current session: $CURRENT_SESSION"
CURRENT_WINDOW=$(get_current_window)
CURRENT_PANE=$(get_current_pane)
PANE_DIR=$(get_pane_directory)
WINDOW_LAYOUT=$(get_window_layout)

# Get undo file paths
UNDO_FILE=$(get_pane_undo_file)
UNDO_STATE=$(get_pane_undo_state)
UNDO_CONTENT=$(get_pane_undo_content)

# Clear previous undo data
cleanup_undo_files "pane"

# Save current state for undo
echo "${CURRENT_SESSION}:${CURRENT_WINDOW}.${CURRENT_PANE}" > "$UNDO_FILE"
chmod 600 "$UNDO_FILE"

# Save pane metadata
{
    echo "dir=$PANE_DIR"
    echo "layout=$WINDOW_LAYOUT"
} > "$UNDO_STATE"
chmod 600 "$UNDO_STATE"

# Capture pane contents
tmux capture-pane -p -S -32768 > "$UNDO_CONTENT" 2>/dev/null || true
chmod 600 "$UNDO_CONTENT"

# If this is the last pane in the last window, use the standardised confirm pattern
IS_LAST_PANE=$(is_last_pane && echo "yes" || echo "no")
IS_LAST_WINDOW=$(is_last_window && echo "yes" || echo "no")
log_debug "Last pane? $IS_LAST_PANE. Last window? $IS_LAST_WINDOW"

if is_last_pane && is_last_window; then
    log_debug "Last pane in last window - using tmux_confirm_last_item"
    PANE_TARGET="${CURRENT_SESSION}:${CURRENT_WINDOW}.${CURRENT_PANE}"
    if tmux_confirm_last_item "pane" "$CURRENT_SESSION" "$PANE_TARGET" ""; then
        log_debug "tmux_confirm_last_item confirmed"
        exit 0
    else
        log_debug "tmux_confirm_last_item cancelled"
        exit 0  # Exit cleanly on cancellation
    fi
fi

# Kill the pane normally
log_debug "Killing pane normally..."
tmux kill-pane -t "${CURRENT_SESSION}:${CURRENT_WINDOW}.${CURRENT_PANE}" >> "$LOG_FILE" 2>&1 || true
log_debug "Kill done."