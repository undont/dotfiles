#!/usr/bin/env bash
# shellcheck disable=SC2016,SC2155
set -euo pipefail

# ══════════════════════════════════════════════════════════════
# launcher picker wrapper
# ══════════════════════════════════════════════════════════════
# runs the launcher picker in a loop so that pressing Esc in a
# submenu (new/edit/run) returns to the main picker list
# called from tmux keybinding: prefix + p

SCRIPT_DIR="${BASH_SOURCE%/*}"

# shellcheck source=tmux/scripts/_lib/common.sh
source "$SCRIPT_DIR/../_lib/common.sh"

load_fzf_theme
require_fzf

# argument parsing + auto-detection
#
# the dotfiles ASCII logo is dropped when the popup is too narrow or too short
# to leave room for launcher rows. the size is read from the popup pty via
# `stty size`, since env vars from the parent shell may not match the popup.
# the width threshold matches the session picker's `<80(bottom,40%)`
# vertical-preview threshold, so both pickers compact at the same size.
# `--no-logo` forces it off regardless
LIST_ARGS=()
HEADER_LINES=7
NO_LOGO=0

for arg in "$@"; do
    case "$arg" in
        --no-logo) NO_LOGO=1 ;;
    esac
done

if ((!NO_LOGO)); then
    popup_height=24
    popup_width=80
    read -r popup_height popup_width < <(stty size 2>/dev/null) || true
    if ((popup_width < 80)) || ((popup_height < 20)); then
        NO_LOGO=1
    fi
fi

if ((NO_LOGO)); then
    LIST_ARGS+=(--no-logo)
    HEADER_LINES=0
fi

main() {
    local select_name="" save_result
    save_result=$(mktemp)
    # shellcheck disable=SC2064  # expand now: the path is fixed for this run
    trap "rm -f '$save_result'" EXIT

    while true; do
        local action list select_bind=()
        list=$("$SCRIPT_DIR/list.sh" "${LIST_ARGS[@]}")

        # after a save, start on the launcher just written (fzf positions
        # count from the first row below the header lines)
        if [[ -n "$select_name" ]]; then
            local select_pos
            select_pos=$(printf '%s\n' "$list" | tail -n +$((HEADER_LINES + 1)) |
                awk -F'\t' -v name="$select_name" '$1 == name { print NR; exit }')
            [[ -n "$select_pos" ]] && select_bind=(--bind "load:pos($select_pos)+unbind(load)")
            select_name=""
        fi

        action=$(printf '%s\n' "$list" | fzf \
            --ansi --reverse --exact --disabled --cycle \
            --delimiter=$'\t' --with-nth=2 --tiebreak=begin,length \
            --color="label:${TMUX_FG_PRIMARY:-#ffffff}" \
            --header-lines="$HEADER_LINES" \
            --padding=0,0,1,0 \
            --prompt=': ' \
            --border=rounded \
            --border-label=' j/k · d/u · g/G · spc/⏎ sel · / search · n new · s save · e edit · D dup · x del · S set · q/esc ' \
            --border-label-pos=bottom \
            --bind 'j:down,k:up,g:first,G:last,d:half-page-down,u:half-page-up,q:abort' \
            --bind 'change:transform:[[ $FZF_PROMPT == ": " ]] && echo "clear-query"' \
            --bind '/:enable-search+change-prompt(> )+unbind(j,k,g,G,d,u,q,n,e,x,s,S,D)' \
            --bind 'esc:transform:[[ $FZF_PROMPT == "> " ]] && echo "disable-search+clear-query+change-prompt(: )+rebind(j,k,g,G,d,u,q,n,e,x,s,S,D)" || echo "abort"' \
            --bind 'ctrl-k:up,ctrl-l:clear-query' \
            --bind 'n:become(printf "ACTION:new")' \
            --bind 's:become(printf "ACTION:save")' \
            --bind 'S:become(printf "ACTION:set")' \
            --bind 'e:become(printf "ACTION:edit:%s" {1})' \
            --bind "x:execute($SCRIPT_DIR/delete.sh {1})+reload-sync($SCRIPT_DIR/list.sh ${LIST_ARGS[*]})" \
            --bind "D:become(printf 'ACTION:dup:%s' \$($SCRIPT_DIR/duplicate.sh {1}))" \
            --bind 'enter:become(printf "ACTION:run:%s" {1})' \
            --bind 'space:become(printf "ACTION:run:%s" {1})' \
            "${select_bind[@]}" \
            2>/dev/null) || break # q/esc from main list closes popup

        case "$action" in
            ACTION:new)
                "$SCRIPT_DIR/prompt.sh" && break
                continue # cancelled, back to picker
                ;;
            ACTION:save)
                # saves the session the popup was opened from, then returns to
                # the picker with the new launcher selected
                : >"$save_result"
                SAVE_RESULT_FILE="$save_result" "$SCRIPT_DIR/save.sh" || true
                select_name=$(cat "$save_result")
                continue
                ;;
            ACTION:set)
                "$SCRIPT_DIR/settings.sh" || true
                continue # always return to picker
                ;;
            ACTION:edit:*)
                local edit_name="${action#ACTION:edit:}"
                edit_name=$(basename "$edit_name")
                # only user launchers can be edited, system launchers are read-only
                if [[ ! -f "$USER_LAUNCHERS/$edit_name" ]]; then
                    show_error "Cannot edit system launcher '$edit_name'"
                    continue
                fi
                "$SCRIPT_DIR/prompt.sh" --edit "$edit_name" && break
                continue
                ;;
            ACTION:dup:*)
                local dup_name="${action#ACTION:dup:}"
                dup_name=$(basename "$dup_name")
                "$SCRIPT_DIR/prompt.sh" --edit "$dup_name" && break
                # cancelled, clean up the copy and return to picker
                rm -f "$USER_LAUNCHERS/$dup_name"
                continue
                ;;
            ACTION:run:*)
                "$SCRIPT_DIR/run.sh" "${action#ACTION:run:}" && break
                continue
                ;;
            *)
                break
                ;;
        esac
    done
}

main "$@"
