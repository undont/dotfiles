#!/usr/bin/env bash
# the picker actions that prompt, run from fzf bindings in the picker's
# terminal: the prompt runs here, the action in pick.lua
# usage: pick-action.sh kill sessions|tabs|panes KEY=VALUE...
#        pick-action.sh rename sessions|tabs KEY=VALUE...
#        pick-action.sh new-session
set -euo pipefail

# shellcheck source=/dev/null
source "${BASH_SOURCE%/*}/_lib.sh"

# kill checks print "ask" or "deny", a tab, then the message
cmd_kill() {
    local module="$1" title verdict message
    shift
    case "$module" in
    sessions) title="Kill Session" ;;
    tabs) title="Kill Tab" ;;
    panes) title="Kill Agent" ;;
    esac
    IFS=$'\t' read -r verdict message <<<"$(pick cmd="$module.kill_check" "$@")" || true
    [[ -n "$verdict" ]] || exit 0
    if [[ "$verdict" == deny ]]; then
        show_visual_confirm "$title" "$message" || true
        exit 0
    fi
    show_visual_confirm "$title" "$message" || exit 0
    pick cmd="$module.kill" "$@"
}

# a session needs a name; clearing a tab's name restores rex's placeholder
cmd_rename() {
    local module="$1" what current name
    shift
    what=session
    [[ "$module" == tabs ]] && what=tab
    current=$(pick cmd="$module.label" "$@")
    name=$(prompt_name "Rename $what: " "$current" '⏎ rename · esc cancel') || exit 0
    [[ "$name" != "$current" ]] || exit 0
    [[ -n "$name" || "$module" == tabs ]] || exit 0
    PICK_NAME="$name" pick cmd="$module.rename" "$@"
}

cmd_new_session() {
    local name
    name=$(prompt_name 'New session: ' '' '⏎ create · esc cancel') || exit 0
    [[ -n "$name" ]] || exit 0
    PICK_NAME="$name" pick cmd=sessions.new
}

case "${1:-}" in
kill) cmd_kill "${@:2}" ;;
rename) cmd_rename "${@:2}" ;;
new-session) cmd_new_session ;;
*)
    printf 'usage: %s kill MODULE ARGS | rename MODULE ARGS | new-session\n' "${0##*/}" >&2
    exit 2
    ;;
esac
