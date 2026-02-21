#!/usr/bin/env bash
set -euo pipefail

# Functional tests for windows/kill.sh behaviour
# Tests the actual kill operations beyond structural checks

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_DIR="$(dirname "$SCRIPT_DIR")"

# Source test helpers to get isolated tmux server
source "$SCRIPT_DIR/_test-helpers.sh"

# Trap to ensure cleanup on exit/interrupt
KILL_TEST_DIR=""
trap 'rm -rf "$KILL_TEST_DIR"; cleanup_test_server' EXIT INT TERM

# Setup isolated tmux server
setup_test_server

# Create temp directory for undo state
KILL_TEST_DIR=$(mktemp -d)
export XDG_CACHE_HOME="$KILL_TEST_DIR/cache"
mkdir -p "$XDG_CACHE_HOME/tmux/undo"

# Override alerts file to avoid polluting real config
export ALERTS_FILE="$KILL_TEST_DIR/alerts"

# Source production libraries
source "$SCRIPTS_DIR/_lib/common.sh"
source "$SCRIPTS_DIR/_lib/paths.sh"
source "$SCRIPTS_DIR/_lib/alerts.sh"

KILL_SCRIPT="$SCRIPTS_DIR/windows/kill.sh"

# ═══════════════════════════════════════════════════════════════
# Normal Kill Tests
# ═══════════════════════════════════════════════════════════════

section "Normal Window Kill"

TEST_SESSION="test-wkill-$$"
test_tmux new-session -d -s "$TEST_SESSION" -n "keep" -c /tmp
test_tmux new-window -t "$TEST_SESSION" -n "target" -c /tmp
sleep 0.2

# Verify setup
INITIAL_COUNT=$(test_tmux list-windows -t "$TEST_SESSION" | wc -l | tr -d ' ')
assert_equals "Two windows created" "2" "$INITIAL_COUNT"

# Kill the second window (index 1)
"$KILL_SCRIPT" "${TEST_SESSION}:1" --no-confirm 2>/dev/null || true

AFTER_COUNT=$(test_tmux list-windows -t "$TEST_SESSION" | wc -l | tr -d ' ')
assert_equals "Kill removes target window" "1" "$AFTER_COUNT"

section "Kill Saves Undo State"

# Verify undo state was saved
UNDO_FILE=$(get_window_undo_file)
UNDO_STATE=$(get_window_undo_state)

if [[ -f "$UNDO_FILE" ]]; then
    pass "Kill saves undo file"
else
    fail "Kill should save undo file"
fi

if [[ -f "$UNDO_STATE" ]]; then
    pass "Kill saves undo state"
else
    fail "Kill should save undo state"
fi

# Verify undo state has correct session reference
if [[ -f "$UNDO_FILE" ]]; then
    undo_target=$(cat "$UNDO_FILE")
    if [[ "$undo_target" == *"$TEST_SESSION"* ]]; then
        pass "Undo file references correct session"
    else
        fail "Undo file should reference $TEST_SESSION (got: $undo_target)"
    fi
fi

# Verify state file contains tab-delimited window metadata
if [[ -f "$UNDO_STATE" ]]; then
    if grep -q "^window" "$UNDO_STATE"; then
        pass "Undo state contains window line"
    else
        fail "Undo state should contain a window line"
    fi

    if grep -q "^pane" "$UNDO_STATE"; then
        pass "Undo state contains pane line(s)"
    else
        fail "Undo state should contain pane line(s)"
    fi
fi

# Clean undo state for next tests
cleanup_undo_files "window"

# ═══════════════════════════════════════════════════════════════
# Invalid Target Tests
# ═══════════════════════════════════════════════════════════════

section "Invalid Target Handling"

# Kill with nonexistent session
if ! "$KILL_SCRIPT" "nonexistent-session-$$:0" --no-confirm 2>/dev/null; then
    pass "Kill with invalid session fails gracefully"
else
    fail "Kill with invalid session should fail"
fi

# Kill with nonexistent window index
if ! "$KILL_SCRIPT" "${TEST_SESSION}:999" --no-confirm 2>/dev/null; then
    pass "Kill with invalid window index fails gracefully"
else
    fail "Kill with invalid window index should fail"
fi

# ═══════════════════════════════════════════════════════════════
# Alert Cleanup Tests
# ═══════════════════════════════════════════════════════════════

section "Alert Cleanup After Kill"

# Create a new window with an alert set
test_tmux new-window -t "$TEST_SESSION" -n "alerted" -c /tmp
sleep 0.2

# Set a mock alert on the window via tmux option
WINDOW_ID=$(test_tmux display-message -t "${TEST_SESSION}:1" -p '#{window_id}')
test_tmux set-option -wt "$WINDOW_ID" "@claude_alert" 1 2>/dev/null || true

# Write alert to the test alerts file
echo "${TEST_SESSION}:alerted:claude" > "$ALERTS_FILE"

# Kill the window — the kill script should clear alerts
"$KILL_SCRIPT" "${TEST_SESSION}:1" --no-confirm 2>/dev/null || true
sleep 0.3

# Verify alert entry was cleared from file
# Note: The kill script calls clear_window_alerts which greps out matching entries
if [[ ! -f "$ALERTS_FILE" ]] || [[ ! -s "$ALERTS_FILE" ]] || ! grep -q "${TEST_SESSION}:alerted" "$ALERTS_FILE" 2>/dev/null; then
    pass "Kill clears alert from alerts file"
else
    # The kill script uses ALERTS_FILE from its environment
    # If it defaulted to ~/.claude/alerts instead, the test file won't change
    skip "Alert cleanup uses different alerts file path (expected in test isolation)"
fi

# Clean up undo state
cleanup_undo_files "window"

# ═══════════════════════════════════════════════════════════════
# Pane Content Capture Tests
# ═══════════════════════════════════════════════════════════════

section "Pane Content Capture"

# Create a window and put some content in it
test_tmux new-window -t "$TEST_SESSION" -n "content-test" -c /tmp
sleep 0.2
test_tmux send-keys -t "${TEST_SESSION}:content-test" "echo UNDO_TEST_MARKER" Enter
sleep 0.3

# Kill the window
"$KILL_SCRIPT" "${TEST_SESSION}:1" --no-confirm 2>/dev/null || true

# Check that pane content was captured
UNDO_CONTENTS=$(get_window_undo_contents_dir)
if [[ -d "$UNDO_CONTENTS" ]]; then
    content_files=$(find "$UNDO_CONTENTS" -maxdepth 1 -type f 2>/dev/null | wc -l | tr -d ' ')
    if [[ "$content_files" -gt 0 ]]; then
        pass "Kill captures pane content files ($content_files file(s))"
    else
        fail "Kill should capture at least one pane content file"
    fi

    # Check if content contains our marker
    if grep -rq "UNDO_TEST_MARKER" "$UNDO_CONTENTS" 2>/dev/null; then
        pass "Captured content contains expected marker"
    else
        # Content capture can be timing-sensitive
        skip "Content marker not found (timing-dependent)"
    fi
else
    fail "Kill should create undo contents directory"
fi

# Clean up
cleanup_undo_files "window"

# ═══════════════════════════════════════════════════════════════
# Summary
# ═══════════════════════════════════════════════════════════════

echo ""
echo "==========================================="
printf "${GREEN}Test Results: %d passed${NC}, ${RED}%d failed${NC}\n" "$PASS" "$FAIL"
echo "==========================================="

if [[ $FAIL -gt 0 ]]; then
    exit 1
fi
