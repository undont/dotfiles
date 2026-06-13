#!/usr/bin/env bash
set -euo pipefail

# restore the last killed session from its preserved backup
# usage: undo.sh [--quick]
#   --quick: skip UI messages and delays (for use from fzf/scripts)

SCRIPT_DIR="${BASH_SOURCE%/*}"
source "$SCRIPT_DIR/../_lib/common.sh"
source "$SCRIPT_DIR/../_lib/paths.sh"

QUICK_MODE=false
[[ "${1:-}" == "--quick" ]] && QUICK_MODE=true

# only load UI if not in quick mode
if [[ "$QUICK_MODE" == false ]]; then
    source "$SCRIPT_DIR/../_lib/ui.sh"
fi

# get undo file paths
UNDO_FILE=$(get_session_undo_file)
UNDO_BACKUP=$(get_session_undo_backup)

# check if there's something to undo
if [[ ! -f "$UNDO_FILE" ]]; then
    if [[ "$QUICK_MODE" == false ]]; then
        show_centered_message "No session to restore" "" "No recently killed session found."
        sleep 2
    fi
    exit 0
fi

SESSION_NAME=$(cat "$UNDO_FILE")

# check if backup exists
if [[ ! -f "$UNDO_BACKUP" ]]; then
    cleanup_undo_files "session"
    if [[ "$QUICK_MODE" == false ]]; then
        show_centered_message "Backup not found" "" "Backup for '$SESSION_NAME' not found."
        sleep 2
    fi
    exit 0
fi

# restore the session using existing script, passing the undo backup directly
# (avoids race with split.sh orphan cleanup deleting from sessions/)
declare -a restore_args=("--session" "$SESSION_NAME" "--file" "$UNDO_BACKUP")
[[ "$QUICK_MODE" == true ]] && restore_args+=("--no-switch")

if "$SCRIPT_DIR/../resurrect/restore.sh" "${restore_args[@]}" 2>&1; then
    # only cleanup undo data on success (preserve for retry on failure)
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
