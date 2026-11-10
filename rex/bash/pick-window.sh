#!/usr/bin/env bash
# fzf window (tab) picker, run inside a floating layer by the pick_window action.
# rows and actions are in pick/tabs.lua
# usage: pick-window.sh <client_id> <origin_session_id> <origin_block_id> <origin_zoomed>
set -euo pipefail

scripts="${BASH_SOURCE%/*}"
# shellcheck source=/dev/null
source "$scripts/_lib.sh"

picker_start "$1" "$2" "$3" "$4"
rows=$(pick cmd=tabs.list)
wait_for_resize

list="rex do $PICK_LUA cmd=tabs.list"
action="$scripts/pick-action.sh"
picker_fzf_opts 'j,k,g,G,q,space,a,r,x,u' \
    'j/k ↓/↑ · g/G top/bottom · spc/⏎ sel · / srch · a all · r rename · x kill · u undo · q/esc'

# ": " lists this session's windows, "* " every session's; reloads keep the mode
reload="transform:[[ \$FZF_PROMPT == \"* \" ]] && echo \"reload-sync($list all=1)\" || echo \"reload-sync($list)\""

# rows are window_id, block_id to preview, session_id, display
selected=$(
    printf '%s\n' "$rows" |
        fzf "${PICKER_FZF_OPTS[@]}" --header-lines="$(header_count "$rows")" --with-nth=4 \
            --preview "rex do $PICK_LUA cmd=preview session={3} block={2}" \
            --bind 'change:transform:[[ $FZF_PROMPT == ": " || $FZF_PROMPT == "* " ]] && echo "clear-query"' \
            --bind "a:transform:[[ \$FZF_PROMPT == \": \" ]] && echo \"change-prompt(* )+reload-sync($list all=1)\" || echo \"change-prompt(: )+reload-sync($list)\"" \
            --bind "r:execute($action rename tabs session={3} window={1})+$reload" \
            --bind "x:execute($action kill tabs session={3} window={1})+$reload" \
            --bind "u:execute-silent(rex do $PICK_LUA cmd=tabs.undo)+$reload" |
        cut -f1,3
) || exit 0

[[ -n "$selected" ]] || exit 0
trap - EXIT
pick cmd=tabs.select session="${selected#*$'\t'}" window="${selected%%$'\t'*}"
