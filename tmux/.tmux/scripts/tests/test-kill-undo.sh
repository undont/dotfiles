#!/usr/bin/env bash
set -euo pipefail

# Integration tests for kill/undo operations
# Usage: ./test-kill-undo.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_DIR="$(dirname "$SCRIPT_DIR")"
LIB_DIR="$SCRIPTS_DIR/_lib"

# Source test helpers to get isolated tmux server
source "$SCRIPT_DIR/_test-helpers.sh"

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

section "Setup Test Environment"

# Setup isolated tmux server for testing
setup_test_server
pass "Created isolated tmux server"

# Create a test session
TEST_SESSION="test-kill-undo-$$"
test_tmux new-session -d -s "$TEST_SESSION" -c /tmp
pass "Created test session: $TEST_SESSION"

# Source libraries needed for test
source "$LIB_DIR/common.sh"
source "$LIB_DIR/paths.sh"
source "$LIB_DIR/session.sh"

section "Window Kill/Undo Tests"

# Create a second window
test_tmux new-window -t "$TEST_SESSION" -n "test-window" -c /tmp
sleep 0.5

WINDOW_COUNT_BEFORE=$(test_tmux list-windows -t "$TEST_SESSION" | wc -l | tr -d ' ')
if [[ "$WINDOW_COUNT_BEFORE" -eq 2 ]]; then
    pass "Created second window (count: $WINDOW_COUNT_BEFORE)"
else
    fail "Expected 2 windows, got $WINDOW_COUNT_BEFORE"
fi

# Kill the second window (index 2) using kill-window.sh with explicit target
WINDOW_TO_KILL="${TEST_SESSION}:2"
"$SCRIPTS_DIR/kill-window.sh" "$WINDOW_TO_KILL" 2>/dev/null || true
sleep 0.5

WINDOW_COUNT_AFTER=$(test_tmux list-windows -t "$TEST_SESSION" | wc -l | tr -d ' ')
if [[ "$WINDOW_COUNT_AFTER" -eq 1 ]]; then
    pass "kill-window.sh reduced window count to 1"
else
    fail "Expected 1 window after kill, got $WINDOW_COUNT_AFTER"
fi

# Check undo file was created
WINDOW_UNDO_FILE=$(get_window_undo_file)
if [[ -f "$WINDOW_UNDO_FILE" ]]; then
    pass "Window undo file created"
else
    fail "Window undo file not found: $WINDOW_UNDO_FILE"
fi

# Undo the window kill
"$SCRIPTS_DIR/undo-window.sh" 2>/dev/null || true
sleep 0.5

WINDOW_COUNT_RESTORED=$(test_tmux list-windows -t "$TEST_SESSION" | wc -l | tr -d ' ')
if [[ "$WINDOW_COUNT_RESTORED" -eq 2 ]]; then
    pass "undo-window.sh restored window (count: $WINDOW_COUNT_RESTORED)"
else
    fail "Expected 2 windows after undo, got $WINDOW_COUNT_RESTORED"
fi

section "Cleanup"

# Kill test session
test_tmux kill-session -t "$TEST_SESSION" 2>/dev/null || true
pass "Cleaned up test session"

# Clean up undo files
cleanup_undo_files "pane" 2>/dev/null || true
cleanup_undo_files "window" 2>/dev/null || true
pass "Cleaned up undo files"

# Cleanup isolated tmux server
cleanup_test_server
pass "Cleaned up tmux server"

echo ""
echo "==========================================="
echo "Test Results: ${GREEN}${PASS} passed${NC}, ${RED}${FAIL} failed${NC}"
echo "==========================================="

[[ $FAIL -eq 0 ]]
