#!/usr/bin/env bash
# shellcheck disable=SC1091
set -euo pipefail

# Uninstall dotfiles - removes symlinks and optionally restores backups
# Usage: ./scripts/install/uninstall.sh [--restore-backup] [--remove-brew-packages]

SCRIPT_DIR="${BASH_SOURCE%/*}"
DOTFILES_DIR="$(cd "$(dirname "$(dirname "$SCRIPT_DIR")")" && pwd)"
export DOTFILES_DIR

source "$SCRIPT_DIR/../_lib/common.sh"
source "$SCRIPT_DIR/../_lib/brewfile.sh"
source "$SCRIPT_DIR/../_lib/rollback.sh"

# Parse arguments
RESTORE_BACKUP=0
REMOVE_BREW=0

while [[ $# -gt 0 ]]; do
    case "$1" in
        --restore-backup)
            RESTORE_BACKUP=1
            shift
            ;;
        --remove-brew-packages)
            REMOVE_BREW=1
            shift
            ;;
        -h|--help)
            cat << 'EOF'
uninstall.sh - Remove dotfiles installation

USAGE:
    ./scripts/install/uninstall.sh [OPTIONS]

OPTIONS:
    --restore-backup       Restore files from most recent backup
    --remove-brew-packages Also uninstall Homebrew packages from Brewfile
    -h, --help             Show this help message

DESCRIPTION:
    Removes all symlinks created by the dotfiles installation.

    By default, only symlinks are removed. Use --restore-backup to
    restore your original configuration files from ~/.dotfiles-backup/

EXAMPLES:
    # Just remove symlinks
    ./scripts/install/uninstall.sh

    # Remove symlinks and restore original configs
    ./scripts/install/uninstall.sh --restore-backup

    # Full uninstall including brew packages
    ./scripts/install/uninstall.sh --restore-backup --remove-brew-packages
EOF
            exit 0
            ;;
        *)
            error "Unknown option: $1"
            exit 1
            ;;
    esac
done

print_header "Dotfiles Uninstall"

# Define all symlinks that install.sh creates
# Must match create-symlinks.sh exactly
SYMLINKS=(
    "$HOME/.zshrc"
    "$HOME/.zprofile"
    "$HOME/.p10k.zsh"
    "$HOME/.zsh"
    "$HOME/.tmux.conf"
    "$HOME/.tmux"
    "$HOME/.local/bin/dotfiles"
    "$HOME/.config/nvim"
    "$HOME/.config/ghostty/config"
    "$HOME/.config/karabiner/karabiner.json"
    "$HOME/.hammerspoon"
    "$HOME/.local/launchers/tnew"
    "$HOME/.local/launchers/dana"
    "$HOME/.local/launchers/code"
)

echo "This will remove the following symlinks:"
for link in "${SYMLINKS[@]}"; do
    if [[ -L "$link" ]]; then
        echo "  - $link -> $(readlink "$link")"
    elif [[ -e "$link" ]]; then
        echo "  - $link (exists but not a symlink - will skip)"
    fi
done
echo ""

if [[ $RESTORE_BACKUP -eq 1 ]]; then
    BACKUP_BASE="$HOME/.dotfiles-backup"
    if [[ -d "$BACKUP_BASE" ]]; then
        LATEST_BACKUP=$(find "$BACKUP_BASE" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | sort -r | head -1)
        if [[ -n "$LATEST_BACKUP" ]]; then
            echo "Will restore from backup: $LATEST_BACKUP"
            echo ""
        else
            warn "No backups found in $BACKUP_BASE"
            RESTORE_BACKUP=0
        fi
    else
        warn "Backup directory not found: $BACKUP_BASE"
        RESTORE_BACKUP=0
    fi
fi

if [[ $REMOVE_BREW -eq 1 ]]; then
    echo "Will also remove Homebrew packages from Brewfile"
    echo ""
fi

if ! confirm "Proceed with uninstall?"; then
    echo "Uninstall cancelled"
    exit 0
fi

echo ""

# Step 1: Remove symlinks
info "Removing symlinks..."
for link in "${SYMLINKS[@]}"; do
    if [[ -L "$link" ]]; then
        rm -f "$link"
        success "Removed: $link"
    elif [[ -e "$link" ]]; then
        warn "Skipped (not a symlink): $link"
    fi
done

# Step 2: Restore from backup if requested
if [[ $RESTORE_BACKUP -eq 1 ]] && [[ -n "${LATEST_BACKUP:-}" ]]; then
    echo ""
    restore_from_backup "$LATEST_BACKUP"
fi

# Step 3: Remove additional created files/directories
echo ""
info "Cleaning up additional files..."

# Remove TPM if installed by us
if [[ -d "$HOME/.tmux/plugins/tpm" ]]; then
    if confirm "Remove TPM (Tmux Plugin Manager)?"; then
        rm -rf "$HOME/.tmux/plugins"
        success "Removed: ~/.tmux/plugins"
    fi
fi

# Remove secrets file if empty
if [[ -f "$HOME/.zsh/.secrets.zsh" ]]; then
    if [[ ! -s "$HOME/.zsh/.secrets.zsh" ]]; then
        rm -f "$HOME/.zsh/.secrets.zsh"
        success "Removed empty secrets file"
    else
        warn "Kept ~/.zsh/.secrets.zsh (contains data)"
    fi
fi

# Step 4: Remove Homebrew packages if requested
if [[ $REMOVE_BREW -eq 1 ]]; then
    echo ""
    info "Removing Homebrew packages..."

    if [[ -f "$DOTFILES_DIR/Brewfile" ]] && command_exists brew; then
        # Load saved preset
        PRESET_FILE="${XDG_CONFIG_HOME:-$HOME/.config}/dotfiles/preset"
        if [[ -f "$PRESET_FILE" ]]; then
            PRESET=$(cat "$PRESET_FILE")
            echo "Using saved preset: $PRESET"
        else
            PRESET="full"
            echo "No saved preset found, assuming: $PRESET"
        fi

        # Create filtered Brewfile
        FILTERED_BREWFILE=$(create_filtered_brewfile "$PRESET" "$DOTFILES_DIR/Brewfile")

        # Set up cleanup trap for filtered Brewfile
        # shellcheck disable=SC2064
        trap "rm -f '$FILTERED_BREWFILE'" EXIT

        echo ""
        echo "Packages to remove (based on $PRESET preset):"
        grep -E '^(brew|cask) "' "$FILTERED_BREWFILE" | head -20
        TOTAL=$(grep -cE '^(brew|cask) "' "$FILTERED_BREWFILE" || echo 0)
        if [[ $TOTAL -gt 20 ]]; then
            echo "  ... and $((TOTAL - 20)) more"
        fi
        echo ""

        if confirm "Remove these $TOTAL packages?"; then
            # Uninstall each package
            grep -E '^brew "' "$FILTERED_BREWFILE" | sed 's/brew "//;s/".*//' | while read -r pkg; do
                brew uninstall --ignore-dependencies "$pkg" 2>/dev/null || true
            done
            grep -E '^cask "' "$FILTERED_BREWFILE" | sed 's/cask "//;s/".*//' | while read -r pkg; do
                brew uninstall --cask "$pkg" 2>/dev/null || true
            done
            success "Homebrew packages removed"
        fi
    else
        warn "Brewfile not found or brew not installed"
    fi
fi

# Step 5: Remove preset config (after brew removal since we need to read it)
PRESET_CONFIG_FILE="${XDG_CONFIG_HOME:-$HOME/.config}/dotfiles/preset"
if [[ -f "$PRESET_CONFIG_FILE" ]]; then
    rm -f "$PRESET_CONFIG_FILE"
    rmdir "${XDG_CONFIG_HOME:-$HOME/.config}/dotfiles" 2>/dev/null || true
    success "Removed preset configuration"
fi

echo ""
print_header "Uninstall Complete"

echo "Dotfiles symlinks have been removed."
if [[ $RESTORE_BACKUP -eq 1 ]]; then
    echo "Original configuration files have been restored."
fi
echo ""
echo "Note: Backups are preserved at ~/.dotfiles-backup/"
echo "You can delete them manually if no longer needed."
