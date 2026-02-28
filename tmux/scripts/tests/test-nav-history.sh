#!/usr/bin/env bash
set -euo pipefail

# Tests for browser-style navigation history (nav.sh)
# Usage: ./test-nav-history.sh
# Requires: tmux (uses isolated test server)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_DIR="$(dirname "$SCRIPT_DIR")"
NAV_SCRIPT="$SCRIPTS_DIR/utils/nav.sh"

# Source test helpers to get isolated tmux server
source "$SCRIPT_DIR/_test-helpers.sh"

# Use temp dir for nav cache to avoid polluting real cache
TEST_NAV_DIR=$(mktemp -d)
export XDG_CACHE_HOME="$TEST_NAV_DIR"

# Cleanup on exit
# shellcheck disable=SC2329
cleanup() {
    cleanup_test_server
    rm -rf "$TEST_NAV_DIR"
}
trap cleanup EXIT INT TERM

# Source common.sh so nav.sh gets the tmux wrapper
source "$SCRIPTS_DIR/_lib/common.sh"

# Setup isolated tmux server
setup_test_server

# Create test session with multiple windows
TEST_SESSION="nav-test-$$"
test_tmux new-session -d -s "$TEST_SESSION"
WIN1=$(test_tmux display-message -t "$TEST_SESSION" -p '#{window_id}')
test_tmux new-window -t "$TEST_SESSION"
WIN2=$(test_tmux display-message -t "$TEST_SESSION" -p '#{window_id}')
test_tmux new-window -t "$TEST_SESSION"
WIN3=$(test_tmux display-message -t "$TEST_SESSION" -p '#{window_id}')

# Nav file paths (matching nav.sh internal paths)
NAV_CACHE="$TEST_NAV_DIR/tmux/nav"
HISTORY_FILE="$NAV_CACHE/history"
POS_FILE="$NAV_CACHE/position"
LAST_FILE="$NAV_CACHE/last"

# Helper: get the active window in the test session (works without a client)
get_active_window() {
    test_tmux list-windows -t "$TEST_SESSION" -F '#{window_active} #{window_id}' \
        | awk '/^1 /{print $2}'
}

# Helper: get position
get_pos() {
    [[ -f "$POS_FILE" ]] && cat "$POS_FILE" || echo "0"
}

# Helper: count history lines
count_history() {
    [[ -f "$HISTORY_FILE" ]] && wc -l < "$HISTORY_FILE" | tr -d ' ' || echo "0"
}

# Helper: reset nav state for clean test sections
reset_nav() {
    rm -rf "$NAV_CACHE"
    tmux set-option -gq @nav-skip "" 2>/dev/null || true
}

# ═══════════════════════════════════════════════════
section "Record basics"
# ═══════════════════════════════════════════════════

reset_nav

# Record a window — should create history file
"$NAV_SCRIPT" record "$WIN1"
if [[ -f "$HISTORY_FILE" ]]; then
    pass "record creates history file"
else
    fail "record creates history file"
fi

assert_equals "first record writes window ID" "$WIN1" "$(tail -n1 "$HISTORY_FILE")"

# Record same window again — should not duplicate
"$NAV_SCRIPT" record "$WIN1"
assert_equals "consecutive duplicate is skipped" "1" "$(count_history)"

# Record a different window — departure + arrival
"$NAV_SCRIPT" record "$WIN2"
local_count=$(count_history)
assert_equals "second record adds entry" "2" "$local_count"
assert_equals "last entry is WIN2" "$WIN2" "$(tail -n1 "$HISTORY_FILE")"

# LAST_FILE tracks previous window
assert_equals "LAST_FILE tracks current" "$WIN2" "$(cat "$LAST_FILE")"

# Record invalid window ID — should exit silently
"$NAV_SCRIPT" record "" || true
"$NAV_SCRIPT" record "invalid" || true
assert_equals "invalid IDs are ignored" "2" "$(count_history)"

# ═══════════════════════════════════════════════════
section "Back navigation"
# ═══════════════════════════════════════════════════

reset_nav

# Build history: WIN1 -> WIN2 -> WIN3
test_tmux select-window -t "$WIN1"
"$NAV_SCRIPT" record "$WIN1"
test_tmux select-window -t "$WIN2"
"$NAV_SCRIPT" record "$WIN2"
test_tmux select-window -t "$WIN3"
"$NAV_SCRIPT" record "$WIN3"

assert_equals "history has 3 entries" "3" "$(count_history)"

# Go back — should navigate to WIN2
"$NAV_SCRIPT" back
current=$(get_active_window)
assert_equals "back navigates to WIN2" "$WIN2" "$current"
assert_equals "position is 1 after back" "1" "$(get_pos)"

# Go back again — should navigate to WIN1
"$NAV_SCRIPT" back
current=$(get_active_window)
assert_equals "second back navigates to WIN1" "$WIN1" "$current"
assert_equals "position is 2 after second back" "2" "$(get_pos)"

# ═══════════════════════════════════════════════════
section "Forward navigation"
# ═══════════════════════════════════════════════════

# Go forward — should navigate to WIN2
"$NAV_SCRIPT" forward
current=$(get_active_window)
assert_equals "forward navigates to WIN2" "$WIN2" "$current"
assert_equals "position is 1 after forward" "1" "$(get_pos)"

# Go forward again — should navigate to WIN3
"$NAV_SCRIPT" forward
current=$(get_active_window)
assert_equals "second forward navigates to WIN3" "$WIN3" "$current"
assert_equals "position is 0 at newest" "0" "$(get_pos)"

# ═══════════════════════════════════════════════════
section "Forward truncation"
# ═══════════════════════════════════════════════════

reset_nav

# Build history: WIN1 -> WIN2 -> WIN3
test_tmux select-window -t "$WIN1"
"$NAV_SCRIPT" record "$WIN1"
test_tmux select-window -t "$WIN2"
"$NAV_SCRIPT" record "$WIN2"
test_tmux select-window -t "$WIN3"
"$NAV_SCRIPT" record "$WIN3"

# Go back to WIN2
"$NAV_SCRIPT" back
assert_equals "at WIN2 before truncation test" "$WIN2" "$(get_active_window)"

# Navigate to WIN1 (new navigation while at position 1) — should truncate WIN3
# Clear skip flag first so record works
tmux set-option -gq @nav-skip "" 2>/dev/null || true
test_tmux select-window -t "$WIN1"
"$NAV_SCRIPT" record "$WIN1"

assert_equals "position reset to 0 after new nav" "0" "$(get_pos)"
# History should now be WIN1, WIN2, WIN1 (forward history truncated)
local_last=$(tail -n1 "$HISTORY_FILE")
assert_equals "last entry is WIN1 after truncation" "$WIN1" "$local_last"

# WIN3 should not be in history anymore (it was the forward entry)
if ! grep -q "$WIN3" "$HISTORY_FILE" 2>/dev/null; then
    pass "forward history (WIN3) was truncated"
else
    fail "forward history (WIN3) was truncated"
fi

# ═══════════════════════════════════════════════════
section "Stale window cleanup"
# ═══════════════════════════════════════════════════

reset_nav

# Build history: WIN1 -> WIN2 -> WIN3
test_tmux select-window -t "$WIN1"
"$NAV_SCRIPT" record "$WIN1"
test_tmux select-window -t "$WIN2"
"$NAV_SCRIPT" record "$WIN2"
test_tmux select-window -t "$WIN3"
"$NAV_SCRIPT" record "$WIN3"

# Create a 4th window, record it, then kill WIN3 to make it stale
test_tmux new-window -t "$TEST_SESSION"
WIN4=$(test_tmux display-message -t "$TEST_SESSION" -p '#{window_id}')
"$NAV_SCRIPT" record "$WIN4"

assert_equals "history has 4 entries before stale test" "4" "$(count_history)"

# Kill WIN3 to make it stale in history
test_tmux kill-window -t "$WIN3"

# Go back — should skip stale WIN3 and target WIN2
# Note: select-window may not change the active window in detached test servers,
# so verify position and history state rather than active window
"$NAV_SCRIPT" back

# Position should be set (back was executed past the stale entry)
local_pos=$(get_pos)
if [[ "$local_pos" -gt 0 ]]; then
    pass "position advanced after back (pos=$local_pos)"
else
    fail "position advanced after back (pos=$local_pos)"
fi

# WIN3 should be removed from history (stale entry pruned)
if ! grep -q "$WIN3" "$HISTORY_FILE" 2>/dev/null; then
    pass "stale window removed from history"
else
    fail "stale window removed from history"
fi

# Verify the target was WIN2 (the entry before WIN3 in history)
# After removing WIN3, history is [WIN1, WIN2, WIN4] and position=1
# means we targeted line count-1 = line 2 = WIN2
local_count=$(count_history)
local_target_line=$((local_count - local_pos))
local_target=$(sed -n "${local_target_line}p" "$HISTORY_FILE" 2>/dev/null || echo "")
assert_equals "back targeted WIN2 (skipped stale)" "$WIN2" "$local_target"

# ═══════════════════════════════════════════════════
section "History trim"
# ═══════════════════════════════════════════════════

reset_nav

# Create more windows than MAX_HISTORY (100)
# We'll write directly to the history file to test trimming
mkdir -p "$NAV_CACHE"
for i in $(seq 1 105); do
    printf '@%d\n' "$i" >> "$HISTORY_FILE"
done
printf '%s' "$WIN1" > "$LAST_FILE"

# Record a new entry — should trigger trim to MAX_HISTORY
"$NAV_SCRIPT" record "$WIN1"
local_count=$(count_history)
if [[ "$local_count" -le 100 ]]; then
    pass "history trimmed to MAX_HISTORY ($local_count entries)"
else
    fail "history trimmed to MAX_HISTORY (got $local_count, expected <= 100)"
fi

# ═══════════════════════════════════════════════════
# Summary
# ═══════════════════════════════════════════════════

echo ""
echo "─────────────────────────────────"
printf "Results: ${GREEN}%d passed${NC}" "$PASS"
if [[ "$FAIL" -gt 0 ]]; then
    printf ", ${RED}%d failed${NC}" "$FAIL"
fi
echo ""

exit "$FAIL"
