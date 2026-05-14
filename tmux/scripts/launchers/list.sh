#!/usr/bin/env bash
# shellcheck disable=SC2155,SC2059
set -euo pipefail

# ══════════════════════════════════════════════════════════════
# Tmux Launcher List Provider
# ══════════════════════════════════════════════════════════════
# Lists available session launchers with descriptions and status.
# Tab-delimited output; called from picker.sh to feed fzf.

SCRIPT_DIR="${BASH_SOURCE%/*}"

# shellcheck source=tmux/scripts/_lib/common.sh
source "$SCRIPT_DIR/../_lib/common.sh"

# Load current theme colours for fzf
load_fzf_theme

# Check whether a newline-delimited list contains an exact entry.
contains_line() {
    local needle="$1"
    local haystack="$2"
    while IFS= read -r line; do
        [[ "$line" == "$needle" ]] && return 0
    done <<< "$haystack"
    return 1
}

# Extract the first description tag from a launcher file.
extract_description() {
    local file="$1"
    local line
    while IFS= read -r line; do
        case "$line" in
            ("# @description:"*)
                line="${line#"# @description:"}"
                line="${line#"${line%%[![:space:]]*}"}"
                printf '%s\n' "$line"
                return 0
                ;;
        esac
    done < "$file"
    return 1
}

# List launchers in fzf-compatible format, sorted by most recently used
list_launchers_for_fzf() {
    # Header (consumed by fzf --header-lines)
    # Prefix with tab so --with-nth=2 in picker.sh still displays the logo
    local logo_line
    while IFS= read -r logo_line; do
        printf '\t%s\n' "$logo_line"
    done < <(print_dotfiles_logo)

    # Collect all launchers in memory.
    # Format: name|description|source
    local all_launchers="" seen_names=""

    # Helper: collect a single launcher entry
    collect_launcher() {
        local file="$1"
        local source="${2:-}"
        local name description

        name=$(basename "$file")

        # Extract @description tag
        description=$(extract_description "$file" || true)
        [[ -n "$description" ]] || return 0

        # Store: name|description|source
        all_launchers+="${name}|${description}|${source}"$'\n'
        seen_names+="${name}"$'\n'
    }

    # User launchers first (they take priority on name collision)
    if [[ -d "$USER_LAUNCHERS" ]]; then
        for file in "$USER_LAUNCHERS"/*; do
            [[ -f "$file" ]] || continue
            [[ -x "$file" ]] || continue
            [[ "$file" != *.template ]] || continue
            collect_launcher "$file" "user"
        done
    fi

    # Repo launchers (skip if overridden by user)
    if [[ -d "$DOTFILES_LAUNCHERS" ]]; then
        for file in "$DOTFILES_LAUNCHERS"/*; do
            [[ -f "$file" ]] || continue
            [[ -x "$file" ]] || continue
            [[ "$file" != *.template ]] || continue
            local name
            name=$(basename "$file")
            # Skip if already seen (user override)
            contains_line "$name" "$seen_names" && continue
            collect_launcher "$file" "system"
        done
    fi

    # Build MRU list from history (most recent first, deduplicated)
    local mru_list="" history_lines=()
    if [[ -f "$LAUNCHER_HISTORY" ]] && [[ -s "$LAUNCHER_HISTORY" ]]; then
        local hist_line idx
        while IFS= read -r hist_line; do
            [[ -n "$hist_line" ]] || continue
            history_lines+=("$hist_line")
        done < "$LAUNCHER_HISTORY"

        for (( idx=${#history_lines[@]}-1; idx>=0; idx-- )); do
            hist_line="${history_lines[$idx]}"
            contains_line "$hist_line" "$mru_list" && continue
            mru_list+="${hist_line}"$'\n'
        done
    fi

    # Track which launchers have been output
    local outputted=""

    # Output MRU launchers first
    while IFS= read -r hist_name; do
        [[ -n "$hist_name" ]] || continue
        # Find this launcher in all_launchers
        local entry="" scan_entry
        while IFS= read -r scan_entry; do
            [[ "$scan_entry" == "$hist_name|"* ]] || continue
            entry="$scan_entry"
            break
        done <<< "$all_launchers"
        [[ -n "$entry" ]] || continue

        # Parse entry: name|description|source
        local name desc source suffix=""
        IFS='|' read -r name desc source <<< "$entry"

        if [[ "$source" == "user" ]]; then
            suffix=" ${GREY}(user)${NC}"
        elif [[ "$source" == "system" ]]; then
            suffix=" ${GREY}(system)${NC}"
        fi

        printf "%s\t    %-16s ${GREY}%s${NC}%s\n" "$name" "$name" "$desc" "$suffix"
        outputted+="${name}"$'\n'
    done <<< "$mru_list"

    # Output remaining launchers alphabetically
    local remaining=""
    while IFS='|' read -r name desc source; do
        [[ -n "$name" ]] || continue
        # Skip if already output
        contains_line "$name" "$outputted" && continue
        remaining+="${name}|${desc}|${source}"$'\n'
    done <<< "$all_launchers"

    # Sort and output remaining
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

# Main
main() {
    list_launchers_for_fzf
}

main "$@"
