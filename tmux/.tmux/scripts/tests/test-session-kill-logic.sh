#!/usr/bin/env bash
set -euo pipefail

# Unit/Integration tests for kill-session logic
# Mocks UI interactions to verify behavior without user input

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEST_SCRIPTS_DIR="$(dirname "$SCRIPT_DIR")"
LIB_DIR="$TEST_SCRIPTS_DIR/_lib"

# Source test helpers to get isolated tmux server
source "$SCRIPT_DIR/_test-helpers.sh"

# Mocks
# ---------------------------------------------------------
# Create a mock UI library
MOCK_UI_LIB="/tmp/mock_ui_lib_$$.sh"
echo 'show_centered_confirm() { return 0; }' > "$MOCK_UI_LIB"
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
"$TEST_SCRIPTS_DIR/kill-session.sh" "$TEST_SESSION_2" --no-confirm >/dev/null

if ! tmux has-session -t "$TEST_SESSION_2" 2>/dev/null; then
    pass "Inactive session killed successfully"
else
    fail "Inactive session still exists"
fi


# Test 2: Kill active session (should switch then kill)
# ---------------------------------------------------------
echo "Test 2: Kill active session ($TEST_SESSION_1)"

TEST_SCRIPT_COPY="/tmp/kill-session-test-copy.sh"

# Construct the mocked script
# 1. Read the original script
# 2. Inject source "$MOCK_UI_LIB" after existing sources (line 10)
# 3. Inject mock get_current_session after that

# Read lines 1-10
head -n 10 "$TEST_SCRIPTS_DIR/kill-session.sh" > "$TEST_SCRIPT_COPY"

# Inject mocks
cat <<EOF >> "$TEST_SCRIPT_COPY"
source "$MOCK_UI_LIB"
get_current_session() { echo "$TEST_SESSION_1"; }
EOF

# Read the rest of the file (from line 11)
tail -n +11 "$TEST_SCRIPTS_DIR/kill-session.sh" >> "$TEST_SCRIPT_COPY"

# Fix SCRIPT_DIR to point to the original location so imports work
# We replace line 7 directly (where SCRIPT_DIR is defined)
sed -i '' '7s|^.*$|SCRIPT_DIR="'"$TEST_SCRIPTS_DIR"'"|' "$TEST_SCRIPT_COPY"

# Make executable
chmod +x "$TEST_SCRIPT_COPY"

# Run it
echo "Running mocked kill-session..."
"$TEST_SCRIPT_COPY" "$TEST_SESSION_1" >/dev/null

if ! tmux has-session -t "$TEST_SESSION_1" 2>/dev/null; then
    pass "Active session (mocked) killed successfully"
else
    fail "Active session (mocked) still exists"
fi

# Cleanup
rm -f "$MOCK_UI_LIB" "$TEST_SCRIPT_COPY"
test_tmux kill-session -t "$TEST_SESSION_1" 2>/dev/null || true
test_tmux kill-session -t "$TEST_SESSION_2" 2>/dev/null || true

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
