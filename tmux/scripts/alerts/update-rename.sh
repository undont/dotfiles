#!/usr/bin/env bash
set -euo pipefail
# update agent alerts when a window is renamed
# called by after-rename-window hook

SESSION="$1"
OLD_WINDOW="$2"
NEW_WINDOW="$3"

readonly ALERTS_FILE="${XDG_CONFIG_HOME:-$HOME/.config}/tmux-alerts/alerts"

# source the alerts library for lock helpers
SCRIPT_DIR="${BASH_SOURCE%/*}"
# shellcheck source=../_lib/alerts.sh
source "$SCRIPT_DIR/../_lib/alerts.sh"

# if format strings weren't expanded, get the values directly from tmux
if [[ "$SESSION" == '#{session_name}' ]] || [[ -z "$SESSION" ]]; then
    SESSION=$(tmux display-message -p '#S' 2>/dev/null) || exit 1
    NEW_WINDOW=$(tmux display-message -p '#W' 2>/dev/null) || exit 1
fi

# validate session and window names. session keeps the strict project
# convention; window names are looser (tmux derives them from running commands
# and they can contain spaces and colons) so reject only control characters
if [[ ! "$SESSION" =~ ^[a-zA-Z0-9._-]+$ ]] || [[ ! "$NEW_WINDOW" =~ ^[^[:cntrl:]]+$ ]]; then
    exit 1
fi

# exit early if no old window name or no alerts file
if [[ -z "$OLD_WINDOW" ]] || [[ ! -f "$ALERTS_FILE" ]]; then
    exit 0
fi

# exit early if old window name is invalid
if [[ ! "$OLD_WINDOW" =~ ^[^[:cntrl:]]+$ ]]; then
    exit 0
fi

# window names are stored percent-encoded; encode both sides to match
ENC_OLD=$(alerts_encode_window "$OLD_WINDOW")
ENC_NEW=$(alerts_encode_window "$NEW_WINDOW")

# check if there are any alerts for this window before attempting update
if ! grep -qF "${SESSION}:${ENC_OLD}:" "$ALERTS_FILE" 2>/dev/null; then
    exit 0
fi

# update alerts file with file locking
if ! _acquire_alerts_lock; then
    exit 0
fi

# perform the update with error handling
tmp_file=$(mktemp "${ALERTS_FILE}.tmp.XXXXXX")
update_success=0

if sed "s|^${SESSION}:${ENC_OLD}:|${SESSION}:${ENC_NEW}:|" "$ALERTS_FILE" > "$tmp_file" 2>/dev/null; then
    if mv "$tmp_file" "$ALERTS_FILE" 2>/dev/null; then
        update_success=1
    fi
fi

# clean up temp file if update failed
if [[ $update_success -eq 0 ]]; then
    rm -f "$tmp_file"
fi

_release_alerts_lock

exit 0
