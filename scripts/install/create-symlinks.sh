#!/usr/bin/env bash
# shellcheck disable=SC1091
set -euo pipefail

# Create symlinks for all dotfiles based on preset
# Requires DOTFILES_DIR to be set

SCRIPT_DIR="${BASH_SOURCE%/*}"
DOTFILES_DIR="${DOTFILES_DIR:-$(dirname "$(dirname "$SCRIPT_DIR")")}"
export DOTFILES_DIR

source "$SCRIPT_DIR/../_lib/common.sh"
source "$SCRIPT_DIR/../_lib/rollback.sh"

PRESET="${DOTFILES_PRESET:-full}"
FAILED=0

# Helper to check if a component should be installed for the current preset
# Usage: should_install "core" returns true if preset is core or full
should_install() {
    local required_preset="$1"
    case "$required_preset" in
        minimal)
            return 0  # Always include minimal
            ;;
        core)
            [[ "$PRESET" == "core" || "$PRESET" == "full" ]]
            ;;
        full)
            [[ "$PRESET" == "full" ]]
            ;;
    esac
}

create_link() {
    local source="$1"
    local dest="$2"

    # Ensure parent directory exists
    mkdir -p "$(dirname "$dest")"

    # Remove existing symlink if present
    if [[ -L "$dest" ]]; then
        rm "$dest"
    fi

    # Fail if destination exists and is not a symlink
    if [[ -e "$dest" ]]; then
        printf "${RED}FAILED:${NC} %s already exists and is not a symlink\n" "$dest"
        FAILED=1
        return 1
    fi

    # Create symlink
    if ln -sf "$source" "$dest"; then
        printf "${GREEN}Created:${NC} %s -> %s\n" "$dest" "$source"
        # Record for rollback
        record_symlink "$dest" "$source"
        return 0
    else
        printf "${RED}FAILED:${NC} Could not create symlink %s\n" "$dest"
        FAILED=1
        return 1
    fi
}

print_section "Creating symlinks"
echo "Source: $DOTFILES_DIR"
echo "Preset: $PRESET"
echo ""

# Zsh (minimal)
echo "Zsh configuration:"
create_link "$DOTFILES_DIR/zsh/.zshrc" "$HOME/.zshrc"
create_link "$DOTFILES_DIR/zsh/.zprofile" "$HOME/.zprofile"
create_link "$DOTFILES_DIR/zsh/.p10k.zsh" "$HOME/.p10k.zsh"
create_link "$DOTFILES_DIR/zsh/.zsh" "$HOME/.zsh"

# Tmux (minimal)
echo ""
echo "Tmux configuration:"
create_link "$DOTFILES_DIR/tmux/.tmux.conf" "$HOME/.tmux.conf"
create_link "$DOTFILES_DIR/tmux/.tmux" "$HOME/.tmux"

# Neovim (core)
if should_install "core"; then
    echo ""
    echo "Neovim configuration:"
    create_link "$DOTFILES_DIR/nvim" "$HOME/.config/nvim"
fi

# Hammerspoon (full)
if should_install "full"; then
    echo ""
    echo "Hammerspoon configuration:"
    create_link "$DOTFILES_DIR/hammerspoon" "$HOME/.hammerspoon"
fi

# Ghostty (core)
if should_install "core"; then
    echo ""
    echo "Ghostty configuration:"
    mkdir -p "$HOME/.config/ghostty"
    create_link "$DOTFILES_DIR/ghostty/config" "$HOME/.config/ghostty/config"
fi

# Karabiner (full)
if should_install "full"; then
    echo ""
    echo "Karabiner configuration:"
    mkdir -p "$HOME/.config/karabiner"
    create_link "$DOTFILES_DIR/karabiner/karabiner.json" "$HOME/.config/karabiner/karabiner.json"
fi

# Session launchers (core)
if should_install "core"; then
    echo ""
    echo "Session launchers:"
    mkdir -p "$HOME/.local/launchers"
    create_link "$DOTFILES_DIR/launchers/tm" "$HOME/.local/launchers/tm"
    create_link "$DOTFILES_DIR/launchers/dana" "$HOME/.local/launchers/dana"
fi

echo ""

# Record step completion
record_step "symlinks"

if [[ $FAILED -eq 0 ]]; then
    success "All symlinks created successfully!"
    exit 0
else
    error "Some symlinks failed to create. Check the output above."
    exit 1
fi
