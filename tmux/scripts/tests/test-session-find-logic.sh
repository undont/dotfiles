#!/usr/bin/env bash
set -euo pipefail

# Unit tests for session logic (mocks tmux)
# This test verifies that find_other_session handles edge cases correctly
# specifically that it doesn't crash with pipefail when grep finds nothing.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$(dirname "$SCRIPT_DIR")/_lib"

# Mocks
# ---------------------------------------------------------

# Mock tmux command to simulate specific session states
# shellcheck disable=SC2329  # Mock function called indirectly via export -f
tmux() {
    case "$1" in
        list-sessions) 
            # Return predetermined output based on TEST_CASE variable
            echo "$TMUX_LIST_OUTPUT"
            ;;
        *)
            # Fallback to system tmux or error
            echo "Mock tmux received unexpected command: $*" >&2
            return 1
            ;;
    esac
}
export -f tmux

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
# Source the library under test
source "$LIB_DIR/session.sh"

echo "Running find_other_session logic tests..."
echo "-------------------------------------------"

# Test 1: Single session exists (No other session)
# ---------------------------------------------------------
TMUX_LIST_OUTPUT="1736780000 active_session"

# We expect find_other_session to return empty string and NOT exit with error
output=$(find_other_session "active_session")
exit_code=$?

if [[ $exit_code -eq 0 ]]; then
    if [[ -z "$output" ]]; then
        pass "Single session: Returns empty string correctly"
    else
        fail "Single session: Expected empty output, got '$output'"
    fi
else
    fail "Single session: Function exited with code $exit_code (crashed?)"
fi


# Test 2: Multiple sessions exist
# ---------------------------------------------------------
# Format: activity name
TMUX_LIST_OUTPUT=$'1736780000 active_session\n1736770000 older_session'

output=$(find_other_session "active_session")
exit_code=$?

if [[ $exit_code -eq 0 ]]; then
    if [[ "$output" == "older_session" ]]; then
        pass "Multiple sessions: Found correct alternative session"
    else
        fail "Multiple sessions: Expected 'older_session', got '$output'"
    fi
else
    fail "Multiple sessions: Function exited with code $exit_code"
fi

# Summary
# ---------------------------------------------------------
echo "-------------------------------------------"
if [[ $FAIL -eq 0 ]]; then
    echo "All $PASS tests passed."
    exit 0
else
    echo "$FAIL tests failed."
    exit 1
fi
