#!/usr/bin/env bash
set -euo pipefail

# create a new tmux session via fzf prompt

SCRIPT_DIR="${BASH_SOURCE%/*}"
source "$SCRIPT_DIR/../_lib/common.sh"

require_tmux

load_fzf_theme

newname=$(printf '' | fzf \
    --print-query \
    --query='' \
    --prompt='New session: ' \
    --height=100% \
    --layout=reverse \
    --border=rounded \
    --border-label=' ⏎ create · esc cancel ' \
    --border-label-pos=bottom \
    --no-info \
    --pointer=' ' \
    --bind 'enter:print-query' \
    --bind 'esc:abort' \
    2>/dev/null | head -1) || true

# handle empty input (user cancelled)
if [[ -z "$newname" ]]; then
    exit 0
fi

newname=$(sanitise_session_name "$newname")

if ! validate_session_name "$newname"; then
    # validate_session_name already outputs error message via error()
    exit 1
fi

if session_exists "$newname"; then
    tmux switch-client -t "$newname"
else
    tmux new-session -d -s "$newname" -n "zsh" -c ~
    tmux switch-client -t "$newname"
fi
