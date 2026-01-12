#!/usr/bin/env bash
set -euo pipefail

# Install packages from Brewfile based on preset

SCRIPT_DIR="${BASH_SOURCE%/*}"
source "$SCRIPT_DIR/../_lib/common.sh"

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

# Filter Brewfile based on preset
# The Brewfile uses section markers like "# @preset: minimal"
# We include sections based on hierarchy: minimal < core < full
filter_brewfile() {
    local preset="$1"
    local brewfile="$2"
    local include_minimal=true
    local include_core=false
    local include_full=false

    case "$preset" in
        minimal)
            include_minimal=true
            ;;
        core)
            include_minimal=true
            include_core=true
            ;;
        full)
            include_minimal=true
            include_core=true
            include_full=true
            ;;
    esac

    awk -v inc_min="$include_minimal" -v inc_core="$include_core" -v inc_full="$include_full" '
    BEGIN {
        include = 1  # Include header lines before any preset marker
    }

    # Detect preset section markers
    /^# @preset: minimal/ {
        include = (inc_min == "true") ? 1 : 0
        next
    }
    /^# @preset: core/ {
        include = (inc_core == "true") ? 1 : 0
        next
    }
    /^# @preset: full/ {
        include = (inc_full == "true") ? 1 : 0
        next
    }

    # Print lines if we should include this section
    include { print }
    ' "$brewfile"
}

# Create filtered Brewfile
FILTERED_BREWFILE=$(mktemp)
trap 'rm -f "$FILTERED_BREWFILE"' EXIT

echo "Filtering Brewfile for preset: $PRESET"
filter_brewfile "$PRESET" "$DOTFILES_DIR/Brewfile" > "$FILTERED_BREWFILE"

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

# fzf keybindings and completion
if command_exists fzf; then
    FZF_INSTALL="$(brew --prefix)/opt/fzf/install"
    if [[ -f "$FZF_INSTALL" ]]; then
        echo "Setting up fzf keybindings..."
        "$FZF_INSTALL" --key-bindings --completion --no-update-rc --no-bash --no-fish
    fi
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

# gemini-cli setup reminder
if command_exists gemini; then
    echo ""
    info "Gemini CLI installed. To start:"
    echo "  gemini"
fi

echo ""
success "Package installation complete"
