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
source "$SCRIPT_DIR/../_lib/alerts.sh"

require_tmux

# Load current theme colours for fzf
load_fzf_theme

# Get current state
if [[ -n "$PANE_TARGET" ]]; then
    # Target specified - parse session:window.pane format
    CURRENT_SESSION="${PANE_TARGET%%:*}"
    REST="${PANE_TARGET#*:}"
    CURRENT_WINDOW="${REST%%.*}"
    CURRENT_PANE="${REST#*.}"

    # Verify the target exists
    if ! tmux list-panes -t "${CURRENT_SESSION}:${CURRENT_WINDOW}" 2>/dev/null | grep -q "^${CURRENT_PANE}:"; then
        exit 1
    fi

    PANE_DIR=$(tmux display-message -t "$PANE_TARGET" -p '#{pane_current_path}')
    WINDOW_LAYOUT=$(tmux display-message -t "$PANE_TARGET" -p '#{window_layout}')
else
    # No target - use current pane
    CURRENT_SESSION=$(get_current_session)
    CURRENT_WINDOW=$(get_current_window)
    CURRENT_PANE=$(get_current_pane)
    PANE_TARGET="${CURRENT_SESSION}:${CURRENT_WINDOW}.${CURRENT_PANE}"
    PANE_DIR=$(get_pane_directory)
    WINDOW_LAYOUT=$(get_window_layout)
fi

# Check if this is the last pane/window to customise the message
PANE_COUNT=$(tmux list-panes -t "${CURRENT_SESSION}:${CURRENT_WINDOW}" 2>/dev/null | wc -l | tr -d ' ')
WINDOW_COUNT=$(tmux list-windows -t "$CURRENT_SESSION" 2>/dev/null | wc -l | tr -d ' ')
IS_LAST_PANE=$([[ "$PANE_COUNT" -eq 1 ]] && echo "yes" || echo "no")
IS_LAST_WINDOW=$([[ "$WINDOW_COUNT" -eq 1 ]] && echo "yes" || echo "no")

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

    if ! show_visual_confirm "Kill Pane" "$MESSAGE"; then
        exit 0
    fi
fi

# User confirmed - save undo state
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

# Capture window name/ID before the kill for alert cleanup
# (killing the last pane destroys the window, so we need these beforehand)
if [[ "$IS_LAST_PANE" == "yes" ]]; then
    WINDOW_NAME=$(tmux display-message -t "${CURRENT_SESSION}:${CURRENT_WINDOW}" -p '#{window_name}' 2>/dev/null || echo "")
    WINDOW_ID=$(tmux display-message -t "${CURRENT_SESSION}:${CURRENT_WINDOW}" -p '#{window_id}' 2>/dev/null || echo "")
fi

# Determine if we need to check for session switching
# We need the ACTUAL current client session (where the user is), not the target session
ACTUAL_CLIENT_SESSION=$(tmux display-message -p '#{client_session}' 2>/dev/null || echo "")

# If last pane in last window and we're in that session, handle session switching
if [[ "$IS_LAST_PANE" == "yes" && "$IS_LAST_WINDOW" == "yes" && "$ACTUAL_CLIENT_SESSION" == "$CURRENT_SESSION" ]]; then
    OTHER_SESSION=$(find_other_session "$CURRENT_SESSION")
    if [[ -n "$OTHER_SESSION" ]]; then
        tmux switch-client -t "$OTHER_SESSION" \; kill-pane -t "$PANE_TARGET" 2>/dev/null || exit 1
    else
        tmux kill-pane -t "$PANE_TARGET" 2>/dev/null || exit 1
    fi
    # Session is destroyed — clear all session alerts synchronously
    # (backgrounding risks SIGHUP killing the process when popup exits)
    clear_session_alerts "$CURRENT_SESSION"
elif [[ "$IS_LAST_PANE" == "yes" ]]; then
    # Last pane but not last window — killing destroys the window
    tmux kill-pane -t "$PANE_TARGET" 2>/dev/null || exit 1
    # Window is destroyed — clear its alerts
    clear_window_alerts "$CURRENT_SESSION" "$WINDOW_NAME" "$WINDOW_ID"
else
    # Not the last pane — panes don't have individual alerts
    tmux kill-pane -t "$PANE_TARGET" 2>/dev/null || exit 1
fi
