#!/usr/bin/env bash
# shellcheck disable=SC2155,SC2059
set -euo pipefail

# ══════════════════════════════════════════════════════════════
# Tmux Launcher Picker (fzf)
# ══════════════════════════════════════════════════════════════
# Lists available session launchers with descriptions and status
# Called from tmux keybinding: prefix + p

SCRIPT_DIR="${BASH_SOURCE%/*}"

# shellcheck source=tmux/scripts/_lib/common.sh
source "$SCRIPT_DIR/../_lib/common.sh"

# Load current theme colours for fzf
load_fzf_theme

# List launchers in fzf-compatible format, sorted by most recently used
list_launchers_for_fzf() {
    # Header (consumed by fzf --header-lines)
    print_dotfiles_logo

    # Collect all launchers into temporary files (Bash 3.2 compatible)
    # Format: name|description|source
    local tmpdir
    tmpdir=$(mktemp -d)

    local all_launchers="$tmpdir/all"
    local seen_names="$tmpdir/seen"
    touch "$all_launchers" "$seen_names"

    # Helper: collect a single launcher entry
    collect_launcher() {
        local file="$1"
        local source="${2:-}"
        local name description

        name=$(basename "$file")

        # Extract @description tag
        description=$(grep -m1 '# @description:' "$file" 2>/dev/null | sed 's/.*# @description: *//' || true)
        [[ -n "$description" ]] || return 0

        # Store: name|description|source
        printf '%s|%s|%s\n' "$name" "$description" "$source" >> "$all_launchers"
        printf '%s\n' "$name" >> "$seen_names"
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
            grep -qxF "$name" "$seen_names" 2>/dev/null && continue
            collect_launcher "$file" "system"
        done
    fi

    # Build MRU list from history (most recent first, deduplicated)
    local mru_file="$tmpdir/mru"
    touch "$mru_file"
    if [[ -f "$LAUNCHER_HISTORY" ]]; then
        awk '{ lines[NR] = $0; count = NR } END { for (i = count; i >= 1; i--) print lines[i] }' "$LAUNCHER_HISTORY" \
            | awk '!seen[$0]++' > "$mru_file"
    fi

    # Track which launchers have been output
    local outputted="$tmpdir/outputted"
    touch "$outputted"

    # Output MRU launchers first
    while IFS= read -r hist_name; do
        [[ -n "$hist_name" ]] || continue
        # Find this launcher in all_launchers
        local entry
        entry=$(grep -m1 "^${hist_name}|" "$all_launchers" 2>/dev/null || true)
        [[ -n "$entry" ]] || continue

        # Parse entry: name|description|source
        local name desc source suffix=""
        name=$(printf '%s' "$entry" | cut -d'|' -f1)
        desc=$(printf '%s' "$entry" | cut -d'|' -f2)
        source=$(printf '%s' "$entry" | cut -d'|' -f3)

        if [[ "$source" == "user" ]]; then
            suffix=" ${GREY}(user)${NC}"
        elif [[ "$source" == "system" ]]; then
            suffix=" ${GREY}(system)${NC}"
        fi

        printf "    %-16s ${GREY}%s${NC}%s\n" "$name" "$desc" "$suffix"
        printf '%s\n' "$name" >> "$outputted"
    done < "$mru_file"

    # Output remaining launchers alphabetically
    local remaining="$tmpdir/remaining"
    touch "$remaining"
    while IFS='|' read -r name desc source; do
        [[ -n "$name" ]] || continue
        # Skip if already output
        grep -qxF "$name" "$outputted" 2>/dev/null && continue
        printf '%s|%s|%s\n' "$name" "$desc" "$source" >> "$remaining"
    done < "$all_launchers"

    # Sort and output remaining
    while IFS='|' read -r name desc source; do
        [[ -n "$name" ]] || continue

        local suffix=""
        if [[ "$source" == "user" ]]; then
            suffix=" ${GREY}(user)${NC}"
        elif [[ "$source" == "system" ]]; then
            suffix=" ${GREY}(system)${NC}"
        fi

        printf "    %-16s ${GREY}%s${NC}%s\n" "$name" "$desc" "$suffix"
    done < <(sort "$remaining")

    # Cleanup
    rm -rf "$tmpdir"
}

# Main
main() {
    list_launchers_for_fzf
}

main "$@"
