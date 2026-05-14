#!/usr/bin/env bash
set -euo pipefail

# Restore the last killed session from its preserved backup
# Usage: undo.sh [--quick]
#   --quick: Skip UI messages and delays (for use from fzf/scripts)

SCRIPT_DIR="${BASH_SOURCE%/*}"
source "$SCRIPT_DIR/../_lib/common.sh"
source "$SCRIPT_DIR/../_lib/paths.sh"

QUICK_MODE=false
[[ "${1:-}" == "--quick" ]] && QUICK_MODE=true

# Only load UI if not in quick mode
if [[ "$QUICK_MODE" == false ]]; then
    source "$SCRIPT_DIR/../_lib/ui.sh"
fi

# Get undo file paths
UNDO_FILE=$(get_session_undo_file)
UNDO_BACKUP=$(get_session_undo_backup)

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

# Restore the session using existing script, passing the undo backup directly
# (avoids race with split.sh orphan cleanup deleting from sessions/)
declare -a restore_args=("--session" "$SESSION_NAME" "--file" "$UNDO_BACKUP")
[[ "$QUICK_MODE" == true ]] && restore_args+=("--no-switch")

if "$SCRIPT_DIR/../resurrect/restore.sh" "${restore_args[@]}" 2>&1; then
    # Only cleanup undo data on success (preserve for retry on failure)
    cleanup_undo_files "session"
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
