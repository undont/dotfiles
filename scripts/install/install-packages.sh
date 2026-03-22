#!/usr/bin/env bash
set -euo pipefail

# Install packages from Brewfile based on preset

SCRIPT_DIR="${BASH_SOURCE%/*}"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/../_lib/common.sh"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/../_lib/brewfile.sh"

DOTFILES_DIR="${DOTFILES_DIR:-$(cd "$(dirname "$(dirname "$SCRIPT_DIR")")" && pwd)}"
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
cleanup() { rm -f "$FILTERED_BREWFILE"; }
trap cleanup EXIT

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

# Linux: fix gcc symlinks and prefer system gcc for native builds
# Note: find -printf and grep -oP are GNU-only; this block is Linux-only by design.
if is_linux; then
    BREW_BIN=""
    if command_exists brew; then
        BREW_BIN="$(brew --prefix)/bin"
    fi

    # Fix gcc symlinks (brew post-install often fails on non-standard distros)
    # Without these, formulas that need source compilation can't find gcc/g++.
    if [[ -n "$BREW_BIN" ]]; then
        GCC_VERSION=$(find "$BREW_BIN" -maxdepth 1 -name 'gcc-[0-9]*' -printf '%f\n' 2>/dev/null \
            | grep -oP 'gcc-\K\d+' | sort -rn | head -1 || true)
        if [[ -n "$GCC_VERSION" ]] && [[ -x "$BREW_BIN/gcc-$GCC_VERSION" ]] && [[ ! -e "$BREW_BIN/gcc" ]]; then
            echo "Fixing gcc symlinks (gcc-$GCC_VERSION -> gcc)..."
            ln -sf "$BREW_BIN/gcc-$GCC_VERSION" "$BREW_BIN/gcc"
            [[ -x "$BREW_BIN/g++-$GCC_VERSION" ]] && ln -sf "$BREW_BIN/g++-$GCC_VERSION" "$BREW_BIN/g++"
            for tool in gcc-ar gcc-nm gcc-ranlib; do
                [[ -x "$BREW_BIN/${tool}-$GCC_VERSION" ]] && ln -sf "$BREW_BIN/${tool}-$GCC_VERSION" "$BREW_BIN/$tool"
            done
            success "gcc symlinks created"
        fi
    fi

    # Prefer system gcc over Homebrew's for general compilation.
    # Homebrew's gcc has broken include_next paths (can't find system stdint.h etc.)
    # which causes tree-sitter and other native builds to fail.
    if ! command -v /usr/bin/gcc &>/dev/null; then
        echo "Installing system gcc (needed for native builds like tree-sitter)..."
        install_system_package "gcc" || true
    fi

    # Point cc at system gcc when available (not Homebrew's)
    if [[ -n "$BREW_BIN" ]]; then
        if [[ -x /usr/bin/gcc ]]; then
            ln -sf /usr/bin/gcc "$BREW_BIN/cc"
            success "cc symlink created (-> system /usr/bin/gcc)"
        elif [[ -x "$BREW_BIN/gcc" ]] && [[ ! -e "$BREW_BIN/cc" ]]; then
            ln -sf "$BREW_BIN/gcc" "$BREW_BIN/cc"
            success "cc symlink created (-> brew gcc, fallback)"
        fi
    fi
fi

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

    # Ghostty (cask on macOS, system package on Linux — not managed by brew)
    if ! command_exists ghostty; then
        if grep -qi steamos /etc/os-release 2>/dev/null; then
            info "Ghostty not available on SteamOS (read-only filesystem)."
            echo "  Install manually: sudo steamos-readonly disable && sudo pacman -S ghostty"
        elif command_exists pacman; then
            # Arch Linux: ghostty is in the [extra] repo
            echo "Installing Ghostty (pacman)..."
            sudo pacman -S --noconfirm ghostty || warn "Ghostty install failed — see https://ghostty.org/docs/install/binary"
        elif command_exists apt-get; then
            # Ubuntu/Debian: not in default repos — handled in post-install next steps
            :
        elif command_exists dnf; then
            # Fedora: available via Terra repository
            echo "Installing Ghostty (dnf)..."
            if ! sudo dnf install -y ghostty; then
                echo "  Ghostty not found in default repos. Trying Terra repository..."
                if sudo rpm --import https://repos.fyralabs.com/terra/gpg.key \
                    && sudo dnf install -y --repofrompath 'terra,https://repos.fyralabs.com/terra$releasever' terra-release \
                    && sudo dnf install -y ghostty; then
                    success "Ghostty installed via Terra"
                else
                    warn "Ghostty install failed."
                    echo "  Try: sudo dnf copr enable pgdev/ghostty && sudo dnf install ghostty"
                    echo "  Or build from source: https://ghostty.org/docs/install/build"
                fi
            fi
        else
            warn "No supported package manager found for Ghostty."
            echo "  See https://ghostty.org/docs/install/binary"
        fi
    fi

    # fnm (macOS uses brew; Linux needs manual install — brew compile often fails)
    if ! command_exists fnm; then
        warn "fnm not found. Install manually: curl -fsSL https://fnm.vercel.app/install | bash"
        echo "  Or download a release from https://github.com/Schniz/fnm/releases"
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
        # Trust decision: first-party URL (claude.ai) — no third-party CDN involved.
        # No published checksum available; accepted risk for first-party installer.
        if ! curl -fsSL https://claude.ai/install.sh | bash; then
            warn "Claude Code install failed. You can retry manually: curl -fsSL https://claude.ai/install.sh | bash"
        fi
    else
        echo "Claude Code already installed: $(claude --version 2>/dev/null || echo 'unknown version')"
    fi
fi

# glazepkg (gpk) - Go package manager tool
if should_install "core"; then
    if command_exists go; then
        if ! command_exists gpk; then
            echo "Installing gpk (glazepkg)..."
            if ! go install github.com/neur0map/glazepkg/cmd/gpk@latest; then
                warn "gpk install failed. You can retry manually: go install github.com/neur0map/glazepkg/cmd/gpk@latest"
            fi
        else
            echo "gpk already installed"
        fi
    else
        warn "Go not found — skipping gpk install"
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
    gh extension install dlvhdr/gh-dash    2>/dev/null || true
    gh extension install dlvhdr/gh-enhance 2>/dev/null || true
    gh extension install seanhalberthal/gh-bench 2>/dev/null || true
fi

# fnm shell setup reminder
if command_exists fnm; then
    echo ""
    info "fnm installed. To install Node.js:"
    echo "  fnm install --lts"
    echo "  fnm default lts-latest"
fi

# Ghostty next steps (Ubuntu/Debian — no official apt package)
if should_install "core" && is_linux && ! command_exists ghostty; then
    if command_exists apt-get; then
        ghostty_commit="655c77ad73ff1a6c38d1141e30d4c53eccb5a054"
        echo ""
        info "Ghostty not installed. Install options:"
        echo "  Community .deb (pinned to ${ghostty_commit:0:7}):"
        echo "    curl -fsSL https://raw.githubusercontent.com/mkasberg/ghostty-ubuntu/${ghostty_commit}/install.sh -o /tmp/ghostty-install.sh"
        echo "    less /tmp/ghostty-install.sh  # review first"
        echo "    bash /tmp/ghostty-install.sh"
        echo "  Or build from source: https://ghostty.org/docs/install/build"
    fi
fi

echo ""
success "Package installation complete"
