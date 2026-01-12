#!/bin/bash
# Hook script: Clear agent alert when user interacts with the terminal
# Used by: PostCommand (user submitted a command)

# Source the alerts library
# We need to find the dotfiles directory relative to this script
SCRIPT_DIR="${BASH_SOURCE%/*}"
DOTFILES_DIR=$(cd "$SCRIPT_DIR/../../" && pwd)
ALERTS_LIB="$DOTFILES_DIR/tmux/.tmux/scripts/_lib/alerts.sh"

if [[ -f "$ALERTS_LIB" ]]; then
    source "$ALERTS_LIB"
    
    # Get current session and window
    SESSION=$(tmux display-message -p '#S' 2>/dev/null)
    WINDOW=$(tmux display-message -p '#W' 2>/dev/null)
    WINDOW_ID=$(tmux display-message -p '#D' 2>/dev/null)
    
    # Clear alerts for this window
    if [[ -n "$SESSION" && -n "$WINDOW" ]]; then
        clear_window_alerts "$SESSION" "$WINDOW" "$WINDOW_ID"
    fi
fi
