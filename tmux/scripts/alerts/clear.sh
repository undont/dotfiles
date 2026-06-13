#!/usr/bin/env bash
# clear agent alerts for the current window
# called by after-select-window hook and window/session switchers

SESSION="$1"
WINDOW="$2"
WINDOW_ID="$3"

SCRIPT_DIR="${BASH_SOURCE%/*}"
source "$SCRIPT_DIR/../_lib/alerts.sh"

# if format strings weren't expanded (display-popup doesn't expand them),
# get the values directly from tmux
if [[ "$SESSION" == '#{session_name}' ]] || [[ -z "$SESSION" ]]; then
    SESSION=$(tmux display-message -p '#S')
    WINDOW=$(tmux display-message -p '#W')
    WINDOW_ID=$(tmux display-message -p '#D')
fi

# validate session and window names. sessions follow project convention
# (alphanumerics, dots, underscores, hyphens; see validate_session_name).
# windows are looser because tmux assigns names from running commands and
# user-rename can include spaces and colons; reject only control characters.
# clear_window_alerts percent-encodes the window name before touching the
# alerts file, so a literal colon (the file delimiter) is handled safely
if [[ ! "$SESSION" =~ ^[a-zA-Z0-9._-]+$ ]] || [[ ! "$WINDOW" =~ ^[^[:cntrl:]]+$ ]]; then
    exit 1
fi

# clear all agent alerts for this window
clear_window_alerts "$SESSION" "$WINDOW" "$WINDOW_ID"
