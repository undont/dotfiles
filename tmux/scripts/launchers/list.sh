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

# List launchers in fzf-compatible format
list_launchers_for_fzf() {
    # Header (consumed by fzf --header-lines)
    print_dotfiles_logo

    # Collect launchers: user dir overrides repo by filename
    local seen_names=""

    # Helper: output a single launcher entry
    # Usage: output_launcher <file> [system]
    output_launcher() {
        local file="$1"
        local source="${2:-}"
        local name description suffix=""

        name=$(basename "$file")

        # Extract @description tag
        description=$(grep -m1 '# @description:' "$file" 2>/dev/null | sed 's/.*# @description: *//' || true)
        [[ -n "$description" ]] || return 0

        if [[ "$source" == "user" ]]; then
            suffix=" ${GREY}(user)${NC}"
        elif [[ "$source" == "system" ]]; then
            suffix=" ${GREY}(system)${NC}"
        fi

        printf "    %-16s ${GREY}%s${NC}%s\n" "$name" "$description" "$suffix"
    }

    # User launchers first (they take priority)
    if [[ -d "$USER_LAUNCHERS" ]]; then
        for file in "$USER_LAUNCHERS"/*; do
            [[ -f "$file" ]] || continue
            [[ -x "$file" ]] || continue
            [[ "$file" != *.template ]] || continue
            local name
            name=$(basename "$file")
            seen_names="${seen_names}:${name}:"
            output_launcher "$file" "user"
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
            [[ "$seen_names" != *":${name}:"* ]] || continue
            output_launcher "$file" "system"
        done
    fi
}

# Main
main() {
    list_launchers_for_fzf
}

main "$@"
