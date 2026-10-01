#!/usr/bin/env bash
# clear agent alerts for the current window
# called by after-select-window hook and window/session switchers

SESSION="$1"
WINDOW="$2"
WINDOW_ID="$3"

SCRIPT_DIR="${BASH_SOURCE%/*}"
source "$SCRIPT_DIR/../_lib/alerts.sh"

# resolve the target when the caller passed nothing (the agent hooks) or when
# format strings weren't expanded (display-popup doesn't expand them). TMUX_PANE
# names the pane the caller runs in; an untargeted display-message answers for
# the attached client's current window instead. a blank window name is recovered
# from the window id: during a pane kill the automatic-rename-format can resolve
# to empty while the pane's command/title is unset
if [[ "$SESSION" == '#{session_name}' ]] || [[ -z "$SESSION" ]]; then
    TARGET=()
    [[ -n "${TMUX_PANE:-}" ]] && TARGET=(-t "$TMUX_PANE")
    META=$(tmux display-message "${TARGET[@]}" -p $'#S\t#{window_id}\t#W' 2>/dev/null)
    IFS=$'\t' read -r SESSION WINDOW_ID WINDOW <<<"$META"
elif [[ -z "$WINDOW" && -n "$WINDOW_ID" ]]; then
    WINDOW=$(tmux display-message -t "$WINDOW_ID" -p '#W' 2>/dev/null)
fi

# sessions: alphanumerics, dots, underscores, hyphens. windows are looser: tmux
# names them from running commands and a user rename can include spaces and
# colons. an empty name is allowed (the id-keyed cleanup in clear_window_alerts
# still runs); control characters would corrupt the alerts file.
# exit 0 on reject: a non-zero exit from a backgrounded run-shell hook is
# reported on the status line
[[ "$SESSION" =~ ^[a-zA-Z0-9._-]+$ ]] || exit 0
case "$WINDOW" in *[[:cntrl:]]*) exit 0 ;; esac

clear_window_alerts "$SESSION" "$WINDOW" "$WINDOW_ID"
