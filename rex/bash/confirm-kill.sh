#!/usr/bin/env bash
# confirm, then kill the session, tab or pane the popup was opened over.
# run inside a floating layer by the kill_* actions; sessions and tabs save an
# undo snapshot (u in their pickers, or undo_kill, restores it)
# usage: confirm-kill.sh <client_id> <origin_session_id> <origin_block_id> <origin_zoomed> session|tab|pane
set -euo pipefail

scripts="${BASH_SOURCE%/*}"
# shellcheck source=/dev/null
source "$scripts/_lib.sh"

picker_start "$1" "$2" "$3" "$4"
wait_for_resize

case "${5:-}" in
session)
    "$scripts/pick-action.sh" kill sessions session="$PICK_ORIGIN_SESSION"
    ;;
tab)
    "$scripts/pick-action.sh" kill tabs session="$PICK_ORIGIN_SESSION" block="$PICK_ORIGIN_BLOCK"
    ;;
pane)
    show_visual_confirm "Kill Pane" "Kill this pane?" || exit 0
    rex block close -s "$PICK_ORIGIN_SESSION" "$PICK_ORIGIN_BLOCK" >/dev/null
    ;;
*)
    printf 'usage: %s <client> <session> <block> <zoomed> session|tab|pane\n' "${0##*/}" >&2
    exit 2
    ;;
esac
