#!/usr/bin/env bash
set -euo pipefail

# Test suite for installation script libraries
# Usage: ./test.sh [--verbose]

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PASS=0
FAIL=0
# shellcheck disable=SC2034
VERBOSE="${1:-}"  # Reserved for future verbose output

# Colours (using $'...' for proper escape interpretation)
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

# Assert that a command succeeds
assert_success() {
    local desc="$1"
    shift
    if "$@" 2>/dev/null; then
        pass "$desc"
    else
        fail "$desc"
    fi
}

# Assert that a command fails
assert_failure() {
    local desc="$1"
    shift
    if ! "$@" 2>/dev/null; then
        pass "$desc"
    else
        fail "$desc"
    fi
}

# Assert output equals expected value
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

# ===========================================================================
# Tests
# ===========================================================================

section "Library Sourcing"

# Source the library
if source "$SCRIPT_DIR/common.sh" 2>/dev/null; then
    pass "common.sh sources without error"
else
    fail "common.sh failed to source"
    exit 1
fi

section "Colour Definitions"

assert_equals "RED is defined" $'\033[0;31m' "$RED"
assert_equals "GREEN is defined" $'\033[0;32m' "$GREEN"
assert_equals "YELLOW is defined" $'\033[0;33m' "$YELLOW"
assert_equals "CYAN is defined" $'\033[0;36m' "$CYAN"
assert_equals "NC is defined" $'\033[0m' "$NC"

section "Output Functions"

# Test that output functions exist and are callable
assert_success "error function exists" type error
assert_success "warn function exists" type warn
assert_success "info function exists" type info
assert_success "success function exists" type success
assert_success "print_header function exists" type print_header
assert_success "print_section function exists" type print_section
assert_success "print_step function exists" type print_step

section "Utility Functions"

# command_exists
assert_success "command_exists returns true for bash" command_exists bash
assert_failure "command_exists returns false for nonexistent" command_exists nonexistent_command_12345

# is_macos (platform-dependent)
if [[ "$(uname)" == "Darwin" ]]; then
    assert_success "is_macos returns true on macOS" is_macos
else
    assert_failure "is_macos returns false on non-macOS" is_macos
fi

# get_homebrew_prefix
prefix=$(get_homebrew_prefix)
if [[ "$(uname -m)" == "arm64" ]]; then
    assert_equals "get_homebrew_prefix on Apple Silicon" "/opt/homebrew" "$prefix"
else
    assert_equals "get_homebrew_prefix on Intel/Linux" "/usr/local" "$prefix"
fi

section "Check Command Function"

# Test check_command with a known command
if check_command "bash" "bash" "" >/dev/null 2>&1; then
    pass "check_command returns 0 for existing command"
else
    fail "check_command should return 0 for bash"
fi

# Test check_command with nonexistent command
if ! check_command "nonexistent" "nonexistent_12345" "" 2>/dev/null; then
    pass "check_command returns 1 for missing command"
else
    fail "check_command should return 1 for nonexistent"
fi

section "ShellCheck Validation"

if command -v shellcheck &>/dev/null; then
    if shellcheck -x "$SCRIPT_DIR/common.sh" 2>/dev/null; then
        pass "common.sh passes shellcheck"
    else
        fail "common.sh has shellcheck warnings"
    fi
else
    skip "shellcheck not installed"
fi

# ===========================================================================
# Install Preset Tests
# ===========================================================================

DOTFILES_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")"

section "Brewfile Preset Markers"

BREWFILE="$DOTFILES_DIR/Brewfile"
if [[ -f "$BREWFILE" ]]; then
    brewfile_content=$(cat "$BREWFILE")

    if [[ "$brewfile_content" == *"@preset: minimal"* ]]; then
        pass "Brewfile has @preset: minimal marker"
    else
        fail "Brewfile missing @preset: minimal marker"
    fi

    if [[ "$brewfile_content" == *"@preset: core"* ]]; then
        pass "Brewfile has @preset: core marker"
    else
        fail "Brewfile missing @preset: core marker"
    fi

    if [[ "$brewfile_content" == *"@preset: full"* ]]; then
        pass "Brewfile has @preset: full marker"
    else
        fail "Brewfile missing @preset: full marker"
    fi

    if [[ "$brewfile_content" == *'brew "zsh"'* ]]; then
        pass "Brewfile has zsh"
    else
        fail "Brewfile missing zsh"
    fi

    if [[ "$brewfile_content" == *'cask "karabiner-elements"'* ]]; then
        pass "Brewfile has karabiner in full section"
    else
        fail "Brewfile missing karabiner"
    fi

    if [[ "$brewfile_content" == *'cask "music-presence"'* ]]; then
        pass "Brewfile has music-presence in full section"
    else
        fail "Brewfile missing music-presence"
    fi
else
    fail "Brewfile not found at $BREWFILE"
fi

section "Brewfile Filtering"

# Define the filter function for testing
filter_brewfile() {
    local preset="$1"
    local brewfile="$2"
    local include_minimal=true
    local include_core=false
    local include_full=false

    case "$preset" in
        minimal) include_minimal=true ;;
        core) include_minimal=true; include_core=true ;;
        full) include_minimal=true; include_core=true; include_full=true ;;
    esac

    awk -v inc_min="$include_minimal" -v inc_core="$include_core" -v inc_full="$include_full" '
    BEGIN { include = 1 }
    /^# @preset: minimal/ { include = (inc_min == "true") ? 1 : 0; next }
    /^# @preset: core/ { include = (inc_core == "true") ? 1 : 0; next }
    /^# @preset: full/ { include = (inc_full == "true") ? 1 : 0; next }
    include { print }
    ' "$brewfile"
}

# Create test Brewfile
TEST_BREWFILE=$(mktemp)
cat > "$TEST_BREWFILE" << 'EOF'
tap "homebrew/bundle"
# @preset: minimal
brew "zsh"
brew "tmux"
# @preset: core
brew "neovim"
cask "ghostty"
# @preset: full
cask "hammerspoon"
EOF

# Test minimal filtering
minimal_output=$(filter_brewfile "minimal" "$TEST_BREWFILE")
if [[ "$minimal_output" == *'brew "zsh"'* ]]; then
    pass "minimal preset includes zsh"
else
    fail "minimal preset should include zsh"
fi
if [[ "$minimal_output" != *'brew "neovim"'* ]]; then
    pass "minimal preset excludes neovim"
else
    fail "minimal preset should exclude neovim"
fi

# Test core filtering
core_output=$(filter_brewfile "core" "$TEST_BREWFILE")
if [[ "$core_output" == *'brew "neovim"'* ]]; then
    pass "core preset includes neovim"
else
    fail "core preset should include neovim"
fi
if [[ "$core_output" != *'cask "hammerspoon"'* ]]; then
    pass "core preset excludes hammerspoon"
else
    fail "core preset should exclude hammerspoon"
fi

# Test full filtering
full_output=$(filter_brewfile "full" "$TEST_BREWFILE")
if [[ "$full_output" == *'cask "hammerspoon"'* ]]; then
    pass "full preset includes hammerspoon"
else
    fail "full preset should include hammerspoon"
fi

rm -f "$TEST_BREWFILE"

section "should_install Helper"

# Define the helper for testing
should_install() {
    local required_preset="$1"
    local current_preset="$2"
    case "$required_preset" in
        minimal) return 0 ;;
        core) [[ "$current_preset" == "core" || "$current_preset" == "full" ]] ;;
        full) [[ "$current_preset" == "full" ]] ;;
    esac
}

# Test minimal preset
if should_install "minimal" "minimal"; then
    pass "minimal: should_install 'minimal' returns true"
else
    fail "minimal: should_install 'minimal' should return true"
fi
if ! should_install "core" "minimal"; then
    pass "minimal: should_install 'core' returns false"
else
    fail "minimal: should_install 'core' should return false"
fi

# Test core preset
if should_install "core" "core"; then
    pass "core: should_install 'core' returns true"
else
    fail "core: should_install 'core' should return true"
fi
if ! should_install "full" "core"; then
    pass "core: should_install 'full' returns false"
else
    fail "core: should_install 'full' should return false"
fi

# Test full preset
if should_install "full" "full"; then
    pass "full: should_install 'full' returns true"
else
    fail "full: should_install 'full' should return true"
fi

section "Install Script Help"

INSTALL_SCRIPT="$DOTFILES_DIR/install.sh"
if [[ -f "$INSTALL_SCRIPT" ]]; then
    help_output=$("$INSTALL_SCRIPT" --help 2>&1 || true)

    if [[ "$help_output" == *"--minimal"* ]]; then
        pass "Help shows --minimal flag"
    else
        fail "Help missing --minimal flag"
    fi
    if [[ "$help_output" == *"--core"* ]]; then
        pass "Help shows --core flag"
    else
        fail "Help missing --core flag"
    fi
    if [[ "$help_output" == *"--full"* ]]; then
        pass "Help shows --full flag"
    else
        fail "Help missing --full flag"
    fi
else
    fail "install.sh not found"
fi

section "Sub-script Preset Awareness"

check_reads_preset() {
    local script="$1"
    local name="$2"
    if [[ -f "$script" ]] && grep -q 'DOTFILES_PRESET' "$script"; then
        pass "$name reads DOTFILES_PRESET"
    elif [[ -f "$script" ]]; then
        fail "$name should read DOTFILES_PRESET"
    else
        skip "$name not found"
    fi
}

check_reads_preset "$SCRIPT_DIR/../install/install-packages.sh" "install-packages.sh"
check_reads_preset "$SCRIPT_DIR/../install/create-symlinks.sh" "create-symlinks.sh"
check_reads_preset "$SCRIPT_DIR/../install/backup-existing.sh" "backup-existing.sh"
check_reads_preset "$SCRIPT_DIR/../install/health-check.sh" "health-check.sh"
check_reads_preset "$SCRIPT_DIR/../install/check-prerequisites.sh" "check-prerequisites.sh"

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
