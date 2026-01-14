#!/usr/bin/env bash
# FZF-based confirmation for kill operations
# Usage: fzf-confirm-kill.sh <type> <target> [--current-session]
#   type: "session", "window", or "pane"
#   target: session name, session:window, or session:window.pane
#   --current-session: indicates target is the current session (needs switch)

set -euo pipefail

SCRIPT_DIR="${BASH_SOURCE%/*}"
source "$SCRIPT_DIR/_lib/common.sh"
source "$SCRIPT_DIR/_lib/session.sh"
source "$SCRIPT_DIR/_lib/alerts.sh"

TYPE="$1"
TARGET="$2"
IS_CURRENT="${3:-}"

# Show confirmation using fzf with y/n options
confirm=$(printf "y\nn" | fzf \
    --height=~100% \
    --layout=reverse \
    --border=rounded \
    --border-label=" Kill ${TYPE} '${TARGET}'? " \
    --border-label-pos=top \
    --no-info \
    --prompt='Select: ' \
    --pointer='→' \
    --bind 'j:down,k:up' \
    --bind 'y:accept' \
    --bind 'n:abort' \
    --bind 'enter:accept' \
    --bind 'esc:abort' \
    --bind 'q:abort')

if [[ "$confirm" == "y" ]]; then
    case "$TYPE" in
        session)
            if [[ "$IS_CURRENT" == "--current-session" ]]; then
                OTHER_SESSION=$(find_other_session "$TARGET")
                if [[ -n "$OTHER_SESSION" ]]; then
                    clear_session_alerts "$TARGET"
                    tmux switch-client -t "$OTHER_SESSION" \; kill-session -t "$TARGET"
                else
                    error "Failed to find another session to switch to"
                    exit 1
                fi
            else
                clear_session_alerts "$TARGET"
                tmux kill-session -t "$TARGET"
            fi
            ;;
        window)
            # Extract session and window from target
            SESSION="${TARGET%%:*}"
            WINDOW_NAME=$(tmux display-message -t "$TARGET" -p '#{window_name}')
            
            clear_window_alerts "$SESSION" "$WINDOW_NAME"
            
            if [[ "$IS_CURRENT" == "--current-session" ]]; then
                OTHER_SESSION=$(find_other_session "$SESSION")
                if [[ -n "$OTHER_SESSION" ]]; then
                    tmux switch-client -t "$OTHER_SESSION" \; kill-window -t "$TARGET"
                else
                    tmux kill-window -t "$TARGET"
                fi
            else
                tmux kill-window -t "$TARGET"
            fi
            ;;
        pane)
            # Extract session, window, pane from target
            SESSION="${TARGET%%:*}"
            # REST="${TARGET#*:}"  # Unused: extracted for pane but not needed
            # WINDOW="${REST%%.*}" # Unused: extracted for pane but not needed
            
            if [[ "$IS_CURRENT" == "--current-session" ]]; then
                OTHER_SESSION=$(find_other_session "$SESSION")
                if [[ -n "$OTHER_SESSION" ]]; then
                    tmux switch-client -t "$OTHER_SESSION" \; kill-pane -t "$TARGET"
                else
                    tmux kill-pane -t "$TARGET"
                fi
            else
                tmux kill-pane -t "$TARGET"
            fi
            ;;
        *)
            error "Unknown type: $TYPE"
            exit 1
            ;;
    esac
    exit 0
else
    exit 1
fi
