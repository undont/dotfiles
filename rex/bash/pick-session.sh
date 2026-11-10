#!/usr/bin/env bash
# fzf session picker, run inside a floating layer by the pick_session action.
# rows and actions are in pick/sessions.lua
# usage: pick-session.sh <client_id> <origin_session_id> <origin_block_id> <origin_zoomed>
set -euo pipefail

scripts="${BASH_SOURCE%/*}"
# shellcheck source=/dev/null
source "$scripts/_lib.sh"

picker_start "$1" "$2" "$3" "$4"
rows=$(pick cmd=sessions.list)
wait_for_resize

list="rex do $PICK_LUA cmd=sessions.list"
action="$scripts/pick-action.sh"
picker_fzf_opts 'j,k,g,G,q,space,n,r,x,u' \
    'j/k ↓/↑ · g/G top/bottom · spc/⏎ sel · / srch · q/esc · n new · r rename · x kill · u undo'

# rows are session_id, block_id to preview, label
selected=$(
    printf '%s\n' "$rows" |
        fzf "${PICKER_FZF_OPTS[@]}" --header-lines="$(header_count "$rows")" --with-nth=3 \
            --preview "rex do $PICK_LUA cmd=preview session={1} block={2}" \
            --bind "n:execute($action new-session)+abort" \
            --bind "r:execute($action rename sessions session={1})+reload-sync($list)" \
            --bind "x:execute($action kill sessions session={1})+reload-sync($list)" \
            --bind "u:execute-silent(rex do $PICK_LUA cmd=sessions.undo)+reload-sync($list)" |
        cut -f1
) || exit 0

[[ -n "$selected" ]] || exit 0
trap - EXIT
pick cmd=sessions.select session="$selected"
