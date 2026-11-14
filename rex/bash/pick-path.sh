#!/usr/bin/env bash
# copy a file path from the origin pane's scrollback, run inside a floating
# layer by the pick_path action. the paths come from do/paths.lua, newest first
# usage: pick-path.sh <client_id> <origin_session_id> <origin_block_id> <origin_zoomed>
set -euo pipefail

# shellcheck source=/dev/null
source "${BASH_SOURCE%/*}/_lib.sh"

picker_start "$1" "$2" "$3" "$4"
[[ -n "$PICK_ORIGIN_BLOCK" ]] || exit 0

paths=$(pick cmd=paths.list) || true

wait_for_resize
if [[ -z "$paths" ]]; then
    show_notification "No paths found in scrollback" 1
    exit 0
fi

picker_fzf_opts 'j,k,g,G,f,b,d,u,q,space,y' \
    'j/k · g/G · f/b · d/u · y/spc/⏎ yank · / search · q/esc quit'
selected=$(
    printf '%s\n' "$paths" |
        fzf "${PICKER_FZF_OPTS[@]}" --no-sort \
            --bind 'y:accept,f:page-down,b:page-up,d:half-page-down,u:half-page-up'
) || exit 0

[[ -n "$selected" ]] && printf '%s' "$selected" | "${BASH_SOURCE%/*}/copy-in-app.sh"
