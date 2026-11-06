#!/usr/bin/env bash
# shellcheck disable=SC2155,SC2059
set -euo pipefail

# ══════════════════════════════════════════════════════════════
# tmux launcher list provider
# ══════════════════════════════════════════════════════════════
# lists available session launchers with descriptions and status.
# tab-delimited output; called from picker.sh to feed fzf

SCRIPT_DIR="${BASH_SOURCE%/*}"

# shellcheck source=launchers/lib/data.sh
source "$SCRIPT_DIR/../lib/data.sh"

load_fzf_theme

# argument parsing
SHOW_LOGO=1
for arg in "$@"; do
    case "$arg" in
        --no-logo) SHOW_LOGO=0 ;;
    esac
done

# check whether a newline-delimited list contains an exact entry
contains_line() {
    local needle="$1"
    local haystack="$2"
    while IFS= read -r line; do
        [[ "$line" == "$needle" ]] && return 0
    done <<<"$haystack"
    return 1
}

# list launchers in fzf-compatible format, sorted by most recently used
list_launchers_for_fzf() {
    # header (consumed by fzf --header-lines)
    # prefix with tab so --with-nth=2 in picker.sh still displays the logo
    if ((SHOW_LOGO)); then
        local logo_line
        while IFS= read -r logo_line; do
            printf '\t%s\n' "$logo_line"
        done < <(print_dotfiles_logo)
    fi

    # collect all launchers in memory as name|description|source
    local all_launchers="" seen_names=""

    collect_launcher() {
        local name="$1" description="$2" source="$3"
        [[ -n "$description" ]] || return 0
        all_launchers+="${name}|${description}|${source}"$'\n'
        seen_names+="${name}"$'\n'
    }

    # user launchers first (they take priority on name collision)
    local name description
    while IFS=$'\t' read -r name description; do
        collect_launcher "$name" "$description" user
    done < <(launcher_field "$USER_LAUNCHERS" description)

    # repo launchers, unless a user launcher has the name
    while IFS=$'\t' read -r name description; do
        contains_line "$name" "$seen_names" && continue
        collect_launcher "$name" "$description" system
    done < <(launcher_field "$DOTFILES_LAUNCHERS" description)

    # build MRU list from history (most recent first, deduplicated)
    local mru_list="" history_lines=()
    if [[ -f "$LAUNCHER_HISTORY" ]] && [[ -s "$LAUNCHER_HISTORY" ]]; then
        local hist_line idx
        while IFS= read -r hist_line; do
            [[ -n "$hist_line" ]] || continue
            history_lines+=("$hist_line")
        done <"$LAUNCHER_HISTORY"

        for ((idx = ${#history_lines[@]} - 1; idx >= 0; idx--)); do
            hist_line="${history_lines[$idx]}"
            contains_line "$hist_line" "$mru_list" && continue
            mru_list+="${hist_line}"$'\n'
        done
    fi

    local outputted=""

    # output MRU launchers first
    while IFS= read -r hist_name; do
        [[ -n "$hist_name" ]] || continue
        local entry="" scan_entry
        while IFS= read -r scan_entry; do
            [[ "$scan_entry" == "$hist_name|"* ]] || continue
            entry="$scan_entry"
            break
        done <<<"$all_launchers"
        [[ -n "$entry" ]] || continue

        # parse entry: name|description|source
        local name desc source suffix=""
        IFS='|' read -r name desc source <<<"$entry"

        if [[ "$source" == "user" ]]; then
            suffix=" ${GREY}(user)${NC}"
        elif [[ "$source" == "system" ]]; then
            suffix=" ${GREY}(system)${NC}"
        fi

        printf "%s\t    %-16s ${GREY}%s${NC}%s\n" "$name" "$name" "$desc" "$suffix"
        outputted+="${name}"$'\n'
    done <<<"$mru_list"

    # output remaining launchers alphabetically
    local remaining=""
    while IFS='|' read -r name desc source; do
        [[ -n "$name" ]] || continue
        contains_line "$name" "$outputted" && continue
        remaining+="${name}|${desc}|${source}"$'\n'
    done <<<"$all_launchers"

    while IFS='|' read -r name desc source; do
        [[ -n "$name" ]] || continue

        local suffix=""
        if [[ "$source" == "user" ]]; then
            suffix=" ${GREY}(user)${NC}"
        elif [[ "$source" == "system" ]]; then
            suffix=" ${GREY}(system)${NC}"
        fi

        printf "%s\t    %-16s ${GREY}%s${NC}%s\n" "$name" "$name" "$desc" "$suffix"
    done < <(printf '%s' "$remaining" | sort)
}

main() {
    list_launchers_for_fzf
}

main "$@"
