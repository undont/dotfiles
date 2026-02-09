#!/usr/bin/env bash
set -euo pipefail

# Create a new window in the current session and launch a process
#
# Usage: new-instance.sh <process_name>
#   process_name: claude, opencode, or nvim

SCRIPT_DIR="${BASH_SOURCE%/*}"
source "$SCRIPT_DIR/../_lib/common.sh"

require_tmux

if [[ $# -lt 1 ]]; then
    show_error "Usage: new-instance.sh <process_name>"
    exit 1
fi

PROCESS="$1"

# Validate process name
case "$PROCESS" in
    claude|opencode|nvim) ;;
    *)
        show_error "Unknown process: $PROCESS"
        exit 1
        ;;
esac

# Get current session and directory
SESSION=$(tmux display-message -p '#{session_name}')
DIR=$(tmux display-message -p '#{pane_current_path}')

# Create new window and launch process
tmux new-window -t "$SESSION" -n "$PROCESS" -c "$DIR"
tmux set-window-option -t "$SESSION:$PROCESS" automatic-rename off
tmux send-keys -t "$SESSION:$PROCESS" "$PROCESS" Enter

# Switch client to the new window
tmux switch-client -t "$SESSION:$PROCESS"
