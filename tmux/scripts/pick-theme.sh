#!/usr/bin/env bash
# shellcheck disable=SC2155,SC2059
set -euo pipefail

# ══════════════════════════════════════════════════════════════
# Tmux Theme Picker (fzf)
# ══════════════════════════════════════════════════════════════
# Interactive theme selector using fzf
# Called from tmux keybinding: prefix + t

SCRIPT_DIR="${BASH_SOURCE%/*}"

# shellcheck source=tmux/scripts/_lib/common.sh
source "$SCRIPT_DIR/_lib/common.sh"

# Load current theme colours for fzf
load_fzf_theme
THEMES_DIR="$DOTFILES_ROOT/themes"
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/dotfiles"
CURRENT_THEME_FILE="$CONFIG_DIR/current-theme"

# Get current theme
get_current_theme() {
    if [[ -f "$CURRENT_THEME_FILE" ]]; then
        cat "$CURRENT_THEME_FILE"
    else
        echo "dracula"
    fi
}

# List themes in fzf-compatible format
list_themes_for_fzf() {
    local current_theme
    current_theme=$(get_current_theme)

    # Header
    printf "${CYAN}╭─────────────────────────────────────────────────────────────╮${NC}\n"
    printf "${CYAN}│${NC}  ${GREEN}Theme Switcher${NC}                                            ${CYAN}│${NC}\n"
    printf "${CYAN}│${NC}  Select a theme to apply to tmux and ghostty               ${CYAN}│${NC}\n"
    printf "${CYAN}╰─────────────────────────────────────────────────────────────╯${NC}\n"
    printf "\n"

    # List themes
    for theme_file in "$THEMES_DIR"/*.theme; do
        if [[ -f "$theme_file" ]]; then
            local theme_id
            theme_id=$(basename "$theme_file" .theme)

            # Source theme to get display name
            # shellcheck disable=SC1090
            source "$theme_file"

            # Mark current theme
            local marker=""
            if [[ "$theme_id" == "$current_theme" ]]; then
                marker="${GREEN}● ${NC}"
            else
                marker="${GREY}○ ${NC}"
            fi

            # Format: theme-id first (for easy parsing), then marker and display name
            printf "%-20s %b${CYAN}%s${NC}\n" "$theme_id" "$marker" "$THEME_NAME"
        fi
    done
}

# Get 1-based position of current theme in the list
get_current_position() {
    local current_theme
    current_theme=$(get_current_theme)
    local pos=1
    for theme_file in "$THEMES_DIR"/*.theme; do
        if [[ -f "$theme_file" ]]; then
            local theme_id
            theme_id=$(basename "$theme_file" .theme)
            if [[ "$theme_id" == "$current_theme" ]]; then
                echo "$pos"
                return
            fi
            ((pos++))
        fi
    done
    echo "1"
}

# Main
main() {
    if [[ "${1:-}" == "--pos" ]]; then
        get_current_position
    else
        list_themes_for_fzf
    fi
}

main "$@"
