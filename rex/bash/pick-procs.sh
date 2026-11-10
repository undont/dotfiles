#!/usr/bin/env bash
# fzf picker over commands running in rex panes and the last hour's finished
# ones, run inside a floating layer by the pick_procs action. rows and actions
# are in do/procs.lua
# usage: pick-procs.sh <client_id> <origin_session_id> <origin_block_id> <origin_zoomed>
set -euo pipefail

# shellcheck source=/dev/null
source "${BASH_SOURCE%/*}/_lib.sh"

picker_start "$1" "$2" "$3" "$4"

rows=$(pick cmd=procs.list)
wait_for_resize

list="rex do $PICK_LUA cmd=procs.list"
row_args="type={4} session={2} block={1} epoch={5}"
picker_fzf_opts 'j,k,g,G,q,space,x,r,R' \
    "j/k ↓/↑ · g/G top/bottom · spc/⏎ jump · r/R stage/run · x stop/clear · / srch · q/esc"

# rows are block_id, session_id, window_id, type, epoch, display
selected=$(
    printf '%s\n' "$rows" |
        fzf "${PICKER_FZF_OPTS[@]}" --header-lines="$(header_count "$rows")" --with-nth=6 \
            --preview "rex do $PICK_LUA cmd=preview session={2} block={1}" \
            --bind "every(2):reload-sync($list)" \
            --bind "x:execute-silent(rex do $PICK_LUA cmd=procs.dismiss $row_args)+reload-sync($list)" \
            --bind "r:execute-silent(rex do $PICK_LUA cmd=procs.rerun $row_args)+accept" \
            --bind "R:execute-silent(rex do $PICK_LUA cmd=procs.rerun $row_args mode=exec)+accept" |
        cut -f1-3
) || exit 0

IFS=$'\t' read -r block session window <<<"$selected"
[[ -n "$session" ]] || exit 0
trap - EXIT
pick cmd=procs.select session="$session" window="$window" block="$block"
