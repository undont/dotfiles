#!/usr/bin/env bash
set -euo pipefail

# Kill a process (claude, opencode, nvim) running in a specific pane
# without killing the pane itself. Shows a confirmation dialog first.
#
# Usage: kill-instance.sh <session:window.pane> <process_name>
#   process_name: claude, opencode, or nvim

SCRIPT_DIR="${BASH_SOURCE%/*}"
source "$SCRIPT_DIR/../_lib/common.sh"
source "$SCRIPT_DIR/../_lib/ui.sh"
source "$SCRIPT_DIR/../_lib/alerts.sh"

require_tmux

# Load current theme colours for fzf
load_fzf_theme

if [[ $# -lt 2 ]]; then
    show_error "Usage: kill-instance.sh <target> <process_name>"
    exit 1
fi

TARGET="$1"
PROCESS="$2"

# Validate process name
case "$PROCESS" in
    claude|opencode|nvim) ;;
    *)
        show_error "Unknown process: $PROCESS"
        exit 1
        ;;
esac

# Get pane PID
PANE_PID=$(tmux display-message -t "$TARGET" -p '#{pane_pid}' 2>/dev/null) || {
    show_error "Cannot find pane: $TARGET"
    exit 1
}

# Get window name for confirmation message
WINDOW_NAME=$(tmux display-message -t "$TARGET" -p '#{window_name}' 2>/dev/null || echo "$TARGET")

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

# Send SIGTERM for graceful shutdown
kill -TERM "$CHILD_PID" 2>/dev/null || true

# Wait up to 2s for graceful exit
for _ in {1..20}; do
    kill -0 "$CHILD_PID" 2>/dev/null || break
    sleep 0.1
done

# Force kill if still alive
kill -0 "$CHILD_PID" 2>/dev/null && kill -KILL "$CHILD_PID" 2>/dev/null || true

# Clear alerts for claude/opencode (nvim doesn't use alerts)
if [[ "$PROCESS" == "claude" || "$PROCESS" == "opencode" ]]; then
    SESSION=$(echo "$TARGET" | cut -d: -f1)
    WINDOW_IDX=$(echo "$TARGET" | cut -d: -f2 | cut -d. -f1)
    WINDOW_ID=$(tmux display-message -t "${SESSION}:${WINDOW_IDX}" -p '#{window_id}' 2>/dev/null || echo "")
    clear_window_alerts "$SESSION" "$WINDOW_NAME" "$WINDOW_ID"
fi
