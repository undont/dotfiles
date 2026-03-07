#!/usr/bin/env bash
# Shared test helpers for scripts/tests/ and scripts/_lib/ test suites
# Provides pass/fail/skip/section output and assertion helpers

# Determine dotfiles root from this file's location
_SCRIPTS_TEST_HELPERS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_ROOT="$(cd "$_SCRIPTS_TEST_HELPERS_DIR/../.." && pwd)"

# Source colour definitions
# shellcheck source=scripts/_lib/colours.sh
source "$DOTFILES_ROOT/scripts/_lib/colours.sh"

# Test counters
PASS=0
FAIL=0
SKIP=0

pass() {
    PASS=$((PASS + 1))
    printf "${GREEN}✓${NC} %s\n" "$1"
}

fail() {
    FAIL=$((FAIL + 1))
    printf "${RED}✗${NC} %s\n" "$1"
}

skip() {
    SKIP=$((SKIP + 1))
    printf "${YELLOW}○${NC} %s (skipped)\n" "$1"
}

section() {
    echo ""
    echo "─────────────────────────────────────────"
    echo "$1"
    echo "─────────────────────────────────────────"
}

assert_success() {
    local desc="$1"
    shift
    if "$@" 2>/dev/null; then
        pass "$desc"
    else
        fail "$desc"
    fi
}

assert_failure() {
    local desc="$1"
    shift
    if ! "$@" 2>/dev/null; then
        pass "$desc"
    else
        fail "$desc"
    fi
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

# Create a sandboxed test environment with isolated HOME
# Usage: setup_sandbox
# Sets: TEST_DIR, TEST_HOME, ORIGINAL_HOME
setup_sandbox() {
    TEST_DIR=$(mktemp -d)
    TEST_HOME="$TEST_DIR/home"
    mkdir -p "$TEST_HOME"
    ORIGINAL_HOME="$HOME"
    export HOME="$TEST_HOME"
}

# Clean up sandboxed test environment
# Usage: cleanup_sandbox
cleanup_sandbox() {
    export HOME="$ORIGINAL_HOME"
    rm -rf "$TEST_DIR"
}

# Create a minimal dotfiles structure in the sandbox for testing
# Usage: setup_dotfiles_sandbox
# Sets: TEST_DOTFILES_DIR (a copy/mock of the repo structure)
setup_dotfiles_sandbox() {
    setup_sandbox
    TEST_DOTFILES_DIR="$TEST_DIR/dotfiles"
    mkdir -p "$TEST_DOTFILES_DIR"
    export DOTFILES_DIR="$TEST_DOTFILES_DIR"
}

print_summary() {
    echo ""
    echo "==========================================="
    printf "Test Results: ${GREEN}%d passed${NC}, ${RED}%d failed${NC}" "$PASS" "$FAIL"
    if [[ $SKIP -gt 0 ]]; then
        printf ", ${YELLOW}%d skipped${NC}" "$SKIP"
    fi
    echo ""
    echo "==========================================="
}
