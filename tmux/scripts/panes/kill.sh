#!/usr/bin/env bash
set -euo pipefail

# Kill current pane with undo capability
# Saves pane state before killing for later restoration

# Parse arguments
PANE_TARGET=""
FORCE_KILL=false

for arg in "$@"; do
    case "$arg" in
        --force)
            FORCE_KILL=true
            ;;
        *)
            PANE_TARGET="$arg"
            ;;
    esac
done

SCRIPT_DIR="${BASH_SOURCE%/*}"
source "$SCRIPT_DIR/../_lib/common.sh"
source "$SCRIPT_DIR/../_lib/paths.sh"
source "$SCRIPT_DIR/../_lib/session.sh"
source "$SCRIPT_DIR/../_lib/ui.sh"

require_tmux

# Load current theme colours for fzf
load_fzf_theme

# DEBUG LOGGING
LOG_FILE="$HOME/kill-pane-debug.log"
log_debug() {
    echo "[$(date '+%H:%M:%S')] $1" >> "$LOG_FILE"
}

log_debug "Starting kill-pane.sh with target: ${PANE_TARGET:-none}"

# Get current state
if [[ -n "$PANE_TARGET" ]]; then
    # Target specified - parse session:window.pane format
    CURRENT_SESSION="${PANE_TARGET%%:*}"
    REST="${PANE_TARGET#*:}"
    CURRENT_WINDOW="${REST%%.*}"
    CURRENT_PANE="${REST#*.}"

    # Verify the target exists
    if ! tmux list-panes -t "${CURRENT_SESSION}:${CURRENT_WINDOW}" 2>/dev/null | grep -q "^${CURRENT_PANE}:"; then
        log_debug "ERROR: Pane $PANE_TARGET does not exist"
        exit 1
    fi

    PANE_DIR=$(tmux display-message -t "$PANE_TARGET" -p '#{pane_current_path}')
    WINDOW_LAYOUT=$(tmux display-message -t "$PANE_TARGET" -p '#{window_layout}')
    log_debug "Using specified target: $PANE_TARGET"
else
    # No target - use current pane
    CURRENT_SESSION=$(get_current_session)
    CURRENT_WINDOW=$(get_current_window)
    CURRENT_PANE=$(get_current_pane)
    PANE_TARGET="${CURRENT_SESSION}:${CURRENT_WINDOW}.${CURRENT_PANE}"
    PANE_DIR=$(get_pane_directory)
    WINDOW_LAYOUT=$(get_window_layout)
    log_debug "Using current pane"
fi

log_debug "Session: $CURRENT_SESSION, Window: $CURRENT_WINDOW, Pane: $CURRENT_PANE"

# Check if this is the last pane/window to customize the message
PANE_COUNT=$(tmux list-panes -t "${CURRENT_SESSION}:${CURRENT_WINDOW}" 2>/dev/null | wc -l | tr -d ' ')
WINDOW_COUNT=$(tmux list-windows -t "$CURRENT_SESSION" 2>/dev/null | wc -l | tr -d ' ')
IS_LAST_PANE=$([[ "$PANE_COUNT" -eq 1 ]] && echo "yes" || echo "no")
IS_LAST_WINDOW=$([[ "$WINDOW_COUNT" -eq 1 ]] && echo "yes" || echo "no")
log_debug "Last pane? $IS_LAST_PANE (count: $PANE_COUNT). Last window? $IS_LAST_WINDOW (count: $WINDOW_COUNT). Force? $FORCE_KILL"

# Show confirmation unless --force flag is set
if ! $FORCE_KILL; then
    # Build context-aware message
    if [[ "$IS_LAST_PANE" == "yes" && "$IS_LAST_WINDOW" == "yes" ]]; then
        OTHER_SESSION=$(find_other_session "$CURRENT_SESSION")
        if [[ -n "$OTHER_SESSION" ]]; then
            MESSAGE="Last pane in '${CURRENT_SESSION}'\nSwitch to '${OTHER_SESSION}' and kill?"
        else
            MESSAGE="Last pane in '${CURRENT_SESSION}'\nThis will end the session. Kill?"
        fi
    else
        MESSAGE="Kill this pane?"
    fi

    log_debug "Showing confirmation: $MESSAGE"
    if ! show_visual_confirm "Kill Pane" "$MESSAGE"; then
        log_debug "User cancelled"
        exit 0
    fi
    log_debug "User confirmed"
fi

# User confirmed - save undo state
log_debug "Saving undo state..."
UNDO_FILE=$(get_pane_undo_file)
UNDO_STATE=$(get_pane_undo_state)
UNDO_CONTENT=$(get_pane_undo_content)

# Clear previous undo data
cleanup_undo_files "pane"

# Save current state for undo
echo "$PANE_TARGET" > "$UNDO_FILE"
chmod 600 "$UNDO_FILE"

# Save pane metadata
{
    echo "dir=$PANE_DIR"
    echo "layout=$WINDOW_LAYOUT"
} > "$UNDO_STATE"
chmod 600 "$UNDO_STATE"

# Capture pane contents
tmux capture-pane -t "$PANE_TARGET" -p -S -32768 > "$UNDO_CONTENT" 2>/dev/null || true
chmod 600 "$UNDO_CONTENT"
log_debug "Undo state saved"

# Determine if we need to check for session switching
# We need the ACTUAL current client session (where the user is), not the target session
ACTUAL_CLIENT_SESSION=$(tmux display-message -p '#{client_session}' 2>/dev/null || echo "")
log_debug "Actual client session: $ACTUAL_CLIENT_SESSION"

# If last pane in last window and we're in that session, handle session switching
if [[ "$IS_LAST_PANE" == "yes" && "$IS_LAST_WINDOW" == "yes" && "$ACTUAL_CLIENT_SESSION" == "$CURRENT_SESSION" ]]; then
    OTHER_SESSION=$(find_other_session "$CURRENT_SESSION")
    if [[ -n "$OTHER_SESSION" ]]; then
        log_debug "Switching to $OTHER_SESSION before killing last pane"
        tmux switch-client -t "$OTHER_SESSION" \; kill-pane -t "$PANE_TARGET" >> "$LOG_FILE" 2>&1 || {
            log_debug "Kill failed: $?"
            exit 1
        }
    else
        log_debug "No other session, killing last pane (will end session)"
        tmux kill-pane -t "$PANE_TARGET" >> "$LOG_FILE" 2>&1 || {
            log_debug "Kill failed: $?"
            exit 1
        }
    fi
else
    # Kill the pane normally
    # Note: Panes don't have individual alerts (they inherit from windows)
    log_debug "Killing pane normally: $PANE_TARGET"
    tmux kill-pane -t "$PANE_TARGET" >> "$LOG_FILE" 2>&1 || {
        log_debug "Kill failed: $?"
        exit 1
    }
fi

log_debug "Kill done."