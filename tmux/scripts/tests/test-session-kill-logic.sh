#!/usr/bin/env bash
set -euo pipefail

# Unit/Integration tests for kill-session logic
# Mocks UI interactions to verify behavior without user input

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEST_SCRIPTS_DIR="$(dirname "$SCRIPT_DIR")"
LIB_DIR="$TEST_SCRIPTS_DIR/_lib"

# Source test helpers to get isolated tmux server
source "$SCRIPT_DIR/_test-helpers.sh"

# Trap to ensure cleanup on exit/interrupt
trap cleanup_test_server EXIT INT TERM

# Mocks
# ---------------------------------------------------------
# Create a mock UI library
MOCK_UI_LIB="/tmp/mock_ui_lib_$$.sh"
echo 'show_visual_confirm() { return 0; }' > "$MOCK_UI_LIB"
echo 'show_centered_confirm() { return 0; }' >> "$MOCK_UI_LIB"
echo 'show_centered_message() { :; }' >> "$MOCK_UI_LIB"

# Helpers
# ---------------------------------------------------------
PASS=0
FAIL=0

pass() {
    echo "✓ $1"
    PASS=$((PASS + 1))
}

fail() {
    echo "✗ $1"
    FAIL=$((FAIL + 1))
}

# Setup
# ---------------------------------------------------------
# Setup isolated tmux server for testing
setup_test_server

TEST_SESSION_1="test_kill_1_$$"
TEST_SESSION_2="test_kill_2_$$"

# Create two test sessions
test_tmux new-session -d -s "$TEST_SESSION_1" -c /tmp
test_tmux new-session -d -s "$TEST_SESSION_2" -c /tmp

echo "Created test sessions: $TEST_SESSION_1, $TEST_SESSION_2"

# Test 1: Kill inactive session (should just kill it)
# ---------------------------------------------------------
echo "Test 1: Kill inactive session ($TEST_SESSION_2)"

# Run kill-session.sh targeting TEST_SESSION_2 with --no-confirm flag
"$TEST_SCRIPTS_DIR/sessions/kill.sh" "$TEST_SESSION_2" --no-confirm >/dev/null

if ! test_tmux has-session -t "$TEST_SESSION_2" 2>/dev/null; then
    pass "Inactive session killed successfully"
else
    fail "Inactive session still exists"
fi


# Test 2: Kill remaining session with --no-confirm
# ---------------------------------------------------------
# Note: Testing the "active session + switch" path requires an actual attached
# client, which isn't possible in an isolated test server. Instead we verify
# killing the remaining session directly.
echo "Test 2: Kill remaining session ($TEST_SESSION_1)"

# Create a third session so we don't try to kill the last one
TEST_SESSION_3="test_kill_3_$$"
test_tmux new-session -d -s "$TEST_SESSION_3" -c /tmp

"$TEST_SCRIPTS_DIR/sessions/kill.sh" "$TEST_SESSION_1" --no-confirm >/dev/null 2>&1 || true

if ! test_tmux has-session -t "$TEST_SESSION_1" 2>/dev/null; then
    pass "Remaining session killed successfully"
else
    fail "Remaining session still exists"
fi

# Cleanup
rm -f "$MOCK_UI_LIB"
test_tmux kill-session -t "$TEST_SESSION_1" 2>/dev/null || true
test_tmux kill-session -t "$TEST_SESSION_2" 2>/dev/null || true
test_tmux kill-session -t "${TEST_SESSION_3:-}" 2>/dev/null || true

# Cleanup isolated tmux server
cleanup_test_server

echo "-------------------------------------------"
if [[ $FAIL -eq 0 ]]; then
    echo "All $PASS tests passed."
    exit 0
else
    echo "$FAIL tests failed."
    exit 1
fi
