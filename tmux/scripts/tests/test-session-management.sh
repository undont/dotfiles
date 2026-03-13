#!/usr/bin/env bash
set -euo pipefail

# Integration tests for session management operations
# Usage: ./test-session-management.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_DIR="$(dirname "$SCRIPT_DIR")"
LIB_DIR="$SCRIPTS_DIR/_lib"

# Source test helpers to get isolated tmux server
source "$SCRIPT_DIR/_test-helpers.sh"

# Trap to ensure cleanup on exit/interrupt
trap cleanup_test_server EXIT INT TERM

# Note: Colours (GREEN, RED, etc.) and test helpers (pass, fail, skip, section)
# are already provided by _test-helpers.sh

# Setup isolated tmux server for testing
setup_test_server

# Create a test session to work with
TEST_SESSION="test-session-$$"
test_tmux new-session -d -s "$TEST_SESSION" -c /tmp

# Source libraries
source "$LIB_DIR/common.sh"
source "$LIB_DIR/session.sh"

section "Session Library Tests"

# Test session_exists with our test session
if session_exists "$TEST_SESSION"; then
    pass "session_exists returns true for test session"
else
    fail "session_exists should return true for test session"
fi

if ! session_exists "nonexistent-session-12345"; then
    pass "session_exists returns false for nonexistent session"
else
    fail "session_exists should return false for nonexistent"
fi

section "Validation Tests"

# Test validate_session_name
assert_valid_name() {
    local name="$1"
    if validate_session_name "$name" 2>/dev/null; then
        pass "validate_session_name accepts: '$name'"
    else
        fail "validate_session_name should accept: '$name'"
    fi
}

assert_invalid_name() {
    local name="$1"
    if ! validate_session_name "$name" 2>/dev/null; then
        pass "validate_session_name rejects: '$name'"
    else
        fail "validate_session_name should reject: '$name'"
    fi
}

# Valid session names
assert_valid_name "myproject"
assert_valid_name "my-project"
assert_valid_name "my_project"
assert_invalid_name "my.project"
assert_valid_name "project123"
assert_valid_name "123"

# Invalid session names
assert_invalid_name ""
assert_invalid_name "my project"
assert_invalid_name "my:project"
assert_invalid_name "my/project"
assert_invalid_name "my\$project"

section "Session Switching Tests"

# Create a second test session so find_other_session has something to find
TEST_SESSION_2="test-session-2-$$"
test_tmux new-session -d -s "$TEST_SESSION_2" -c /tmp
pass "Created second test session: $TEST_SESSION_2"

# Test find_other_session using our first test session
other=$(find_other_session "$TEST_SESSION")
if [[ -n "$other" ]]; then
    pass "find_other_session found: $other"
else
    fail "find_other_session should find another session"
fi

# Cleanup both test sessions
test_tmux kill-session -t "$TEST_SESSION_2" 2>/dev/null || true

# Cleanup
test_tmux kill-session -t "$TEST_SESSION" 2>/dev/null || true
pass "Cleaned up test session"

# Cleanup isolated tmux server
cleanup_test_server

# ===========================================================================
# Summary
# ===========================================================================

echo ""
echo "==========================================="
printf "${GREEN}Test Results: %d passed${NC}, ${RED}%d failed${NC}\n" "$PASS" "$FAIL"
echo "==========================================="

if [[ $FAIL -gt 0 ]]; then
    exit 1
fi
