#!/usr/bin/env bash
set -euo pipefail

# install Homebrew if not present, update if already installed

SCRIPT_DIR="${BASH_SOURCE%/*}"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/../_lib/common.sh"

print_section "Homebrew Setup"

HOMEBREW_PREFIX=$(get_homebrew_prefix)

# check if Homebrew is installed
if command_exists brew; then
    success "Homebrew is already installed"
    echo ""

    info "Updating Homebrew..."
    # `brew update` is only a metadata refresh; a failure here does not block
    # the package install below, so it must not be fatal under `set -e`. it can
    # also crash with its own internal bugs the first time Homebrew self-updates
    # (e.g. "uninitialized constant DescriptionCacheStore::FormulaVersions" on
    # 5.x), which then self-clear on the next run. retry once to recover from
    # that, then warn and continue rather than aborting the whole update
    if brew update || brew update; then
        echo ""
        success "Homebrew updated successfully"
    else
        echo ""
        warn "brew update reported an error (often a transient Homebrew self-update bug); skipping the metadata refresh and continuing."
        warn "Run 'brew update' again later if needed. This does not affect package installation below."
    fi
else
    warn "Homebrew not found. Installing..."
    echo ""

    # install platform-specific build prerequisites
    if is_macos; then
        # check for Command Line Tools
        if ! xcode-select -p &>/dev/null; then
            warn "Installing Command Line Tools..."
            echo "A dialog may appear - please click 'Install' and wait for completion."
            xcode-select --install

            # wait for installation with timeout
            echo ""
            echo "Waiting for Command Line Tools installation..."
            if ! read_with_timeout "Press Enter once the installation is complete: " _ 600; then
                error "Timed out waiting for Command Line Tools"
                exit 1
            fi
        fi
    elif is_linux; then
        info "Installing Linux build prerequisites..."
        if command_exists apt-get; then
            sudo apt-get update
            sudo apt-get install -y build-essential procps curl file git
        elif command_exists dnf; then
            sudo dnf groupinstall -y 'Development Tools'
            sudo dnf install -y procps-ng curl file git
        elif command_exists yum; then
            sudo yum groupinstall -y 'Development Tools'
            sudo yum install -y procps-ng curl file git
        fi
    fi

    # install Homebrew
    info "Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

    # add Homebrew to PATH for this session
    eval "$("$HOMEBREW_PREFIX/bin/brew" shellenv)"

    echo ""
    success "Homebrew installed successfully"
fi

# verify installation
echo ""
echo "Homebrew version: $(brew --version | head -n1)"
echo "Homebrew prefix: $(brew --prefix)"

# disable analytics (optional but recommended for privacy)
brew analytics off 2>/dev/null || true

echo ""
success "Homebrew setup complete"
