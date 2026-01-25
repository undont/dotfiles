#!/usr/bin/env bash
# Test helpers for tmux scripts
# Provides isolated tmux server for testing

# Colours for test output
GREEN=$'\033[0;32m'
RED=$'\033[0;31m'
YELLOW=$'\033[0;33m'
CYAN=$'\033[0;36m'
NC=$'\033[0m'

# Test counters (can be used by test scripts)
PASS=0
FAIL=0

pass() {
    PASS=$((PASS + 1))
    printf "${GREEN}✓${NC} %s\n" "$1"
}

fail() {
    FAIL=$((FAIL + 1))
    printf "${RED}✗${NC} %s\n" "$1"
}

skip() {
    printf "${CYAN}⊘${NC} %s (skipped)\n" "$1"
}

section() {
    echo ""
    printf "${YELLOW}=== %s ===${NC}\n" "$1"
}

# Create isolated tmux server for testing
# Usage: setup_test_server
# Returns: Sets TEST_TMUX_SOCKET and TEST_TMUX_CMD
setup_test_server() {
    TEST_TMUX_SOCKET="tmux-test-$$"
    TEST_TMUX_CMD="tmux -L $TEST_TMUX_SOCKET"
    
    # Start a detached server
    $TEST_TMUX_CMD new-session -d -s test-bootstrap 2>/dev/null || true
    
    # Export socket name for scripts to use
    # Scripts will check this variable and add -L flag if set
    export TMUX_TEST_SOCKET="$TEST_TMUX_SOCKET"
    
    # Enable test mode to bypass require_tmux's "inside tmux" check
    export TMUX_TEST_MODE=1
    export TMUX=""  # Clear TMUX variable so scripts don't think they're inside tmux
}

# Cleanup test server
# Usage: cleanup_test_server
cleanup_test_server() {
    if [[ -n "${TEST_TMUX_CMD:-}" ]]; then
        $TEST_TMUX_CMD kill-server 2>/dev/null || true
    fi
    if [[ -n "${TEST_TMUX_SOCKET:-}" ]]; then
        rm -f "/tmp/$TEST_TMUX_SOCKET" 2>/dev/null || true
    fi
    
    # Disable test mode and unset test socket
    unset TMUX_TEST_MODE
    unset TMUX_TEST_SOCKET
}

# Wrapper to run tmux commands in test server
# Usage: test_tmux <tmux-args>
test_tmux() {
    # Use command to bypass the wrapper function
    command tmux -L "$TEST_TMUX_SOCKET" "$@"
}

# Export these for use in test scripts
export -f setup_test_server
export -f cleanup_test_server
export -f test_tmux
export -f pass
export -f fail
export -f skip
export -f section
