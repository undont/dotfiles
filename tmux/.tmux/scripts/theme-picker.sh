#!/bin/bash
# shellcheck disable=SC2155,SC2059
set -euo pipefail

# ══════════════════════════════════════════════════════════════
# Tmux Theme Picker (fzf)
# ══════════════════════════════════════════════════════════════
# Interactive theme selector using fzf
# Called from tmux keybinding: prefix + t

# Find dotfiles root by looking for themes directory
# Start from script location and walk up until we find it
find_dotfiles_root() {
    local dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
    while [[ "$dir" != "/" ]]; do
        if [[ -d "$dir/themes" ]]; then
            echo "$dir"
            return 0
        fi
        dir="$(dirname "$dir")"
    done
    # Fallback to standard location
    echo "$HOME/dotfiles"
}

DOTFILES_ROOT="$(find_dotfiles_root)"

# Source colour definitions
# shellcheck source=scripts/_lib/colours.sh
source "$DOTFILES_ROOT/scripts/_lib/colours.sh"

# Load current theme colours for fzf
if [[ -f "$DOTFILES_ROOT/scripts/fzf-theme.sh" ]]; then
    # shellcheck disable=SC1091
    source "$DOTFILES_ROOT/scripts/fzf-theme.sh" 2>/dev/null || true
fi
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

# Main
main() {
    list_themes_for_fzf
}

main "$@"
