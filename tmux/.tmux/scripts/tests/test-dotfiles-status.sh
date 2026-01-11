#!/usr/bin/env bash
set -euo pipefail

# Unit tests for dotfiles-status.sh
# Tests the git sync status indicator logic

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_STATUS_SCRIPT="$SCRIPT_DIR/../dotfiles-status.sh"

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

if [[ -f "$DOTFILES_STATUS_SCRIPT" ]]; then
    pass "dotfiles-status.sh exists"
else
    fail "dotfiles-status.sh not found at $DOTFILES_STATUS_SCRIPT"
    exit 1
fi

if [[ -x "$DOTFILES_STATUS_SCRIPT" ]]; then
    pass "dotfiles-status.sh is executable"
else
    fail "dotfiles-status.sh is not executable"
fi

section "ShellCheck Validation"

if command -v shellcheck &>/dev/null; then
    if shellcheck -x -S warning "$DOTFILES_STATUS_SCRIPT" 2>/dev/null; then
        pass "dotfiles-status.sh passes shellcheck"
    else
        fail "dotfiles-status.sh has shellcheck warnings"
    fi
else
    skip "shellcheck not installed"
fi

section "Script Structure"

# Check for required functions
script_content=$(cat "$DOTFILES_STATUS_SCRIPT")

if [[ "$script_content" == *"get_remote_branch()"* ]]; then
    pass "get_remote_branch function defined"
else
    fail "get_remote_branch function not found"
fi

if [[ "$script_content" == *"maybe_fetch()"* ]]; then
    pass "maybe_fetch function defined"
else
    fail "maybe_fetch function not found"
fi

if [[ "$script_content" == *"bail()"* ]]; then
    pass "bail helper function defined"
else
    fail "bail helper function not found"
fi

section "Output Format"

# Check that output indicators are correct
if [[ "$script_content" == *'output="↓ "'* ]]; then
    pass "Behind indicator (↓) defined"
else
    fail "Behind indicator not found"
fi

if [[ "$script_content" == *'output="↑ "'* ]]; then
    pass "Ahead indicator (↑) defined"
else
    fail "Ahead indicator not found"
fi

if [[ "$script_content" == *'output="↕ "'* ]]; then
    pass "Diverged indicator (↕) defined"
else
    fail "Diverged indicator not found"
fi

section "Cache Configuration"

if [[ "$script_content" == *'CACHE_TTL_SECONDS'* ]]; then
    pass "Cache TTL is configurable"
else
    fail "Cache TTL configuration not found"
fi

if [[ "$script_content" == *'XDG_CACHE_HOME'* ]]; then
    pass "Uses XDG_CACHE_HOME for cache directory"
else
    fail "Should use XDG_CACHE_HOME"
fi

section "Error Handling"

# Script should handle missing git gracefully
if [[ "$script_content" == *"git rev-parse --git-dir"* ]]; then
    pass "Checks for valid git repository"
else
    fail "Should check for valid git repository"
fi

# Script should handle missing remote gracefully
if [[ "$script_content" == *"origin/main"* ]] && [[ "$script_content" == *"origin/master"* ]]; then
    pass "Handles both main and master branches"
else
    fail "Should handle both main and master branches"
fi

section "Silent Failure"

# Script should exit silently on errors (for tmux status bar)
if [[ "$script_content" == *"exit 0"* ]] && [[ "$script_content" == *"bail()"* ]]; then
    pass "Exits cleanly on errors (silent failure)"
else
    fail "Should exit cleanly on errors"
fi

# ===========================================================================
# Integration test (only if in git repo)
# ===========================================================================

section "Integration (Live Execution)"

# Create a temporary directory for testing
TEST_DIR=$(mktemp -d)
trap 'rm -rf "$TEST_DIR"' EXIT

# Test with non-git directory (should output nothing)
DOTFILES_DIR="$TEST_DIR" output=$("$DOTFILES_STATUS_SCRIPT" 2>/dev/null) || true
if [[ -z "$output" ]]; then
    pass "Returns empty output for non-git directory"
else
    fail "Should return empty output for non-git directory (got: '$output')"
fi

# Test with actual dotfiles directory
REAL_DOTFILES_DIR="$(dirname "$(dirname "$(dirname "$(dirname "$SCRIPT_DIR")")")")"
if [[ -d "$REAL_DOTFILES_DIR/.git" ]]; then
    # Script should run without error
    if DOTFILES_DIR="$REAL_DOTFILES_DIR" "$DOTFILES_STATUS_SCRIPT" >/dev/null 2>&1; then
        pass "Runs successfully on real dotfiles repo"
    else
        fail "Failed to run on real dotfiles repo"
    fi

    # Output should be one of: empty, "↓ ", "↑ ", "↕ "
    output=$(DOTFILES_DIR="$REAL_DOTFILES_DIR" "$DOTFILES_STATUS_SCRIPT" 2>/dev/null) || true
    case "$output" in
        ""|"↓ "|"↑ "|"↕ ")
            pass "Output format is valid: '${output:-<empty>}'"
            ;;
        *)
            fail "Unexpected output format: '$output'"
            ;;
    esac
else
    skip "Real dotfiles directory not a git repo"
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
