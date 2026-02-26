#!/usr/bin/env bash
set -euo pipefail

# Verify dotfiles installation is correct
# Checks symlinks, plugin managers, and basic functionality

# Help flag handling
if [[ "${1:-}" == "--help" ]] || [[ "${1:-}" == "-h" ]]; then
    cat << 'EOF'
health-check.sh - Dotfiles installation health check

USAGE:
    ./scripts/install/health-check.sh

DESCRIPTION:
    Runs comprehensive health checks on the dotfiles installation:
      • Verifies all symlinks point to correct locations
      • Checks plugin managers are installed (TPM, lazy.nvim)
      • Validates secrets file exists
      • Tests custom scripts are in PATH

OPTIONS:
    -h, --help   Show this help message

EXAMPLES:
    # Run health check from dotfiles root
    ./scripts/install/health-check.sh

    # Run from anywhere (if in PATH)
    health-check.sh

OUTPUT:
    Displays status for each check:
      ✓ Check passed (green OK)
      ✗ Check failed (red MISSING or WRONG TARGET)

    Exit code 0 if all checks pass, non-zero otherwise.

SEE ALSO:
    ./install.sh --check-only    Dry-run installation without changes
    ./scripts/install/rollback.sh  Restore backup if issues found
EOF
    exit 0
fi

SCRIPT_DIR="${BASH_SOURCE%/*}"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/../_lib/common.sh"

# Derive DOTFILES_DIR from script location if not set
if [[ -z "${DOTFILES_DIR:-}" ]]; then
    DOTFILES_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
fi
export DOTFILES_DIR

PRESET="${DOTFILES_PRESET:-full}"

ISSUES=0

check_symlink() {
    local link="$1"
    local target="$2"
    local name="$3"

    printf "Checking %-30s" "$name..."

    if [[ -L "$link" ]]; then
        local actual_target
        actual_target=$(readlink "$link")
        if [[ "$actual_target" == "$target" ]]; then
            printf '%sOK%s\n' "${GREEN}" "${NC}"
            return 0
        else
            printf '%sWRONG TARGET%s (points to %s)\n' "${YELLOW}" "${NC}" "$actual_target"
            ISSUES=1
            return 1
        fi
    elif [[ -e "$link" ]]; then
        printf '%sEXISTS BUT NOT SYMLINK%s\n' "${RED}" "${NC}"
        ISSUES=1
        return 1
    else
        printf '%sMISSING%s\n' "${RED}" "${NC}"
        ISSUES=1
        return 1
    fi
}

check_directory() {
    local dir="$1"
    local name="$2"

    printf "Checking %-30s" "$name..."

    if [[ -d "$dir" ]]; then
        printf '%sOK%s\n' "${GREEN}" "${NC}"
        return 0
    else
        printf '%sMISSING%s\n' "${RED}" "${NC}"
        ISSUES=1
        return 1
    fi
}

check_file() {
    local file="$1"
    local name="$2"

    printf "Checking %-30s" "$name..."

    if [[ -f "$file" ]]; then
        printf '%sOK%s\n' "${GREEN}" "${NC}"
        return 0
    else
        printf '%sMISSING%s\n' "${YELLOW}" "${NC}"
        ISSUES=1
        return 1
    fi
}

print_section "Dotfiles Health Check"
echo "Preset: $PRESET"
echo ""

echo "Symlinks:"
echo "---------"

# Zsh (minimal)
# ~/.zshrc may be a personal file (new) or symlink (legacy)
printf "Checking %-30s" ".zshrc..."
if [[ -L "$HOME/.zshrc" ]]; then
    printf '%sSYMLINK (legacy)%s\n' "${YELLOW}" "${NC}"
    echo "  Run 'dotfiles update' to migrate to personal ~/.zshrc"
    ISSUES=1
elif [[ -f "$HOME/.zshrc" ]]; then
    if grep -q "dotfiles.zsh" "$HOME/.zshrc" 2>/dev/null; then
        printf '%sOK%s\n' "${GREEN}" "${NC}"
    else
        printf '%sWARN%s\n' "${YELLOW}" "${NC}"
        echo "  ~/.zshrc exists but doesn't source dotfiles.zsh"
        ISSUES=1
    fi
else
    printf '%sMISSING%s\n' "${RED}" "${NC}"
    echo "  Run: cp ~/dotfiles/zsh/zshrc.template ~/.zshrc"
    ISSUES=1
fi
check_symlink "$HOME/.zprofile" "$DOTFILES_DIR/zsh/zprofile" ".zprofile"
check_symlink "$HOME/.p10k.zsh" "$DOTFILES_DIR/zsh/p10k.zsh" ".p10k.zsh"

# Prettier (minimal)
check_symlink "$HOME/.prettierrc" "$DOTFILES_DIR/formatters/prettierrc.json" ".prettierrc"

# Tmux (minimal)
# Note: .tmux.conf is generated to XDG location and symlinked
XDG_TMUX_CONF="${XDG_CONFIG_HOME:-$HOME/.config}/tmux/tmux.conf"
check_symlink "$HOME/.tmux.conf" "$XDG_TMUX_CONF" ".tmux.conf"
check_symlink "$HOME/.tmux" "$DOTFILES_DIR/tmux" ".tmux"

# Neovim (core)
if should_install "core"; then
    check_symlink "$HOME/.config/nvim" "$DOTFILES_DIR/nvim" "nvim config"
fi

# Hammerspoon (full)
if should_install "full"; then
    check_symlink "$HOME/.hammerspoon/init.lua" "$DOTFILES_DIR/hammerspoon/init.lua" "hammerspoon"
fi

# Ghostty (core)
# Config is generated to XDG — Ghostty reads ~/.config/ghostty/config natively on all platforms
if should_install "core"; then
    check_file "$HOME/.config/ghostty/config" "ghostty config (XDG)"
fi

# Karabiner (full)
if should_install "full"; then
    check_symlink "$HOME/.config/karabiner/karabiner.json" "$DOTFILES_DIR/karabiner/karabiner.json" "karabiner config"
fi

echo ""
echo "Plugin Managers:"
echo "----------------"
check_directory "$HOME/.tmux/plugins/tpm" "TPM (Tmux Plugin Manager)"
if should_install "core"; then
    check_directory "$HOME/.local/share/nvim/lazy" "lazy.nvim (Neovim)"

    # Warn if old packer install exists — it shadows lazy.nvim plugins in the
    # runtimepath and can cause "attempt to call field X (a nil value)" errors
    # when Neovim loads the wrong (pre-rewrite) version of a plugin module.
    PACKER_DIR="$HOME/.local/share/nvim/site/pack/packer"
    printf "Checking %-30s" "no stale packer install..."
    if [[ -d "$PACKER_DIR" ]]; then
        printf '%sWARN%s\n' "${YELLOW}" "${NC}"
        printf '  Stale packer plugins at %s\n' "$PACKER_DIR"
        printf '  These shadow lazy.nvim plugins and can break Neovim.\n'
        printf '  Remove with: rm -rf %s\n' "$PACKER_DIR"
        ISSUES=1
    else
        printf '%sOK%s\n' "${GREEN}" "${NC}"
    fi
fi

echo ""
echo "Secrets:"
echo "--------"
ZSH_CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/zsh"
check_file "$ZSH_CONFIG_DIR/secrets.zsh" "Secrets file"

# Session Launchers (core)
if should_install "core"; then
    echo ""
    echo "Session Launchers:"
    echo "------------------"
    if command_exists dev; then
        printf "Checking %-30s${GREEN}OK${NC}\n" "dev command"
    else
        printf "Checking %-30s${YELLOW}NOT IN PATH${NC}\n" "dev command"
        echo "  Add ~/.local/launchers to your PATH"
    fi

fi

echo ""

if [[ $ISSUES -eq 0 ]]; then
    success "All checks passed! Your dotfiles are correctly installed."
    exit 0
else
    warn "Some issues were found. See above for details."
    exit 1
fi
