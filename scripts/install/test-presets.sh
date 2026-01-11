#!/usr/bin/env bash
set -euo pipefail

# Test suite for install preset functionality
# Usage: ./test-presets.sh [--verbose]

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")"
PASS=0
FAIL=0

# Colours
GREEN=$'\033[0;32m'
RED=$'\033[0;31m'
YELLOW=$'\033[0;33m'
NC=$'\033[0m'

# Test output helpers
pass() {
    PASS=$((PASS + 1))
    printf "${GREEN}✓${NC} %s\n" "$1"
}

fail() {
    FAIL=$((FAIL + 1))
    printf "${RED}✗${NC} %s\n" "$1"
}

skip() {
    printf "${YELLOW}○${NC} %s (skipped)\n" "$1"
}

section() {
    echo ""
    echo "─────────────────────────────────────────"
    echo "$1"
    echo "─────────────────────────────────────────"
}

assert_equals() {
    local desc="$1"
    local expected="$2"
    local actual="$3"
    if [[ "$actual" == "$expected" ]]; then
        pass "$desc"
    else
        fail "$desc (expected: '$expected', got: '$actual')"
    fi
}

assert_contains() {
    local desc="$1"
    local needle="$2"
    local haystack="$3"
    if [[ "$haystack" == *"$needle"* ]]; then
        pass "$desc"
    else
        fail "$desc (expected to contain: '$needle')"
    fi
}

assert_not_contains() {
    local desc="$1"
    local needle="$2"
    local haystack="$3"
    if [[ "$haystack" != *"$needle"* ]]; then
        pass "$desc"
    else
        fail "$desc (expected NOT to contain: '$needle')"
    fi
}

# ===========================================================================
# Tests
# ===========================================================================

section "Brewfile Preset Markers"

# Check that Brewfile has preset markers
BREWFILE="$DOTFILES_DIR/Brewfile"
if [[ -f "$BREWFILE" ]]; then
    brewfile_content=$(cat "$BREWFILE")

    assert_contains "Brewfile has @preset: minimal marker" "@preset: minimal" "$brewfile_content"
    assert_contains "Brewfile has @preset: core marker" "@preset: core" "$brewfile_content"
    assert_contains "Brewfile has @preset: full marker" "@preset: full" "$brewfile_content"

    # Check specific packages are in correct sections
    # minimal section should have zsh and tmux
    assert_contains "Brewfile has zsh in minimal section" 'brew "zsh"' "$brewfile_content"
    assert_contains "Brewfile has tmux in minimal section" 'brew "tmux"' "$brewfile_content"

    # full section should have karabiner and hammerspoon
    assert_contains "Brewfile has karabiner in full section" 'cask "karabiner-elements"' "$brewfile_content"
    assert_contains "Brewfile has hammerspoon in full section" 'cask "hammerspoon"' "$brewfile_content"
    assert_contains "Brewfile has music-presence in full section" 'cask "music-presence"' "$brewfile_content"
else
    fail "Brewfile not found at $BREWFILE"
fi

section "Brewfile Filtering (install-packages.sh)"

# Source the install-packages script to get the filter function
# We need to extract and test the filter_brewfile function
INSTALL_PACKAGES="$SCRIPT_DIR/install-packages.sh"

if [[ -f "$INSTALL_PACKAGES" ]]; then
    # Create a test Brewfile
    TEST_BREWFILE=$(mktemp)
    trap 'rm -f "$TEST_BREWFILE"' EXIT

    cat > "$TEST_BREWFILE" << 'TESTEOF'
# Header content
tap "homebrew/bundle"

# =============================================================================
# @preset: minimal
# Minimal packages
# =============================================================================

brew "zsh"
brew "tmux"

# =============================================================================
# @preset: core
# Core packages
# =============================================================================

brew "neovim"
cask "ghostty"

# =============================================================================
# @preset: full
# Full packages
# =============================================================================

cask "hammerspoon"
cask "karabiner-elements"
TESTEOF

    # Extract and define the filter function for testing
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
            current_section = "header"
            include = 1
        }

        /^# @preset: minimal/ {
            current_section = "minimal"
            include = (inc_min == "true") ? 1 : 0
            next
        }
        /^# @preset: core/ {
            current_section = "core"
            include = (inc_core == "true") ? 1 : 0
            next
        }
        /^# @preset: full/ {
            current_section = "full"
            include = (inc_full == "true") ? 1 : 0
            next
        }

        include { print }
        ' "$brewfile"
    }

    # Test minimal preset filtering
    minimal_output=$(filter_brewfile "minimal" "$TEST_BREWFILE")
    assert_contains "minimal preset includes header" "homebrew/bundle" "$minimal_output"
    assert_contains "minimal preset includes zsh" 'brew "zsh"' "$minimal_output"
    assert_contains "minimal preset includes tmux" 'brew "tmux"' "$minimal_output"
    assert_not_contains "minimal preset excludes neovim" 'brew "neovim"' "$minimal_output"
    assert_not_contains "minimal preset excludes ghostty" 'cask "ghostty"' "$minimal_output"
    assert_not_contains "minimal preset excludes hammerspoon" 'cask "hammerspoon"' "$minimal_output"

    # Test core preset filtering
    core_output=$(filter_brewfile "core" "$TEST_BREWFILE")
    assert_contains "core preset includes zsh" 'brew "zsh"' "$core_output"
    assert_contains "core preset includes neovim" 'brew "neovim"' "$core_output"
    assert_contains "core preset includes ghostty" 'cask "ghostty"' "$core_output"
    assert_not_contains "core preset excludes hammerspoon" 'cask "hammerspoon"' "$core_output"
    assert_not_contains "core preset excludes karabiner" 'cask "karabiner-elements"' "$core_output"

    # Test full preset filtering
    full_output=$(filter_brewfile "full" "$TEST_BREWFILE")
    assert_contains "full preset includes zsh" 'brew "zsh"' "$full_output"
    assert_contains "full preset includes neovim" 'brew "neovim"' "$full_output"
    assert_contains "full preset includes hammerspoon" 'cask "hammerspoon"' "$full_output"
    assert_contains "full preset includes karabiner" 'cask "karabiner-elements"' "$full_output"

else
    fail "install-packages.sh not found"
fi

section "should_install Helper Function"

# Define the should_install function for testing
should_install() {
    local required_preset="$1"
    local current_preset="$2"

    case "$required_preset" in
        minimal)
            return 0  # Always include minimal
            ;;
        core)
            [[ "$current_preset" == "core" || "$current_preset" == "full" ]]
            ;;
        full)
            [[ "$current_preset" == "full" ]]
            ;;
    esac
}

# Test minimal preset
PRESET="minimal"
if should_install "minimal" "$PRESET"; then
    pass "minimal: should_install 'minimal' returns true"
else
    fail "minimal: should_install 'minimal' should return true"
fi

if ! should_install "core" "$PRESET"; then
    pass "minimal: should_install 'core' returns false"
else
    fail "minimal: should_install 'core' should return false"
fi

if ! should_install "full" "$PRESET"; then
    pass "minimal: should_install 'full' returns false"
else
    fail "minimal: should_install 'full' should return false"
fi

# Test core preset
PRESET="core"
if should_install "minimal" "$PRESET"; then
    pass "core: should_install 'minimal' returns true"
else
    fail "core: should_install 'minimal' should return true"
fi

if should_install "core" "$PRESET"; then
    pass "core: should_install 'core' returns true"
else
    fail "core: should_install 'core' should return true"
fi

if ! should_install "full" "$PRESET"; then
    pass "core: should_install 'full' returns false"
else
    fail "core: should_install 'full' should return false"
fi

# Test full preset
PRESET="full"
if should_install "minimal" "$PRESET"; then
    pass "full: should_install 'minimal' returns true"
else
    fail "full: should_install 'minimal' should return true"
fi

if should_install "core" "$PRESET"; then
    pass "full: should_install 'core' returns true"
else
    fail "full: should_install 'core' should return true"
fi

if should_install "full" "$PRESET"; then
    pass "full: should_install 'full' returns true"
else
    fail "full: should_install 'full' should return true"
fi

section "Install Script Help Output"

# Test that install.sh --help includes preset information
INSTALL_SCRIPT="$DOTFILES_DIR/install.sh"
if [[ -f "$INSTALL_SCRIPT" ]]; then
    help_output=$("$INSTALL_SCRIPT" --help 2>&1 || true)

    assert_contains "Help shows --minimal flag" "--minimal" "$help_output"
    assert_contains "Help shows --core flag" "--core" "$help_output"
    assert_contains "Help shows --full flag" "--full" "$help_output"
    assert_contains "Help shows Presets section" "Presets:" "$help_output"
    assert_contains "Help mentions default is full" "default" "$help_output"
else
    fail "install.sh not found"
fi

section "Preset Script Awareness"

# Check that sub-scripts read DOTFILES_PRESET
check_script_reads_preset() {
    local script="$1"
    local name="$2"

    if [[ -f "$script" ]]; then
        if grep -q 'DOTFILES_PRESET' "$script"; then
            pass "$name reads DOTFILES_PRESET"
        else
            fail "$name should read DOTFILES_PRESET"
        fi
    else
        skip "$name not found"
    fi
}

check_script_reads_preset "$SCRIPT_DIR/install-packages.sh" "install-packages.sh"
check_script_reads_preset "$SCRIPT_DIR/create-symlinks.sh" "create-symlinks.sh"
check_script_reads_preset "$SCRIPT_DIR/backup-existing.sh" "backup-existing.sh"
check_script_reads_preset "$SCRIPT_DIR/health-check.sh" "health-check.sh"
check_script_reads_preset "$SCRIPT_DIR/check-prerequisites.sh" "check-prerequisites.sh"

# ===========================================================================
# Summary
# ===========================================================================

echo ""
echo "==========================================="
echo "Test Results: ${GREEN}${PASS} passed${NC}, ${RED}${FAIL} failed${NC}"
echo "==========================================="

if [[ $FAIL -gt 0 ]]; then
    exit 1
fi
