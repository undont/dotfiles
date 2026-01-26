#!/usr/bin/env bash
set -euo pipefail

# Restore the last killed session from its preserved backup
# Usage: undo-session.sh [--quick]
#   --quick: Skip UI messages and delays (for use from fzf/scripts)

SCRIPT_DIR="${BASH_SOURCE%/*}"
source "$SCRIPT_DIR/_lib/common.sh"
source "$SCRIPT_DIR/_lib/paths.sh"

QUICK_MODE=false
[[ "${1:-}" == "--quick" ]] && QUICK_MODE=true

# Only load UI if not in quick mode
if [[ "$QUICK_MODE" == false ]]; then
    source "$SCRIPT_DIR/_lib/ui.sh"
fi

# Get undo file paths
UNDO_FILE=$(get_session_undo_file)
UNDO_BACKUP=$(get_session_undo_backup)
SESSIONS_DIR="${HOME}/.tmux/resurrect/sessions"

# Check if there's something to undo
if [[ ! -f "$UNDO_FILE" ]]; then
    if [[ "$QUICK_MODE" == false ]]; then
        show_centered_message "No session to restore" "" "No recently killed session found."
        sleep 2
    fi
    exit 0
fi

SESSION_NAME=$(cat "$UNDO_FILE")

# Check if backup exists
if [[ ! -f "$UNDO_BACKUP" ]]; then
    cleanup_undo_files "session"
    if [[ "$QUICK_MODE" == false ]]; then
        show_centered_message "Backup not found" "" "Backup for '$SESSION_NAME' not found."
        sleep 2
    fi
    exit 0
fi

# Ensure sessions directory exists
mkdir -p "$SESSIONS_DIR"

# Restore the backup to proper location
cp "$UNDO_BACKUP" "${SESSIONS_DIR}/${SESSION_NAME}.txt"
chmod 600 "${SESSIONS_DIR}/${SESSION_NAME}.txt"

# Restore the session using existing script
declare -a restore_args=("--session" "$SESSION_NAME")
[[ "$QUICK_MODE" == true ]] && restore_args+=("--no-switch")

if "$SCRIPT_DIR/restore-resurrect.sh" "${restore_args[@]}" 2>&1; then
    if [[ "$QUICK_MODE" == false ]]; then
        show_centered_message "Session restored" "" "Restored: $SESSION_NAME"
        sleep 1
    fi
else
    if [[ "$QUICK_MODE" == false ]]; then
        show_centered_message "Restore failed" "" "Failed to restore: $SESSION_NAME"
        sleep 2
    fi
fi

# Cleanup undo data
cleanup_undo_files "session"
