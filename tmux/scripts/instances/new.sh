#!/usr/bin/env bash
set -euo pipefail

# create a new window in the current session and launch a process
#
# usage: new.sh <process_name>
#   process_name: claude, codex, opencode, copilot, or nvim

SCRIPT_DIR="${BASH_SOURCE%/*}"
source "$SCRIPT_DIR/../_lib/common.sh"

require_tmux

if [[ $# -lt 1 ]]; then
    show_error "Usage: new.sh <process_name>"
    exit 1
fi

PROCESS="$1"

# validate process name
case "$PROCESS" in
    claude|codex|opencode|copilot|nvim) ;;
    *)
        show_error "Unknown process: $PROCESS"
        exit 1
        ;;
esac

# get current session and directory
SESSION=$(tmux display-message -p '#{session_name}')
DIR=$(tmux display-message -p '#{pane_current_path}')

# create new window and capture its exact target (avoids name collision
# when multiple windows share the same name, e.g. several "nvim" windows)
TARGET=$(tmux new-window -P -F '#{session_name}:#{window_index}' -t "$SESSION" -n "$PROCESS" -c "$DIR")
tmux set-window-option -t "$TARGET" automatic-rename off
tmux send-keys -t "$TARGET" "$PROCESS" Enter

# switch client to the new window
tmux switch-client -t "$TARGET"
