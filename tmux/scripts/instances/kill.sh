#!/usr/bin/env bash
set -euo pipefail

# Kill a process (claude, codex, opencode, copilot, nvim) running in a specific pane
# without killing the pane itself. Shows a confirmation dialog first.
#
# Usage: kill.sh <session:window.pane> <process_name>
#   process_name: claude, codex, opencode, copilot, or nvim

SCRIPT_DIR="${BASH_SOURCE%/*}"
source "$SCRIPT_DIR/../_lib/common.sh"
source "$SCRIPT_DIR/../_lib/ui.sh"
source "$SCRIPT_DIR/../_lib/alerts.sh"
source "$SCRIPT_DIR/../_lib/process.sh"

require_tmux

if [[ $# -lt 2 ]]; then
    show_error "Usage: kill.sh <target> <process_name>"
    exit 1
fi

TARGET="$1"
PROCESS="$2"

# Validate process name
case "$PROCESS" in
    claude|codex|opencode|copilot|nvim) ;;
    *)
        show_error "Unknown process: $PROCESS"
        exit 1
        ;;
esac

# Get pane PID and window metadata in one tmux round-trip
target_info=$(tmux display-message -t "$TARGET" -p '#{pane_pid}|#{session_name}|#{window_index}|#{window_name}|#{window_id}' 2>/dev/null) || {
    show_error "Cannot find pane: $TARGET"
    exit 1
}
IFS='|' read -r PANE_PID SESSION WINDOW_IDX WINDOW_NAME WINDOW_ID <<< "$target_info"
[[ -n "$WINDOW_NAME" ]] || WINDOW_NAME="$TARGET"

# Find the child process matching process name
MATCH_FLAG="-x"
[[ "$PROCESS" == "opencode" ]] && MATCH_FLAG="-f"

CHILD_PID=""

# Check direct children first
CHILD_PID=$(pgrep -P "$PANE_PID" "$MATCH_FLAG" "$PROCESS" 2>/dev/null | head -1) || true

# If not a direct child, walk process tree (some shells spawn subprocesses)
if [[ -z "$CHILD_PID" ]]; then
    for pid in $(pgrep -P "$PANE_PID" 2>/dev/null); do
        CHILD_PID=$(pgrep -P "$pid" "$MATCH_FLAG" "$PROCESS" 2>/dev/null | head -1) && break
        for pid2 in $(pgrep -P "$pid" 2>/dev/null); do
            CHILD_PID=$(pgrep -P "$pid2" "$MATCH_FLAG" "$PROCESS" 2>/dev/null | head -1) && break 2
        done
    done
fi

if [[ -z "$CHILD_PID" ]]; then
    show_error "No $PROCESS process found in $WINDOW_NAME"
    exit 1
fi

# Show confirmation
if ! show_visual_confirm "Kill Instance" "Kill ${PROCESS} in '${WINDOW_NAME}'?"; then
    exit 0
fi

# Graceful shutdown: SIGTERM → wait 2s → SIGKILL
graceful_kill_pids 2 "$CHILD_PID"

# Clear alerts for agent processes (nvim doesn't use alerts)
if [[ "$PROCESS" == "claude" || "$PROCESS" == "codex" || "$PROCESS" == "opencode" || "$PROCESS" == "copilot" ]]; then
    clear_window_alerts "$SESSION" "$WINDOW_NAME" "$WINDOW_ID"
fi
