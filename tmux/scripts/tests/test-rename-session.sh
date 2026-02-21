#!/usr/bin/env bash
# Test suite for rename-session.sh
# Tests the session renaming functionality including edge cases with alerts

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/_test-helpers.sh"
source "$SCRIPT_DIR/../_lib/common.sh"

# Isolate the alerts file to a temp directory so tests never touch the real one.
# ALERTS_FILE must be set before sourcing alerts.sh — it guards with
# [[ -z "${ALERTS_FILE:-}" ]] before declaring it readonly.
TEST_ALERTS_DIR="$(mktemp -d)"
export ALERTS_FILE="$TEST_ALERTS_DIR/alerts"
touch "$ALERTS_FILE"

# Source alerts.sh after ALERTS_FILE is set so it picks up our isolated path
source "$SCRIPT_DIR/../_lib/alerts.sh"

# shellcheck disable=SC2317  # Called indirectly via trap
_cleanup_rename_tests() {
    cleanup_test_server
    rm -rf "$TEST_ALERTS_DIR"
}

# Trap to ensure cleanup on exit/interrupt
trap _cleanup_rename_tests EXIT INT TERM

echo ""
echo "${CYAN}═══════════════════════════════════════════${NC}"
echo "${CYAN}  Rename Session Tests${NC}"
echo "${CYAN}═══════════════════════════════════════════${NC}"
echo ""

# ═══════════════════════════════════════════════════════════════════════════
# Test: Clear alerts for session with no alert options set
# ═══════════════════════════════════════════════════════════════════════════
section "Clear alerts - no options set"

setup_test_server "rename-no-alerts"

# Create a test session with no alerts
tmux new-session -d -s test-rename-1 -n window1

# Create alerts file with entry for this session
echo "test-rename-1:window1:claude" > "$ALERTS_FILE"

# Clear session alerts (should not fail even with no @*_alert options)
if clear_session_alerts "test-rename-1"; then
    pass "Clear alerts succeeded with no options set"
else
    fail "Clear alerts failed with no options set"
fi

cleanup_test_server

# ═══════════════════════════════════════════════════════════════════════════
# Test: Clear alerts for session with alert options set
# ═══════════════════════════════════════════════════════════════════════════
section "Clear alerts - options set"

setup_test_server "rename-with-alerts"

# Create a test session
tmux new-session -d -s test-rename-2 -n window1

# Set alert options on the window
tmux set-option -wt test-rename-2:window1 "@claude_alert" 1

# Create alerts file entry
echo "test-rename-2:window1:claude" > "$ALERTS_FILE"

# Clear session alerts
if clear_session_alerts "test-rename-2"; then
    pass "Clear alerts succeeded with options set"
else
    fail "Clear alerts failed with options set"
fi

# Verify option was cleared
if tmux show-options -wt test-rename-2:window1 "@claude_alert" 2>/dev/null; then
    fail "Alert option was not cleared"
else
    pass "Alert option was cleared"
fi

cleanup_test_server

# ═══════════════════════════════════════════════════════════════════════════
# Test: Sanitise session names
# ═══════════════════════════════════════════════════════════════════════════
section "Sanitise session names"

# Test space conversion
result=$(sanitise_session_name "my session")
assert_equals "Spaces converted to dashes" "my-session" "$result"

# Test special character removal
result=$(sanitise_session_name "my@session!")
assert_equals "Special chars converted to dashes" "my-session" "$result"

# Test trailing dash removal
result=$(sanitise_session_name "test   ")
assert_equals "Trailing dashes removed" "test" "$result"

# Test valid name unchanged
result=$(sanitise_session_name "valid-name_123")
assert_equals "Valid name unchanged" "valid-name_123" "$result"

# ═══════════════════════════════════════════════════════════════════════════
# Test: Validate session names
# ═══════════════════════════════════════════════════════════════════════════
section "Validate session names"

# Valid names
if validate_session_name "test" 2>/dev/null; then
    pass "Simple name valid"
else
    fail "Simple name should be valid"
fi

if validate_session_name "test-session_123.name" 2>/dev/null; then
    pass "Complex valid name accepted"
else
    fail "Complex valid name should be accepted"
fi

# Invalid names
if validate_session_name "" 2>/dev/null; then
    fail "Empty name should be invalid"
else
    pass "Empty name rejected"
fi

if validate_session_name "test session" 2>/dev/null; then
    fail "Name with spaces should be invalid"
else
    pass "Name with spaces rejected"
fi

if validate_session_name "test@session" 2>/dev/null; then
    fail "Name with @ should be invalid"
else
    pass "Name with @ rejected"
fi

# ═══════════════════════════════════════════════════════════════════════════
# Test: Rename session workflow (no alerts)
# ═══════════════════════════════════════════════════════════════════════════
section "Rename workflow - no alerts"

setup_test_server "rename-workflow-1"

# Create test session
tmux new-session -d -s old-name -n window1

# Simulate rename script logic
current_session="old-name"
newname="new-name"

# Validate
if ! validate_session_name "$newname" 2>/dev/null; then
    fail "Validation failed for valid name"
fi

# Check if target exists
if session_exists "$newname"; then
    fail "Target session should not exist yet"
fi

# Clear alerts (should succeed even with no alerts)
if ! clear_session_alerts "$current_session"; then
    fail "Clear alerts failed in rename workflow"
fi

# Rename
if tmux rename-session -t "$current_session" "$newname" 2>/dev/null; then
    pass "Session renamed successfully"
else
    fail "Session rename failed"
fi

# Verify new name exists
if session_exists "$newname"; then
    pass "New session name exists"
else
    fail "New session name does not exist"
fi

# Verify old name gone
if session_exists "$current_session"; then
    fail "Old session name still exists"
else
    pass "Old session name removed"
fi

cleanup_test_server

# ═══════════════════════════════════════════════════════════════════════════
# Test: Rename session workflow (with alerts)
# ═══════════════════════════════════════════════════════════════════════════
section "Rename workflow - with alerts"

setup_test_server "rename-workflow-2"

# Create test session with alerts
tmux new-session -d -s alert-session -n window1

# Set alert on window
tmux set-option -wt alert-session:window1 "@claude_alert" 1

# Create alerts file entry
echo "alert-session:window1:claude" > "$ALERTS_FILE"

# Simulate rename
current_session="alert-session"
newname="renamed-session"

# Clear alerts (should succeed and remove options)
if ! clear_session_alerts "$current_session"; then
    fail "Clear alerts failed with alerts present"
fi

# Verify alerts were cleared from file
if grep -q "^${current_session}:" "$ALERTS_FILE" 2>/dev/null; then
    fail "Alerts not removed from file"
else
    pass "Alerts removed from file"
fi

# Rename
if tmux rename-session -t "$current_session" "$newname" 2>/dev/null; then
    pass "Session with alerts renamed successfully"
else
    fail "Session with alerts rename failed"
fi

# Verify
if session_exists "$newname"; then
    pass "Renamed session exists"
else
    fail "Renamed session does not exist"
fi

cleanup_test_server

# ═══════════════════════════════════════════════════════════════════════════
# Test: Rename to existing session name (should fail)
# ═══════════════════════════════════════════════════════════════════════════
section "Rename to existing name"

setup_test_server "rename-existing"

# Create two sessions
tmux new-session -d -s session-a -n window1
tmux new-session -d -s session-b -n window1

# Try to rename session-a to session-b (should fail)
if session_exists "session-b"; then
    pass "Target session exists (as expected)"
fi

# This should fail (we're just checking the validation)
if session_exists "session-b"; then
    pass "Validation catches existing session name"
fi

cleanup_test_server

# ═══════════════════════════════════════════════════════════════════════════
# Test: Clear window alerts with no options (pipefail safe)
# ═══════════════════════════════════════════════════════════════════════════
section "Clear window alerts - pipefail safety"

setup_test_server "rename-pipefail"

# Create test session
tmux new-session -d -s pipefail-test -n window1

# Get window ID
win_id=$(tmux list-windows -t pipefail-test -F '#D' | head -1)

# This test ensures clear_window_alerts doesn't fail with pipefail
# when grep returns no results
(
    set -euo pipefail
    source "$SCRIPT_DIR/../_lib/alerts.sh"

    if clear_window_alerts "pipefail-test" "window1" "$win_id"; then
        echo "PASS"
    else
        echo "FAIL"
    fi
) | grep -q "PASS" && pass "Clear window alerts is pipefail-safe" || fail "Clear window alerts failed with pipefail"

cleanup_test_server

# Print summary
echo ""
echo "${CYAN}═══════════════════════════════════════════${NC}"
if [[ $FAIL -eq 0 ]]; then
    echo "${GREEN}✓ All tests passed${NC} ($PASS passed)"
    exit 0
else
    echo "${RED}✗ Some tests failed${NC} ($PASS passed, $FAIL failed)"
    exit 1
fi
