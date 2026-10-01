#!/usr/bin/env bash
set -euo pipefail

# installs the Brewfile packages for a preset, then per-tool setup

SCRIPT_DIR="${BASH_SOURCE%/*}"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/../_lib/common.sh"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/../_lib/brewfile.sh"

DOTFILES_DIR="${DOTFILES_DIR:-$(cd "$(dirname "$(dirname "$SCRIPT_DIR")")" && pwd)}"
PRESET="${DOTFILES_PRESET:-full}"

print_section "Installing Homebrew Packages"

if [[ ! -f "$DOTFILES_DIR/Brewfile" ]]; then
    error "Brewfile not found at $DOTFILES_DIR/Brewfile"
    exit 1
fi

if ! command_exists brew; then
    error "Homebrew not found. Run install-homebrew.sh first."
    exit 1
fi

echo "Filtering Brewfile for preset: $PRESET"
FILTERED_BREWFILE=$(create_filtered_brewfile "$PRESET" "$DOTFILES_DIR/Brewfile")

cleanup() { rm -f "$FILTERED_BREWFILE"; }
trap cleanup EXIT

# the shell exports HOMEBREW_REQUIRE_TAP_TRUST=1, under which `brew bundle`
# refuses untrusted third-party taps. homebrew versions without `brew trust`
# skip this
if brew trust --help >/dev/null 2>&1; then
    while read -r _ tap_name; do
        tap_name="${tap_name%\"}"
        tap_name="${tap_name#\"}"
        [[ -n "$tap_name" ]] && brew trust --tap "$tap_name" >/dev/null 2>&1 || true
    done < <(grep -E '^tap "' "$FILTERED_BREWFILE")
fi

# `brew bundle check` exits 0 when nothing needs installing or upgrading. its
# output is discarded: --quiet still prints a "can't satisfy your Brewfile's
# dependencies" summary on a machine that needs the install below
echo "Checking Brewfile state..."
echo ""

if brew bundle check --file="$FILTERED_BREWFILE" --quiet >/dev/null 2>&1; then
    success "All Brewfile packages already installed and up to date"
else
    echo "Installing/upgrading packages from Brewfile..."
    echo "This may take a while on first run."
    echo ""

    if brew bundle install --upgrade --file="$FILTERED_BREWFILE"; then
        echo ""
        success "All packages installed successfully"
    else
        echo ""
        warn "Some packages may have failed to install."
        echo "Check the output above for details."
        echo ""
        echo "You can retry failed packages with:"
        echo "  ./install.sh --$PRESET"
    fi
fi

echo ""
info "Running post-installation setup..."
echo ""

# linux: gcc symlinks, system gcc for native builds
# find -printf and grep -oP are GNU-only
if is_linux; then
    BREW_BIN=""
    if command_exists brew; then
        BREW_BIN="$(brew --prefix)/bin"
    fi

    # brew's post-install can fail to link gcc on non-standard distros, and
    # formulas compiled from source need gcc/g++
    if [[ -n "$BREW_BIN" ]]; then
        GCC_VERSION=$(find "$BREW_BIN" -maxdepth 1 -name 'gcc-[0-9]*' -printf '%f\n' 2>/dev/null |
            grep -oP 'gcc-\K\d+' | sort -rn | head -1 || true)
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

    # homebrew's gcc can't find system headers through include_next (stdint.h
    # etc.), which fails tree-sitter and other native builds
    if ! command -v /usr/bin/gcc &>/dev/null; then
        echo "Installing system gcc (needed for native builds like tree-sitter)..."
        install_system_package "gcc" || true
    fi

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

# postgresql@17: homebrew-core's post_install runs
# `initdb --locale=en_US.UTF-8`, which fails on linux systems without that
# locale and leaves the data cluster uninitialised. initdb runs here with a
# UTF-8 locale that exists on this machine
if is_linux && command_exists brew && brew list postgresql@17 &>/dev/null; then
    PG_DATADIR="$(brew --prefix)/var/postgresql@17"
    if [[ -d "$PG_DATADIR" ]] && [[ ! -f "$PG_DATADIR/PG_VERSION" ]]; then
        # grep exits 1 when the locale is absent, which would abort under set -e
        PG_LOCALE=$(locale -a | grep -im1 '^en_US\.utf-\?8$' || true)
        PG_LOCALE="${PG_LOCALE:-$(locale -a | grep -im1 'utf-\?8$' || true)}"
        PG_LOCALE="${PG_LOCALE:-C}"
        echo "Initializing postgresql@17 data cluster (locale: $PG_LOCALE)..."
        if LC_ALL="$PG_LOCALE" "$(brew --prefix)/opt/postgresql@17/bin/initdb" \
            --locale="$PG_LOCALE" -E UTF-8 "$PG_DATADIR"; then
            success "postgresql@17 cluster initialized"
        else
            warn "postgresql@17 initdb failed — initialize manually:"
            echo "  initdb --locale=$PG_LOCALE -E UTF-8 $PG_DATADIR"
        fi
    fi
fi

# linux alternatives for macOS cask-only packages
if should_install "core" && is_linux; then
    echo "Installing Linux alternatives for cask packages..."

    # .NET SDK (cask "dotnet-sdk" on macOS; formula "dotnet" on Linux)
    if ! command_exists dotnet; then
        echo "Installing .NET SDK..."
        brew install dotnet || warn ".NET SDK install failed — install manually from https://dotnet.microsoft.com"
    fi

    # google cloud SDK (cask "gcloud-cli" on macOS; no Linux formula)
    if ! command_exists gcloud; then
        info "gcloud not installed. Install manually: https://cloud.google.com/sdk/docs/install"
    fi

    # ghostty (cask on macOS, system package on linux)
    if ! command_exists ghostty; then
        if grep -qi steamos /etc/os-release 2>/dev/null; then
            info "Ghostty not available on SteamOS (read-only filesystem)."
            echo "  Install manually: sudo steamos-readonly disable && sudo pacman -S ghostty"
        elif command_exists pacman; then
            # arch: ghostty is in the [extra] repo
            echo "Installing Ghostty (pacman)..."
            sudo pacman -S --noconfirm ghostty || warn "Ghostty install failed — see https://ghostty.org/docs/install/binary"
        elif command_exists apt-get; then
            # ubuntu/debian: not in the default repos; install options are printed below
            :
        elif command_exists dnf; then
            # fedora: terra repository when the default repos lack it
            echo "Installing Ghostty (dnf)..."
            if ! sudo dnf install -y ghostty; then
                echo "  Ghostty not found in default repos. Trying Terra repository..."
                if sudo rpm --import https://repos.fyralabs.com/terra/gpg.key &&
                    sudo dnf install -y --repofrompath 'terra,https://repos.fyralabs.com/terra$releasever' terra-release &&
                    sudo dnf install -y ghostty; then
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

    # fnm comes from brew on macOS; on linux it is a manual install
    if ! command_exists fnm; then
        warn "fnm not found. Install manually: curl -fsSL https://fnm.vercel.app/install | bash"
        echo "  Or download a release from https://github.com/Schniz/fnm/releases"
    fi

    # nerd fonts are casks on macOS; install-fonts.sh installs them on linux
    "$SCRIPT_DIR/install-fonts.sh" || warn "Nerd Font install failed — see output above."

    # `dotfiles theme generate` reads ghostty's theme catalogue, which is
    # fetched into the user dir where ghostty is not installed
    "$SCRIPT_DIR/install-ghostty-themes.sh" || warn "Ghostty theme catalogue install failed — see output above."

    echo ""
fi

# ollama: native install in place of the brew formula
if should_install "core"; then
    if brew list ollama &>/dev/null; then
        echo "Removing Homebrew Ollama formula (switching to native install)..."
        brew uninstall ollama || warn "Failed to uninstall brew ollama"
    fi

    if ! command_exists ollama; then
        echo "Installing Ollama (native)..."
        # first-party URL (ollama.com), no third-party CDN
        if ! curl -fsSL https://ollama.com/install.sh | sh; then
            warn "Ollama install failed. You can retry manually: curl -fsSL https://ollama.com/install.sh | sh"
        fi
    else
        echo "Ollama already installed: $(ollama --version 2>/dev/null || echo 'unknown version')"
    fi
fi

# Claude Code: native install in place of the brew cask
if should_install "core"; then
    if is_macos && brew list --cask claude-code &>/dev/null; then
        echo "Removing Homebrew Claude Code cask (switching to native install)..."
        brew uninstall --cask claude-code || warn "Failed to uninstall brew claude-code cask"
    fi

    if ! command_exists claude; then
        echo "Installing Claude Code (native)..."
        # first-party URL (claude.ai), no third-party CDN; no published checksum
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
    gh extension install dlvhdr/gh-enhance 2>/dev/null || true
    gh extension install undont/gh-bench 2>/dev/null || true
fi

if command_exists fnm; then
    echo ""
    info "fnm installed. To install Node.js:"
    echo "  fnm install --lts"
    echo "  fnm default lts-latest"
fi

# ubuntu/debian have no official ghostty apt package
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
