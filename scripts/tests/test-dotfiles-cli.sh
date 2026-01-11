#!/usr/bin/env bash
set -euo pipefail

# Unit tests for dotfiles CLI
# Tests the dotfiles command wrapper

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_CLI="$SCRIPT_DIR/../dotfiles"
DOTFILES_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")"

# Test counters
PASS=0
FAIL=0

# Colours
GREEN=$'\033[0;32m'
RED=$'\033[0;31m'
YELLOW=$'\033[0;33m'
NC=$'\033[0m'

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

# ===========================================================================
# Tests
# ===========================================================================

section "Script Exists and Is Executable"

if [[ -f "$DOTFILES_CLI" ]]; then
    pass "dotfiles CLI exists"
else
    fail "dotfiles CLI not found at $DOTFILES_CLI"
    exit 1
fi

if [[ -x "$DOTFILES_CLI" ]]; then
    pass "dotfiles CLI is executable"
else
    fail "dotfiles CLI is not executable"
fi

section "ShellCheck Validation"

if command -v shellcheck &>/dev/null; then
    if shellcheck -x -S warning -e SC1091 "$DOTFILES_CLI" 2>/dev/null; then
        pass "dotfiles CLI passes shellcheck"
    else
        fail "dotfiles CLI has shellcheck warnings"
    fi
else
    skip "shellcheck not installed"
fi

section "Help Command"

help_output=$("$DOTFILES_CLI" help 2>&1) || true

if [[ "$help_output" == *"Usage:"* ]]; then
    pass "help shows usage"
else
    fail "help should show usage"
fi

if [[ "$help_output" == *"update"* ]]; then
    pass "help mentions update command"
else
    fail "help should mention update command"
fi

if [[ "$help_output" == *"status"* ]]; then
    pass "help mentions status command"
else
    fail "help should mention status command"
fi

if [[ "$help_output" == *"health"* ]]; then
    pass "help mentions health command"
else
    fail "help should mention health command"
fi

if [[ "$help_output" == *"sync"* ]]; then
    pass "help mentions sync command"
else
    fail "help should mention sync command"
fi

if [[ "$help_output" == *"edit"* ]]; then
    pass "help mentions edit command"
else
    fail "help should mention edit command"
fi

if [[ "$help_output" == *"cd"* ]]; then
    pass "help mentions cd command"
else
    fail "help should mention cd command"
fi

# Test --help flag
help_flag_output=$("$DOTFILES_CLI" --help 2>&1) || true
if [[ "$help_flag_output" == *"Usage:"* ]]; then
    pass "--help flag works"
else
    fail "--help flag should show usage"
fi

section "CD Command"

cd_output=$("$DOTFILES_CLI" cd 2>&1) || true

if [[ "$cd_output" == *"dotfiles"* ]]; then
    pass "cd command returns dotfiles path"
else
    fail "cd command should return dotfiles path"
fi

if [[ -d "$cd_output" ]]; then
    pass "cd command returns valid directory"
else
    fail "cd command should return valid directory"
fi

section "Unknown Command Handling"

unknown_output=$("$DOTFILES_CLI" nonexistent_command_12345 2>&1) || true

if echo "$unknown_output" | grep -q "Unknown command"; then
    pass "Shows error for unknown command"
else
    fail "Should show error for unknown command"
fi

if echo "$unknown_output" | grep -q "Usage:"; then
    pass "Shows usage after unknown command error"
else
    fail "Should show usage after unknown command error"
fi

section "Script Structure"

script_content=$(cat "$DOTFILES_CLI")

# Check for required functions
if [[ "$script_content" == *"cmd_update()"* ]]; then
    pass "cmd_update function defined"
else
    fail "cmd_update function not found"
fi

if [[ "$script_content" == *"cmd_status()"* ]]; then
    pass "cmd_status function defined"
else
    fail "cmd_status function not found"
fi

if [[ "$script_content" == *"cmd_health()"* ]]; then
    pass "cmd_health function defined"
else
    fail "cmd_health function not found"
fi

if [[ "$script_content" == *"cmd_sync()"* ]]; then
    pass "cmd_sync function defined"
else
    fail "cmd_sync function not found"
fi

if [[ "$script_content" == *"get_preset()"* ]]; then
    pass "get_preset function defined"
else
    fail "get_preset function not found"
fi

if [[ "$script_content" == *"get_remote_branch()"* ]]; then
    pass "get_remote_branch function defined"
else
    fail "get_remote_branch function not found"
fi

section "Preset Configuration"

# Check that preset file path uses XDG
if [[ "$script_content" == *'XDG_CONFIG_HOME'* ]]; then
    pass "Uses XDG_CONFIG_HOME for config directory"
else
    fail "Should use XDG_CONFIG_HOME"
fi

# Check fallback to 'full' preset
if [[ "$script_content" == *'"full"'* ]]; then
    pass "Falls back to 'full' preset"
else
    fail "Should fall back to 'full' preset"
fi

section "Sources Common Library"

if [[ "$script_content" == *'source "$DOTFILES_DIR/scripts/_lib/common.sh"'* ]]; then
    pass "Sources common.sh library"
else
    fail "Should source common.sh library"
fi

section "Install.sh Preset Saving"

install_script="$DOTFILES_DIR/install.sh"
if [[ -f "$install_script" ]]; then
    install_content=$(cat "$install_script")

    if [[ "$install_content" == *'echo "$PRESET" >'* ]] || [[ "$install_content" == *'$PRESET_CONFIG_DIR/preset'* ]]; then
        pass "install.sh saves preset to config file"
    else
        fail "install.sh should save preset to config file"
    fi

    if [[ "$install_content" == *"Step 9"* ]]; then
        pass "install.sh has Step 9 for saving preset"
    else
        fail "install.sh should have Step 9 for saving preset"
    fi
else
    skip "install.sh not found"
fi

section "Create Symlinks Integration"

symlinks_script="$DOTFILES_DIR/scripts/install/create-symlinks.sh"
if [[ -f "$symlinks_script" ]]; then
    symlinks_content=$(cat "$symlinks_script")

    if [[ "$symlinks_content" == *'scripts/dotfiles'* ]]; then
        pass "create-symlinks.sh links dotfiles CLI"
    else
        fail "create-symlinks.sh should link dotfiles CLI"
    fi

    if [[ "$symlinks_content" == *'$HOME/bin/dotfiles'* ]]; then
        pass "dotfiles CLI linked to ~/bin/dotfiles"
    else
        fail "dotfiles CLI should be linked to ~/bin/dotfiles"
    fi
else
    skip "create-symlinks.sh not found"
fi

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
