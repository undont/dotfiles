#!/usr/bin/env bash
# fzf picker over one agent's panes in every session, run inside a floating
# layer by the pick_<agent> actions, and over nvim's by pick_nvim. rows and
# actions are in do/panes.lua
# usage: pick-agents.sh <client_id> <origin_session_id> <origin_block_id> <origin_zoomed> <program>
#   program: claude, codex, opencode, copilot or nvim
set -euo pipefail

scripts="${BASH_SOURCE%/*}"
# shellcheck source=/dev/null
source "$scripts/_lib.sh"

picker_start "$1" "$2" "$3" "$4"
program="${5:-}"
case "$program" in
claude | codex | opencode | copilot | nvim) ;;
*)
    printf 'usage: %s <client> <session> <block> <zoomed> claude|codex|opencode|copilot|nvim\n' "${0##*/}" >&2
    exit 2
    ;;
esac

rows=$(pick cmd=panes.list program="$program")
wait_for_resize

list="rex do $PICK_LUA cmd=panes.list program=$program"
action="$scripts/pick-action.sh"
picker_fzf_opts 'j,k,g,G,q,space,n,x' \
    "j/k ↓/↑ · g/G top/bottom · spc/⏎ jump · / srch · n new $program · x kill · q/esc"

# rows are block_id, session_id, window_id, display
selected=$(
    printf '%s\n' "$rows" |
        fzf "${PICKER_FZF_OPTS[@]}" --header-lines="$(header_count "$rows")" --with-nth=4 \
            --preview "rex do $PICK_LUA cmd=preview session={2} block={1}" \
            --bind "every(2):reload-sync($list)" \
            --bind "n:become(printf 'new')" \
            --bind "x:execute($action kill panes session={2} block={1})+reload-sync($list)" |
        cut -f1-3
) || exit 0

[[ -n "$selected" ]] || exit 0
trap - EXIT
if [[ "$selected" == new ]]; then
    pick cmd=panes.new program="$program"
    exit 0
fi
IFS=$'\t' read -r block session window <<<"$selected"
pick cmd=panes.select session="$session" window="$window" block="$block"
