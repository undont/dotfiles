#!/usr/bin/env bash
# shellcheck disable=SC2016,SC2155
set -euo pipefail

# ══════════════════════════════════════════════════════════════
# Launcher Picker Wrapper
# ══════════════════════════════════════════════════════════════
# Runs the launcher picker in a loop so that pressing Esc in a
# submenu (new/edit/run) returns to the main picker list.
# Called from tmux keybinding: prefix + p

SCRIPT_DIR="${BASH_SOURCE%/*}"

# shellcheck source=tmux/scripts/_lib/common.sh
source "$SCRIPT_DIR/../_lib/common.sh"

# Load current theme colours for fzf
load_fzf_theme
require_fzf

main() {
    while true; do
        local action
        action=$("$SCRIPT_DIR/list.sh" | fzf \
            --ansi --reverse --disabled --cycle \
            --color="label:${TMUX_FG_PRIMARY:-#ffffff}" \
            --header-lines=7 \
            --padding=0,0,1,0 \
            --prompt=': ' \
            --border=rounded \
            --border-label=' j/k · ^d/^u · g/G · spc/⏎ sel · / srch · n new · e edit · x del · s set · q/esc ' \
            --border-label-pos=bottom \
            --bind 'j:down,k:up,g:first,G:last,ctrl-d:half-page-down,ctrl-u:half-page-up,q:abort' \
            --bind 'change:transform:[[ $FZF_PROMPT == ": " ]] && echo "clear-query"' \
            --bind '/:enable-search+change-prompt(> )+unbind(j,k,g,G,ctrl-d,ctrl-u,q,n,e,x,s)' \
            --bind 'esc:transform:[[ $FZF_PROMPT == "> " ]] && echo "disable-search+clear-query+change-prompt(: )+rebind(j,k,g,G,ctrl-d,ctrl-u,q,n,e,x,s)" || echo "abort"' \
            --bind 'ctrl-k:kill-line,ctrl-w:unix-line-discard' \
            --bind 'n:become(printf "ACTION:new")' \
            --bind 's:become(printf "ACTION:set")' \
            --bind 'e:become(printf "ACTION:edit:%s" {1})' \
            --bind "x:execute($SCRIPT_DIR/delete.sh {1})+reload-sync($SCRIPT_DIR/list.sh)" \
            --bind 'enter:become(printf "ACTION:run:%s" {1})' \
            --bind 'space:become(printf "ACTION:run:%s" {1})' \
            2>/dev/null) || break  # q/esc from main list → close popup

        case "$action" in
            ACTION:new)
                "$SCRIPT_DIR/prompt.sh" && break
                continue  # cancelled → back to picker
                ;;
            ACTION:set)
                "$SCRIPT_DIR/settings.sh" || true
                continue  # always return to picker
                ;;
            ACTION:edit:*)
                local edit_name="${action#ACTION:edit:}"
                edit_name=$(basename "$edit_name")
                # Only user launchers can be edited — system launchers are read-only
                if [[ ! -f "$USER_LAUNCHERS/$edit_name" ]]; then
                    show_error "Cannot edit system launcher '$edit_name'"
                    continue
                fi
                "$SCRIPT_DIR/prompt.sh" --edit "$edit_name" && break
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
