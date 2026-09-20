#!/usr/bin/env bash
# clear agent alerts for the current window
# called by after-select-window hook and window/session switchers

SESSION="$1"
WINDOW="$2"
WINDOW_ID="$3"

SCRIPT_DIR="${BASH_SOURCE%/*}"
source "$SCRIPT_DIR/../_lib/alerts.sh"

# resolve the target when the caller passed nothing (the agent hooks) or when
# format strings weren't expanded (display-popup doesn't expand them). prefer
# TMUX_PANE: it names the pane the caller runs in, whereas an untargeted
# display-message answers for the attached client's current window, which is a
# different window whenever the agent is working in the background. a blank
# window name is a separate case: during a pane kill/refocus the
# automatic-rename-format can transiently resolve to empty while the pane's
# command/title is unset, so recover the name from the stable window id (the
# hook runs backgrounded, so by now it has usually settled) rather than
# treating the blank as fatal
if [[ "$SESSION" == '#{session_name}' ]] || [[ -z "$SESSION" ]]; then
    TARGET=()
    [[ -n "${TMUX_PANE:-}" ]] && TARGET=(-t "$TMUX_PANE")
    META=$(tmux display-message "${TARGET[@]}" -p $'#S\t#{window_id}\t#W' 2>/dev/null)
    IFS=$'\t' read -r SESSION WINDOW_ID WINDOW <<<"$META"
elif [[ -z "$WINDOW" && -n "$WINDOW_ID" ]]; then
    WINDOW=$(tmux display-message -t "$WINDOW_ID" -p '#W' 2>/dev/null)
fi

# validate session and window names. sessions follow project convention
# (alphanumerics, dots, underscores, hyphens; see validate_session_name).
# windows are looser because tmux assigns names from running commands and
# user-rename can include spaces and colons; an empty name is allowed (the
# id-keyed cleanup in clear_window_alerts still runs) but control characters
# would corrupt the alerts file, so reject those. clear_window_alerts
# percent-encodes the window name before touching the alerts file, so a
# literal colon (the file delimiter) is handled safely.
# exit 0 not 1 on reject: a backgrounded run-shell hook has no consumer for
# the exit code, and a non-zero return is what leaks to the status line
[[ "$SESSION" =~ ^[a-zA-Z0-9._-]+$ ]] || exit 0
case "$WINDOW" in *[[:cntrl:]]*) exit 0 ;; esac

# clear all agent alerts for this window
clear_window_alerts "$SESSION" "$WINDOW" "$WINDOW_ID"
