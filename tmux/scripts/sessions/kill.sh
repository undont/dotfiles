#!/usr/bin/env bash
set -euo pipefail

# Kill a tmux session with confirmation dialog and undo capability
# Usage: kill-session.sh <session_name> [--no-confirm]

SCRIPT_DIR="${BASH_SOURCE%/*}"
source "$SCRIPT_DIR/../_lib/common.sh"
source "$SCRIPT_DIR/../_lib/ui.sh"
source "$SCRIPT_DIR/../_lib/paths.sh"
source "$SCRIPT_DIR/../_lib/session.sh"
source "$SCRIPT_DIR/../_lib/alerts.sh"

require_tmux

# Load current theme colours for fzf
load_fzf_theme

SESSION_NAME="${1:-}"
NO_CONFIRM="${2:-}"
[[ -z "$SESSION_NAME" ]] && exit 1

# Get the current session (the one the client is attached to)
CURRENT_SESSION=$(get_current_session)

# Prevent killing the last session
if is_last_session; then
    tmux display-message "Cannot kill session: This is the only session. Create another session first."
    exit 1
fi

# If killing the current session, show confirmation then switch and kill
if [[ "$SESSION_NAME" == "$CURRENT_SESSION" ]]; then
    OTHER_SESSION=$(find_other_session "$SESSION_NAME")

    if [[ -n "$OTHER_SESSION" ]]; then
        if [[ "$NO_CONFIRM" != "--no-confirm" ]]; then
            # Show visual confirmation
            TITLE="Kill Session"
            MESSAGE="Kill session '${SESSION_NAME}' and switch to '${OTHER_SESSION}'?"

            if ! show_visual_confirm "$TITLE" "$MESSAGE"; then
                exit 0  # Exit cleanly on cancellation
            fi
        fi

        # User confirmed - now save undo state
        UNDO_FILE=$(get_session_undo_file)
        BACKUP_SRC="${HOME}/.tmux/resurrect/sessions/${SESSION_NAME}.txt"
        UNDO_BACKUP=$(get_session_undo_backup)

        # Clear previous undo data
        cleanup_undo_files "session"

        # Save session name for undo
        echo "$SESSION_NAME" > "$UNDO_FILE"
        chmod 600 "$UNDO_FILE"

        # Copy existing backup immediately (fast) - uses last auto-save state
        if [[ -f "$BACKUP_SRC" ]]; then
            cp "$BACKUP_SRC" "$UNDO_BACKUP"
            chmod 600 "$UNDO_BACKUP"
        fi

        # Switch and kill first (fast)
        tmux switch-client -t "$OTHER_SESSION" \; kill-session -t "$SESSION_NAME"

        # Background: clear alerts and update saves for remaining sessions
        (
            clear_session_alerts "$SESSION_NAME"
            ~/.tmux/plugins/tmux-resurrect/scripts/save.sh >/dev/null 2>&1 || true
            ~/.tmux/scripts/resurrect/split.sh >/dev/null 2>&1 || true
        ) &
        exit 0
    else
        error "Failed to find another session to switch to"
        exit 1
    fi
else
    # Killing a different session (not current)
    if [[ "$NO_CONFIRM" != "--no-confirm" ]]; then
        # Show visual confirmation for killing inactive session
        TITLE="Kill Session"
        MESSAGE="Kill inactive session '${SESSION_NAME}'?"

        if ! show_visual_confirm "$TITLE" "$MESSAGE"; then
            exit 0  # Exit cleanly on cancellation
        fi
    fi

    # User confirmed - now save undo state
    UNDO_FILE=$(get_session_undo_file)
    BACKUP_SRC="${HOME}/.tmux/resurrect/sessions/${SESSION_NAME}.txt"
    UNDO_BACKUP=$(get_session_undo_backup)

    # Clear previous undo data
    cleanup_undo_files "session"

    # Save session name for undo
    echo "$SESSION_NAME" > "$UNDO_FILE"
    chmod 600 "$UNDO_FILE"

    # Copy existing backup immediately (fast) - uses last auto-save state
    if [[ -f "$BACKUP_SRC" ]]; then
        cp "$BACKUP_SRC" "$UNDO_BACKUP"
        chmod 600 "$UNDO_BACKUP"
    fi

    # Kill first (fast)
    tmux kill-session -t "$SESSION_NAME" 2>/dev/null || true

    # Background: clear alerts and update saves for remaining sessions
    (
        clear_session_alerts "$SESSION_NAME"
        ~/.tmux/plugins/tmux-resurrect/scripts/save.sh >/dev/null 2>&1 || true
        ~/.tmux/scripts/resurrect/split.sh >/dev/null 2>&1 || true
    ) &
fi
