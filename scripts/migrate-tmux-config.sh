#!/bin/bash
# shellcheck disable=SC2059,SC2032,SC2033
set -euo pipefail

# ══════════════════════════════════════════════════════════════
# Migrate Tmux Configuration to XDG Standard Location
# ══════════════════════════════════════════════════════════════
# This script migrates from the old setup (tmux/.tmux.conf in repo)
# to the new XDG setup (~/.config/tmux/tmux.conf).

SCRIPT_DIR="${BASH_SOURCE%/*}"
DOTFILES_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Colours
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

error() {
    printf "${RED}✗${NC} %s\n" "$1" >&2
}

success() {
    printf "${GREEN}✓${NC} %s\n" "$1"
}

info() {
    printf "${CYAN}•${NC} %s\n" "$1"
}

warn() {
    printf "${YELLOW}!${NC} %s\n" "$1"
}

print_header() {
    printf "\n${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
    printf "${CYAN}%s${NC}\n" "$1"
    printf "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n\n"
}

main() {
    print_header "Tmux Configuration Migration"

    info "This script will:"
    echo "  1. Remove old symlink from ~/.tmux.conf -> dotfiles/tmux/tmux.conf"
    echo "  2. Generate themed config in XDG location (~/.config/tmux/tmux.conf)"
    echo "  3. Create compatibility symlink ~/.tmux.conf -> ~/.config/tmux/tmux.conf"
    echo "  4. Keep tmux/tmux.conf.template as source template in repo"
    echo ""

    # Check if user is on old setup
    if [[ -L "$HOME/.tmux.conf" ]]; then
        local link_target
        link_target=$(readlink "$HOME/.tmux.conf")
        
        if [[ "$link_target" == *"dotfiles/tmux/.tmux.conf" ]]; then
            info "Detected old symlink setup"
        else
            warn "$HOME/.tmux.conf points to unexpected location: $link_target"
            printf "Continue anyway? [y/N] "
            read -r response
            [[ "$response" =~ ^[Yy]$ ]] || exit 0
        fi
    elif [[ -f "$HOME/.tmux.conf" ]]; then
        warn "$HOME/.tmux.conf exists but is not a symlink"
        warn "This file will be backed up and replaced with a symlink"
        printf "Continue? [y/N] "
        read -r response
        [[ "$response" =~ ^[Yy]$ ]] || exit 0
    fi

    # Step 1: Remove old symlink/file
    echo ""
    info "Step 1: Removing old configuration"
    
    if [[ -e "$HOME/.tmux.conf" ]]; then
        if [[ -L "$HOME/.tmux.conf" ]]; then
            rm "$HOME/.tmux.conf"
            success "Removed old symlink"
        else
            # Backup regular file
            local backup
            backup="$HOME/.tmux.conf.backup-$(date +%Y%m%d-%H%M%S)"
            mv "$HOME/.tmux.conf" "$backup"
            success "Backed up to $backup"
        fi
    fi

    # Step 2: Generate themed config in XDG location
    echo ""
    info "Step 2: Generating themed configuration"
    
    # Ensure XDG directory exists
    mkdir -p "${XDG_CONFIG_HOME:-$HOME/.config}/tmux"
    
    # Run theme-switch to generate config
    if [[ -x "$DOTFILES_ROOT/scripts/theme-switch" ]]; then
        # Get current theme
        local current_theme="dracula"
        local theme_file="${XDG_CONFIG_HOME:-$HOME/.config}/dotfiles/current-theme"
        
        if [[ -f "$theme_file" ]]; then
            current_theme=$(cat "$theme_file")
        fi
        
        info "Applying theme: $current_theme"
        "$DOTFILES_ROOT/scripts/theme-switch" "$current_theme" --no-reload --quiet
        success "Generated config at ~/.config/tmux/tmux.conf"
    else
        error "theme-switch script not found"
        exit 1
    fi

    # Step 3: Create compatibility symlink
    echo ""
    info "Step 3: Creating compatibility symlink"
    
    if ln -sf "${XDG_CONFIG_HOME:-$HOME/.config}/tmux/tmux.conf" "$HOME/.tmux.conf"; then
        success "Created ~/.tmux.conf -> ~/.config/tmux/tmux.conf"
    else
        error "Failed to create symlink"
        exit 1
    fi

    # Step 4: Reload tmux if running
    echo ""
    info "Step 4: Reloading tmux"
    
    if command -v tmux >/dev/null 2>&1 && tmux info &>/dev/null; then
        if tmux source-file "$HOME/.tmux.conf" 2>/dev/null; then
            success "Reloaded tmux configuration"
        else
            warn "Failed to reload tmux (you may need to restart tmux)"
        fi
    else
        info "Not in tmux - start tmux to see changes"
    fi

    echo ""
    print_header "Migration Complete!"
    
    echo "Benefits of the new setup:"
    echo "  • Follows XDG Base Directory standard"
    echo "  • Your theme changes won't create git conflicts"
    echo "  • Template stays clean in the repository"
    echo "  • Compatibility symlink maintains backwards compatibility"
    echo ""
    
    success "All done! You can now change themes without git conflicts."
    info "Try it: theme-switch catppuccin-mocha"
}

main "$@"
