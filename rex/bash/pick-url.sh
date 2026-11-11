#!/usr/bin/env bash
# open or copy a URL from the origin pane's scrollback, run inside a floating
# layer by the pick_url action. the URLs come from do/urls.lua, newest first
# usage: pick-url.sh <client_id> <origin_session_id> <origin_block_id> <origin_zoomed>
set -euo pipefail

# shellcheck source=/dev/null
source "${BASH_SOURCE%/*}/_lib.sh"

picker_start "$1" "$2" "$3" "$4"
[[ -n "$PICK_ORIGIN_BLOCK" ]] || exit 0

urls=$(pick cmd=urls.list) || true

wait_for_resize
if [[ -z "$urls" ]]; then
    show_notification "No URLs found in scrollback" 1
    exit 0
fi

picker_fzf_opts 'j,k,g,G,f,b,d,u,q,space,y,o' \
    'j/k · g/G · f/b · d/u · o/spc/⏎ open · y yank · / search · q/esc quit'
selected=$(
    printf '%s\n' "$urls" |
        fzf "${PICKER_FZF_OPTS[@]}" --no-sort \
            --bind 'o:accept,f:page-down,b:page-up,d:half-page-down,u:half-page-up' \
            --bind "y:execute-silent(printf '%s' {} | \"${BASH_SOURCE%/*}/copy-in-app.sh\")+abort"
) || exit 0

[[ -n "$selected" ]] && open_in_app "$selected"
