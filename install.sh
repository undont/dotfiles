#!/usr/bin/env bash
# shellcheck disable=SC1091
set -euo pipefail

# Dotfiles installation script
# Usage: ./install.sh [--minimal|--core|--full] [OPTIONS]

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export DOTFILES_DIR

# Source shared utilities
source "$DOTFILES_DIR/scripts/_lib/common.sh"
source "$DOTFILES_DIR/scripts/_lib/rollback.sh"

# Preset definitions:
#   minimal - zsh + tmux only (servers, remote machines)
#   core    - minimal + nvim + ghostty + AI/CLI tools + session launch scripts (cross-platform dev)
#   full    - core + Hammerspoon + Karabiner (macOS power user)

# Error handler for automatic rollback
on_error() {
    local exit_code=$?
    local line_no=$1

    echo ""
    error "Installation failed at line $line_no (exit code: $exit_code)"
    echo ""

    if has_rollback_state; then
        warn "Installation state detected. You can rollback with:"
        echo "  ./scripts/install/rollback.sh"
        echo ""
        echo "Or to manually restore your backup:"
        backup_dir=$(get_backup_location)
        if [[ -n "$backup_dir" ]] && [[ -d "$backup_dir" ]]; then
            echo "  cp -r $backup_dir/* \$HOME/"
        fi
    fi

    exit $exit_code
}

# Set up error trap
trap 'on_error $LINENO' ERR

# Parse arguments
SKIP_BACKUP=0
SKIP_BREW=0
CHECK_ONLY=0
PRESET="full"  # Default preset

while [[ $# -gt 0 ]]; do
    case "$1" in
        --minimal)
            PRESET="minimal"
            shift
            ;;
        --core)
            PRESET="core"
            shift
            ;;
        --full)
            PRESET="full"
            shift
            ;;
        --skip-backup)
            SKIP_BACKUP=1
            shift
            ;;
        --skip-brew)
            SKIP_BREW=1
            shift
            ;;
        --check-only)
            CHECK_ONLY=1
            shift
            ;;
        -h|--help)
            echo "Usage: ./install.sh [PRESET] [OPTIONS]"
            echo ""
            echo "Presets:"
            echo "  --minimal        Install zsh + tmux only (servers, remote machines)"
            echo "  --core           Install zsh, tmux, nvim, ghostty, CLI/AI tools"
            echo "  --full           Install everything including macOS apps (default)"
            echo ""
            echo "Options:"
            echo "  --skip-backup    Skip backing up existing config files"
            echo "  --skip-brew      Skip Homebrew installation and packages"
            echo "  --check-only     Only run prerequisite and health checks"
            echo "  -h, --help       Show this help message"
            echo ""
            echo "Examples:"
            echo "  ./install.sh                # Full installation (default)"
            echo "  ./install.sh --core         # Cross-platform dev setup"
            echo "  ./install.sh --minimal      # Lightweight server setup"
            echo ""
            echo "To rollback a failed installation:"
            echo "  ./scripts/install/rollback.sh"
            exit 0
            ;;
        *)
            error "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Validate preset value
case "$PRESET" in
    minimal|core|full)
        # Valid preset
        ;;
    *)
        error "Invalid preset: $PRESET"
        echo "Valid presets are: minimal, core, full"
        exit 1
        ;;
esac

# Export preset for sub-scripts
export DOTFILES_PRESET="$PRESET"

# Initialise rollback state
init_rollback_state

print_logo
print_header "Dotfiles Installation"
echo "Dotfiles directory: $DOTFILES_DIR"
echo ""

# Display preset info and confirmation
echo "Selected preset: ${CYAN}${PRESET}${NC}"
case "$PRESET" in
    minimal)
        echo "Components: zsh, tmux"
        ;;
    core)
        echo "Components: zsh, tmux, nvim, ghostty, AI/CLI tools, session launch scripts"
        ;;
    full)
        echo "Components: Everything (core + Hammerspoon, Karabiner)"
        ;;
esac
echo ""

# Confirmation prompt
printf 'Proceed with %s%s%s installation? [y/N] ' "${CYAN}" "${PRESET}" "${NC}"
read -r response
case "$response" in
    [yY][eE][sS]|[yY])
        echo ""
        ;;
    *)
        echo ""
        info "Installation cancelled."
        exit 0
        ;;
esac

# Step 1: Install/Update Homebrew
if [[ $SKIP_BREW -eq 0 ]]; then
    print_step 1 "Setting up Homebrew..."
    "$DOTFILES_DIR/scripts/install/install-homebrew.sh"
    record_step "homebrew"

    # Ensure Homebrew is in PATH for subsequent steps
    # (The install script runs in a subshell, so PATH changes don't propagate)
    HOMEBREW_PREFIX=$(get_homebrew_prefix)
    if [[ -x "$HOMEBREW_PREFIX/bin/brew" ]]; then
        eval "$("$HOMEBREW_PREFIX/bin/brew" shellenv)"
    fi
    echo ""
else
    print_skip 1 "Homebrew setup" "--skip-brew flag"
fi

# Step 2: Install packages from Brewfile
if [[ $SKIP_BREW -eq 0 ]]; then
    print_step 2 "Installing packages from Brewfile..."
    "$DOTFILES_DIR/scripts/install/install-packages.sh"
    record_step "packages"
    echo ""
else
    print_skip 2 "package installation" "--skip-brew flag"
fi

# Step 3: Check prerequisites
print_step 3 "Checking prerequisites..."
if ! "$DOTFILES_DIR/scripts/install/check-prerequisites.sh"; then
    echo ""
    error "Some required tools are missing."
    if [[ $SKIP_BREW -eq 1 ]]; then
        echo "Try running without --skip-brew to install missing packages."
    fi
    exit 1
fi
record_step "prerequisites"

if [[ $CHECK_ONLY -eq 1 ]]; then
    echo ""
    info "Running health check..."
    echo ""
    "$DOTFILES_DIR/scripts/install/health-check.sh" || true
    cleanup_rollback_state
    exit 0
fi

# Step 4: Backup existing files
echo ""
if [[ $SKIP_BACKUP -eq 0 ]]; then
    print_step 4 "Backing up existing configuration..."
    BACKUP_DIR=$("$DOTFILES_DIR/scripts/install/backup-existing.sh" | tail -n1)
    record_step "backup"
else
    print_skip 4 "backup" "--skip-backup flag"
fi

# Step 5: Create symlinks
echo ""
print_step 5 "Creating symlinks..."
if ! "$DOTFILES_DIR/scripts/install/create-symlinks.sh"; then
    echo ""
    error "Some symlinks failed. Check the output above."
    echo ""
    echo "To rollback, run: ./scripts/install/rollback.sh"
    exit 1
fi
record_step "symlinks"

# Step 6: Install plugin managers
echo ""
print_step 6 "Installing plugin managers..."

# TPM (Tmux Plugin Manager) - all presets
if [[ ! -d "$HOME/.tmux/plugins/tpm" ]]; then
    echo "Installing TPM..."
    # Clone TPM at a known stable version for reproducibility
    git clone --branch v3.1.0 --depth 1 https://github.com/tmux-plugins/tpm "$HOME/.tmux/plugins/tpm"
    success "TPM installed. Press prefix + I inside tmux to install plugins."
else
    echo "TPM already installed."
fi
record_step "plugin-managers"

# lazy.nvim is auto-installed by Neovim config (core preset and above)
if [[ "$PRESET" == "core" || "$PRESET" == "full" ]]; then
    echo "lazy.nvim will be auto-installed when you first open Neovim."
fi

# Step 7: Create secrets file if needed
echo ""
print_step 7 "Setting up secrets..."
SECRETS_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/zsh"
mkdir -p "$SECRETS_DIR"

if [[ ! -f "$SECRETS_DIR/secrets.zsh" ]]; then
    if [[ -f "$DOTFILES_DIR/zsh/secrets.zsh.template" ]]; then
        cp "$DOTFILES_DIR/zsh/secrets.zsh.template" "$SECRETS_DIR/secrets.zsh"
        chmod 600 "$SECRETS_DIR/secrets.zsh"
        warn "Created secrets file from template."
        echo "Edit $SECRETS_DIR/secrets.zsh to add your API keys and tokens."
    else
        # Create secrets file with restrictive permissions from the start
        (
            umask 077
            touch "$SECRETS_DIR/secrets.zsh"
        )
        chmod 600 "$SECRETS_DIR/secrets.zsh"  # Belt and suspenders
        warn "Created empty secrets file."
    fi
else
    echo "Secrets file already exists."
fi
record_step "secrets"

# Step 8: Run health check
echo ""
print_step 8 "Running health check..."
"$DOTFILES_DIR/scripts/install/health-check.sh" || true
record_step "health-check"

# Step 9: Save preset for future updates
echo ""
print_step 9 "Saving preset configuration..."
PRESET_CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/dotfiles"
mkdir -p "$PRESET_CONFIG_DIR"
echo "$PRESET" > "$PRESET_CONFIG_DIR/preset"
success "Preset '$PRESET' saved to $PRESET_CONFIG_DIR/preset"
record_step "save-preset"

# Clean up rollback state on success
cleanup_rollback_state

# Done
print_logo
print_header "Installation Complete!"

echo "Preset: $PRESET"
echo ""
echo "Next steps:"
STEP=1
echo "  $STEP. Restart your terminal or run: source ~/.zshrc"
((STEP++))
echo "  $STEP. Open tmux and press \` + I to install plugins"
((STEP++))
if [[ "$PRESET" == "core" || "$PRESET" == "full" ]]; then
    echo "  $STEP. Open Neovim to trigger lazy.nvim plugin installation"
    ((STEP++))
    echo "  $STEP. Install Node.js: fnm install --lts && fnm default lts-latest"
    ((STEP++))
fi
echo "  $STEP. Edit ~/.config/zsh/secrets.zsh to add your API keys"
((STEP++))
echo "  $STEP. Personalise with local override files (never overwritten by updates):"
echo "       ~/.config/nvim/local.lua       → Neovim options, keymaps, cursor style"
echo "       ~/.config/tmux/local.conf      → Extra tmux settings"
echo "       ~/.config/ghostty/local        → Ghostty font/window overrides"
echo ""
if [[ $SKIP_BACKUP -eq 0 ]] && [[ -d "${BACKUP_DIR:-}" ]]; then
    echo "Backup location: $BACKUP_DIR"
    echo ""
fi
