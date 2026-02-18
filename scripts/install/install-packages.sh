#!/usr/bin/env bash
set -euo pipefail

# Install packages from Brewfile based on preset

SCRIPT_DIR="${BASH_SOURCE%/*}"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/../_lib/common.sh"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/../_lib/brewfile.sh"

DOTFILES_DIR="${DOTFILES_DIR:-$HOME/dotfiles}"
PRESET="${DOTFILES_PRESET:-full}"

print_section "Installing Homebrew Packages"

# Check if Brewfile exists
if [[ ! -f "$DOTFILES_DIR/Brewfile" ]]; then
    error "Brewfile not found at $DOTFILES_DIR/Brewfile"
    exit 1
fi

# Check if brew is available
if ! command_exists brew; then
    error "Homebrew not found. Run install-homebrew.sh first."
    exit 1
fi

# Create filtered Brewfile
echo "Filtering Brewfile for preset: $PRESET"
FILTERED_BREWFILE=$(create_filtered_brewfile "$PRESET" "$DOTFILES_DIR/Brewfile")

# Set up cleanup trap for filtered Brewfile
# shellcheck disable=SC2064
trap "rm -f '$FILTERED_BREWFILE'" EXIT

# Install packages from Brewfile
echo "Installing packages from Brewfile..."
echo "This may take a while on first run."
echo ""

if brew bundle install --file="$FILTERED_BREWFILE"; then
    echo ""
    success "All packages installed successfully"
else
    echo ""
    warn "Some packages may have failed to install."
    echo "Check the output above for details."
    echo ""
    echo "You can retry failed packages with:"
    echo "  brew bundle install --file=$DOTFILES_DIR/Brewfile"
fi

# Post-installation setup for specific tools
echo ""
info "Running post-installation setup..."
echo ""

# Linux alternatives for macOS cask-only packages
if should_install "core" && is_linux; then
    echo "Installing Linux alternatives for cask packages..."

    # .NET SDK (cask "dotnet-sdk" on macOS)
    if ! command_exists dotnet; then
        echo "Installing .NET SDK..."
        brew install dotnet-sdk 2>/dev/null || warn ".NET SDK install failed — install manually from https://dotnet.microsoft.com"
    fi

    # Google Cloud SDK (cask "gcloud-cli" on macOS)
    if ! command_exists gcloud; then
        echo "Installing Google Cloud SDK..."
        brew install google-cloud-sdk 2>/dev/null || warn "gcloud install failed — install manually from https://cloud.google.com/sdk"
    fi

    echo ""
fi

# Claude Code - native install (replaces brew cask)
if should_install "core"; then
    # Uninstall brew cask version if present to avoid conflicts (macOS only)
    if is_macos && brew list --cask claude-code &>/dev/null; then
        echo "Removing Homebrew Claude Code cask (switching to native install)..."
        brew uninstall --cask claude-code || warn "Failed to uninstall brew claude-code cask"
    fi

    if ! command_exists claude; then
        echo "Installing Claude Code (native)..."
        if ! curl -fsSL https://claude.ai/install.sh | bash; then
            warn "Claude Code install failed. You can retry manually: curl -fsSL https://claude.ai/install.sh | bash"
        fi
    else
        echo "Claude Code already installed: $(claude --version 2>/dev/null || echo 'unknown version')"
    fi
fi

# fzf keybindings and completion
if command_exists fzf; then
    FZF_INSTALL="$(brew --prefix)/opt/fzf/install"
    if [[ -f "$FZF_INSTALL" ]]; then
        echo "Setting up fzf keybindings..."
        "$FZF_INSTALL" --key-bindings --completion --no-update-rc --no-bash --no-fish
    fi
fi

# gh extensions
if command_exists gh; then
    echo "Installing gh extensions..."
    gh extension install dlvhdr/gh-dash 2>/dev/null || true
fi

# fnm shell setup reminder
if command_exists fnm; then
    echo ""
    info "fnm installed. To install Node.js:"
    echo "  fnm install --lts"
    echo "  fnm default lts-latest"
fi

# pipx path setup
if command_exists pipx; then
    pipx ensurepath 2>/dev/null || true
fi

echo ""
success "Package installation complete"
