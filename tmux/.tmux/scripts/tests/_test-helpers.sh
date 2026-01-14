#!/usr/bin/env bash
# Test helpers for tmux scripts
# Provides isolated tmux server for testing

# Colours for test output
GREEN=$'\033[0;32m'
RED=$'\033[0;31m'
YELLOW=$'\033[0;33m'
NC=$'\033[0m'

pass() { echo "${GREEN}✓${NC} $1"; }
fail() { echo "${RED}✗${NC} $1"; }
section() { echo ""; echo "${YELLOW}=== $1 ===${NC}"; }

# Create isolated tmux server for testing
# Usage: setup_test_server
# Returns: Sets TEST_TMUX_SOCKET and TEST_TMUX_CMD
setup_test_server() {
    TEST_TMUX_SOCKET="/tmp/tmux-test-$$"
    TEST_TMUX_CMD="tmux -L tmux-test-$$"
    
    # Start a detached server
    $TEST_TMUX_CMD new-session -d -s test-bootstrap 2>/dev/null || true
    
    export TMUX=""  # Clear TMUX variable so commands use our socket
}

# Cleanup test server
# Usage: cleanup_test_server
cleanup_test_server() {
    if [[ -n "${TEST_TMUX_CMD:-}" ]]; then
        $TEST_TMUX_CMD kill-server 2>/dev/null || true
    fi
    if [[ -n "${TEST_TMUX_SOCKET:-}" ]]; then
        rm -f "$TEST_TMUX_SOCKET" 2>/dev/null || true
    fi
}

# Wrapper to run tmux commands in test server
# Usage: test_tmux <tmux-args>
test_tmux() {
    $TEST_TMUX_CMD "$@"
}

# Export these for use in test scripts
export -f setup_test_server
export -f cleanup_test_server
export -f test_tmux
export -f pass
export -f fail
export -f section
