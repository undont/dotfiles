#!/usr/bin/env bash
set -euo pipefail

# Check all prerequisites for dotfiles installation
# Returns 0 if all checks pass, 1 otherwise

# Help flag handling
if [[ "${1:-}" == "--help" ]] || [[ "${1:-}" == "-h" ]]; then
    cat << 'EOF'
check-prerequisites.sh - Verify installation prerequisites

USAGE:
    ./scripts/install/check-prerequisites.sh

DESCRIPTION:
    Checks that all required tools and dependencies are installed before
    running the dotfiles installation:
      • Core tools (git, tmux, zsh, neovim, etc.)
      • AI & development tools (claude, dotnet, etc.)
      • Database clients (psql, mongosh, turso)
      • Utilities (fastfetch, speedtest, glow)
      • macOS applications (Karabiner, Ghostty)
      • Optional but recommended tools

    This script is automatically run by install.sh but can be run standalone
    to verify your system is ready.

OPTIONS:
    -h, --help   Show this help message

EXAMPLES:
    # Check prerequisites before installation
    ./scripts/install/check-prerequisites.sh

    # Verify system after fresh OS install
    ./scripts/install/check-prerequisites.sh

OUTPUT:
    For each prerequisite:
      ✓ Tool found (green OK)
      ✗ Tool missing (red MISSING with installation hint)

    Exit code 0 if all required tools found, non-zero otherwise.

NOTES:
    • Missing optional tools generate warnings but don't fail the check
    • Installation hints are provided for each missing tool
    • Automatically run by ./install.sh - manual run optional

SEE ALSO:
    ./install.sh              Main installation script
    Brewfile                  List of Homebrew packages to install
EOF
    exit 0
fi

SCRIPT_DIR="${BASH_SOURCE%/*}"
source "$SCRIPT_DIR/../_lib/common.sh"

PRESET="${DOTFILES_PRESET:-full}"
FAILED=0

check() {
    if ! check_command "$1" "$2" "$3"; then
        FAILED=1
    fi
}

check_optional() {
    check_command "$1" "$2" "$3" "true"
}

print_section "Dotfiles Prerequisites Check"
echo "Preset: $PRESET"
echo ""

# Minimal preset tools
echo "Required - Shell & Terminal:"
echo "----------------------------"
check "git" "git" "xcode-select --install"
check "zsh" "zsh" "brew install zsh"
check "tmux" "tmux" "brew install tmux"
check "fzf" "fzf" "brew install fzf"
check "direnv" "direnv" "brew install direnv"

# Core preset tools
if should_install "core"; then
    echo ""
    echo "Required - Editor & Dev Tools:"
    echo "------------------------------"
    check "neovim" "nvim" "brew install neovim"
    # ghostty is checked via app existence (cask installs to /Applications)
    if is_macos; then
        printf "Checking %-20s" "ghostty..."
        if [[ -d "/Applications/Ghostty.app" ]]; then
            printf "${GREEN}OK${NC}\n"
        else
            printf "${RED}MISSING${NC}\n"
            printf "  ${YELLOW}Install with:${NC} brew install --cask ghostty\n"
            FAILED=1
        fi
    fi
    check "bun" "bun" "brew install oven-sh/bun/bun"
    check "go" "go" "brew install go"
    check "ripgrep" "rg" "brew install ripgrep"
    check "lazygit" "lazygit" "brew install lazygit"
    check "gh" "gh" "brew install gh"
    check "jq" "jq" "brew install jq"
    check "tree" "tree" "brew install tree"
    check "shellcheck" "shellcheck" "brew install shellcheck"

    echo ""
    echo "Required - AI & Dev Tools:"
    echo "--------------------------"
    check "claude" "claude" "curl -fsSL https://claude.ai/install.sh | bash"
    check "dotnet" "dotnet" "brew install --cask dotnet-sdk"
    check "act" "act" "brew install act"
    check "cmake" "cmake" "brew install cmake"
    check "staticcheck" "staticcheck" "brew install staticcheck"
    check "swift-format" "swift-format" "brew install swift-format"
    check "golang-migrate" "migrate" "brew install golang-migrate"

    echo ""
    echo "Required - Databases:"
    echo "---------------------"
    check "postgresql" "psql" "brew install postgresql@14"
    check "mongosh" "mongosh" "brew install mongosh"
    check "sqld" "sqld" "brew install libsql/sqld/sqld"

    echo ""
    echo "Required - Utilities:"
    echo "---------------------"
    check "fastfetch" "fastfetch" "brew install fastfetch"
    check "speedtest" "speedtest" "brew install teamookla/speedtest/speedtest"
    check "glow" "glow" "brew install glow"
fi

# Full preset tools (macOS-specific)
if should_install "full"; then
    echo ""
    echo "Required - macOS Apps:"
    echo "----------------------"
    # Karabiner is checked via app existence since CLI isn't in PATH
    printf "Checking %-20s" "karabiner..."
    if [[ -d "/Applications/Karabiner-Elements.app" ]]; then
        printf "${GREEN}OK${NC}\n"
    else
        printf "${RED}MISSING${NC}\n"
        printf "  ${YELLOW}Install with:${NC} brew install --cask karabiner-elements\n"
        FAILED=1
    fi
fi

echo ""
echo "Optional tools:"
echo "---------------"
check_optional "fnm" "fnm" "brew install fnm"
check_optional "python" "python3" "brew install python"
check_optional "gcloud" "gcloud" "brew install --cask gcloud-cli"
if should_install "full"; then
    check_optional "hammerspoon" "hs" "brew install --cask hammerspoon"
fi
if should_install "core"; then
    check_optional "fd" "fd" "brew install fd"
    check_optional "bat" "bat" "brew install bat"
fi

echo ""

if [[ $FAILED -eq 0 ]]; then
    success "All required prerequisites are installed!"
    exit 0
else
    error "Some required tools are missing. Please install them before continuing."
    exit 1
fi
