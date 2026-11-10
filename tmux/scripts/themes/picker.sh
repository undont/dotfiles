#!/usr/bin/env bash
# shellcheck disable=SC2016,SC2155
set -euo pipefail

# ══════════════════════════════════════════════════════════════
# theme picker wrapper
# ══════════════════════════════════════════════════════════════
# interactive theme selector using fzf with vim-style navigation.
# called from tmux keybinding: prefix + t, and from rex's `>t picker

SCRIPT_DIR="${BASH_SOURCE%/*}"

# shellcheck source=tmux/scripts/_lib/common.sh
source "$SCRIPT_DIR/../_lib/common.sh"

load_fzf_theme
require_fzf

main() {
    local theme_list theme_pos
    theme_list=$("$SCRIPT_DIR/pick.sh")
    theme_pos=1
    local line idx=0
    while IFS= read -r line; do
        idx=$((idx + 1))
        case "$line" in
            *'● '*)
                theme_pos=$idx
                break
                ;;
        esac
    done <<<"$theme_list"

    # a transformed header, not header lines in the list: --with-nth would cut
    # each header line's first field. fzf indents the header by 2, so the pad
    # that centres the 63-wide box is (FZF_COLUMNS - 63) / 2 - 2
    THEME_PICKER_HEADER=$(
        printf "${CYAN}╭─────────────────────────────────────────────────────────────╮${NC}\n"
        printf "${CYAN}│${NC}  ${GREEN}Theme Switcher${NC}                                             ${CYAN}│${NC}\n"
        printf "${CYAN}│${NC}  Select a theme to apply to tmux, ghostty and rex           ${CYAN}│${NC}\n"
        printf "${CYAN}╰─────────────────────────────────────────────────────────────╯${NC}\n"
    )
    export THEME_PICKER_HEADER
    local centre_header
    centre_header='printf "%s\n" "$THEME_PICKER_HEADER" | awk -v w="$FZF_COLUMNS" '\''
        BEGIN { pad = int((w - 63) / 2) - 2; if (pad < 0) pad = 0 }
        { printf "%*s%s\n", pad, "", $0 }
        END { print " " }'\'

    local selected
    selected=$(echo "$theme_list" | fzf \
        --ansi --reverse --exact --disabled --cycle \
        --with-nth=2.. \
        --info=inline-right \
        --bind "start:clear-query+execute-silent(rm -f /tmp/.fzf-theme-pos)+transform-header:$centre_header" \
        --bind "resize:transform-header:$centre_header" \
        --bind "load:pos($theme_pos)" \
        --bind 'result:transform:[[ -f /tmp/.fzf-theme-pos ]] && { echo "clear-query+$(cat /tmp/.fzf-theme-pos)"; rm -f /tmp/.fzf-theme-pos; } || true' \
        --padding=0,0,1,0 \
        --prompt ': ' \
        --border=rounded \
        --border-label=' j/k · d/u · g/G · f fav · r rand · spc/⏎ sel · / srch · q/esc ' \
        --border-label-pos=bottom \
        --bind 'j:down,k:up,g:first,G:last,d:half-page-down,u:half-page-up,q:abort,space:accept' \
        --bind 'enter:accept' \
        --bind 'change:transform:[[ $FZF_PROMPT == ": " ]] && echo "clear-query"' \
        --bind "f:execute-silent($SCRIPT_DIR/pick.sh --toggle-fav {1})+reload-sync($SCRIPT_DIR/pick.sh --reload {1})" \
        --bind "r:become(echo random)" \
        --bind '/:enable-search+change-prompt(> )+unbind(j,k,g,G,d,u,q,space,f,r)' \
        --bind 'esc:transform:[[ $FZF_PROMPT == "> " ]] && echo "disable-search+clear-query+change-prompt(: )+rebind(j,k,g,G,d,u,q,space,f,r)" || echo "abort"' \
        --bind 'ctrl-k:up,ctrl-l:clear-query' \
        2>/dev/null) || return 0

    local theme="${selected%% *}"
    [[ -n "$theme" ]] || return 0

    "$DOTFILES_ROOT/scripts/theme-switch" "$theme" --quiet || return 0
    theme=$(cat "${XDG_CONFIG_HOME:-$HOME/.config}/dotfiles/current-theme")
    [[ -n "${TMUX:-}" ]] && tmux display-message "Theme: $theme"
    return 0
}

main "$@"
