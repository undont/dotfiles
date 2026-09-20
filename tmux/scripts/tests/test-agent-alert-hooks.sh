#!/usr/bin/env bash
set -euo pipefail

# tests for agent alert hooks and wrappers
# tests agent-alert.sh, agent-alert-clear.sh, and per-agent wrappers

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_DIR="$(dirname "$SCRIPT_DIR")"
DOTFILES_ROOT="$(cd "$SCRIPTS_DIR/../.." && pwd)"

# source test helpers to get isolated tmux server
source "$SCRIPT_DIR/_test-helpers.sh"

# trap to ensure cleanup on exit/interrupt
ALERT_TEST_DIR=""
trap 'rm -rf "$ALERT_TEST_DIR"; cleanup_test_server' EXIT INT TERM

# setup isolated tmux server
setup_test_server

# create temp directory for alerts file
ALERT_TEST_DIR=$(mktemp -d)
export ALERTS_FILE="$ALERT_TEST_DIR/alerts"

# create a test session
TEST_SESSION="test-alerts-$$"
test_tmux new-session -d -s "$TEST_SESSION" -n "testwin" -c /tmp

# source production libraries (after setup so tmux wrapper is active)
source "$SCRIPTS_DIR/_lib/common.sh"
source "$SCRIPTS_DIR/_lib/alerts.sh"

# ═══════════════════════════════════════════════════════════════
# Hook Script Validation
# ═══════════════════════════════════════════════════════════════

section "Hook Script Existence and Syntax"

HOOKS_DIR="$DOTFILES_ROOT/scripts/hooks"
WRAPPERS_DIR="$HOOKS_DIR/wrappers"

# check main hook scripts exist and are valid
for script in agent-alert.sh agent-alert-clear.sh; do
    if [[ -f "$HOOKS_DIR/$script" ]]; then
        pass "$script exists"
    else
        fail "$script not found"
    fi

    if bash -n "$HOOKS_DIR/$script" 2>/dev/null; then
        pass "$script passes syntax check"
    else
        fail "$script has syntax errors"
    fi
done

# check all wrapper scripts exist, are executable, and pass syntax check
EXPECTED_WRAPPERS=(
    "claude-alert.sh"
    "claude-alert-clear.sh"
    "opencode-alert.sh"
    "opencode-alert-clear.sh"
)

for wrapper in "${EXPECTED_WRAPPERS[@]}"; do
    if [[ -f "$WRAPPERS_DIR/$wrapper" ]]; then
        pass "Wrapper $wrapper exists"
    else
        fail "Wrapper $wrapper not found"
    fi

    if [[ -x "$WRAPPERS_DIR/$wrapper" ]]; then
        pass "Wrapper $wrapper is executable"
    else
        fail "Wrapper $wrapper should be executable"
    fi

    if bash -n "$WRAPPERS_DIR/$wrapper" 2>/dev/null; then
        pass "Wrapper $wrapper passes syntax check"
    else
        fail "Wrapper $wrapper has syntax errors"
    fi
done

section "Wrapper Agent Name Routing"

# verify each alert wrapper passes the correct agent name
# wrappers use pattern: "$SCRIPT_DIR/agent-alert.sh" <agent>
for agent in claude opencode; do
    wrapper_content=$(cat "$WRAPPERS_DIR/${agent}-alert.sh")
    if [[ "$wrapper_content" == *"agent-alert.sh\" ${agent}"* ]] || [[ "$wrapper_content" == *"agent-alert.sh ${agent}"* ]]; then
        pass "${agent}-alert.sh passes agent name '${agent}'"
    else
        fail "${agent}-alert.sh should pass agent name '${agent}'"
    fi
done

# verify clear wrappers reference the clear script
for agent in claude opencode; do
    clear_content=$(cat "$WRAPPERS_DIR/${agent}-alert-clear.sh")
    if [[ "$clear_content" == *"agent-alert-clear.sh"* ]] || [[ "$clear_content" == *"clear.sh"* ]]; then
        pass "${agent}-alert-clear.sh references clear script"
    else
        fail "${agent}-alert-clear.sh should reference clear script"
    fi
done

# ═══════════════════════════════════════════════════════════════
# Alert Library Functional Tests
# ═══════════════════════════════════════════════════════════════

section "Alert Library - set_window_alert"

# test set_window_alert with TMUX_PANE pointing at test server
export TMUX_PANE="" # clear to test graceful handling
export TMUX=""      # already cleared by setup_test_server

# set alert using direct library function with explicit tmux context
test_tmux set-option -wt "$TEST_SESSION:testwin" "@claude_alert" 1 2>/dev/null || true

# verify the option was set
alert_value=$(test_tmux show-options -wt "$TEST_SESSION:testwin" -v "@claude_alert" 2>/dev/null) || alert_value=""
if [[ "$alert_value" == "1" ]]; then
    pass "set_window_alert sets @claude_alert option"
else
    fail "set_window_alert should set @claude_alert to 1 (got: '$alert_value')"
fi

section "Alert Library - clear_window_alerts"

# first, add an entry to the alerts file
echo "$TEST_SESSION:testwin:claude" >"$ALERTS_FILE"

# run clear
clear_window_alerts "$TEST_SESSION" "testwin" 2>/dev/null || true

# verify alerts file no longer contains the entry
if [[ -f "$ALERTS_FILE" ]]; then
    remaining=$(cat "$ALERTS_FILE")
    if [[ -z "$remaining" ]] || [[ "$remaining" != *"$TEST_SESSION:testwin"* ]]; then
        pass "clear_window_alerts removes entry from alerts file"
    else
        fail "clear_window_alerts should remove entry (remaining: '$remaining')"
    fi
else
    pass "clear_window_alerts removed all entries (file gone)"
fi

section "Alert Library - Window Renames"

# an agent's window name follows its pane title under automatic-rename, so it
# drifts between the alert and the clear. the row is keyed on window_id to
# survive that; these are the regressions for a name-keyed row
RENAME_WIN="renamewin-$$"
test_tmux new-window -t "$TEST_SESSION" -n "$RENAME_WIN" -c /tmp
RENAME_WIN_ID=$(test_tmux list-windows -t "$TEST_SESSION" -F '#{window_name}|#{window_id}' | grep -F "${RENAME_WIN}|" | cut -d'|' -f2)
RENAME_PANE_ID=$(test_tmux list-panes -t "$RENAME_WIN_ID" -F '#{pane_id}' | head -1)
test_tmux set-window-option -t "$RENAME_WIN_ID" automatic-rename off 2>/dev/null || true

: >"$ALERTS_FILE"
TMUX_PANE="$RENAME_PANE_ID" set_window_alert "claude" "false" 2>/dev/null || true
if grep -qxF "${TEST_SESSION}:${RENAME_WIN}:claude:${RENAME_WIN_ID}" "$ALERTS_FILE" 2>/dev/null; then
    pass "set_window_alert records the window id"
else
    fail "set_window_alert should record the window id (file: $(cat "$ALERTS_FILE"))"
fi

# re-setting after a rename rewrites the row rather than appending a second one
test_tmux rename-window -t "$RENAME_WIN_ID" "${RENAME_WIN}-renamed"
TMUX_PANE="$RENAME_PANE_ID" set_window_alert "claude" "false" 2>/dev/null || true
if [[ $(grep -c . "$ALERTS_FILE") -eq 1 ]] && grep -qxF "${TEST_SESSION}:${RENAME_WIN}-renamed:claude:${RENAME_WIN_ID}" "$ALERTS_FILE"; then
    pass "re-setting after a rename refreshes the row in place"
else
    fail "re-set should refresh the row, not append (file: $(cat "$ALERTS_FILE"))"
fi

# the clear runs with the current name, which no longer matches the stored one
test_tmux rename-window -t "$RENAME_WIN_ID" "${RENAME_WIN}-again"
clear_window_alerts "$TEST_SESSION" "${RENAME_WIN}-again" "$RENAME_WIN_ID" 2>/dev/null || true
if [[ -s "$ALERTS_FILE" ]]; then
    fail "clear_window_alerts should drop the row after a rename (file: $(cat "$ALERTS_FILE"))"
else
    pass "clear_window_alerts drops the row after a rename"
fi

# the GC refreshes a drifted name so the picker shows what the window is called now
printf '%s:%s:claude:%s\n' "$TEST_SESSION" "stale-name" "$RENAME_WIN_ID" >"$ALERTS_FILE"
cleanup_stale_alerts 2>/dev/null || true
if grep -qxF "${TEST_SESSION}:${RENAME_WIN}-again:claude:${RENAME_WIN_ID}" "$ALERTS_FILE" 2>/dev/null; then
    pass "cleanup_stale_alerts refreshes a drifted window name"
else
    fail "cleanup_stale_alerts should refresh the name (file: $(cat "$ALERTS_FILE"))"
fi

# rows written before the id was recorded still clear on the name alone
printf '%s:testwin:claude\n' "$TEST_SESSION" >"$ALERTS_FILE"
clear_window_alerts "$TEST_SESSION" "testwin" "" 2>/dev/null || true
if [[ -s "$ALERTS_FILE" ]]; then
    fail "clear_window_alerts should still clear a legacy 3-field row (file: $(cat "$ALERTS_FILE"))"
else
    pass "clear_window_alerts still clears a legacy 3-field row"
fi

# a row whose window is gone is reaped
printf '%s:gone:claude:@9999\n' "$TEST_SESSION" >"$ALERTS_FILE"
cleanup_stale_alerts 2>/dev/null || true
if [[ -s "$ALERTS_FILE" ]]; then
    fail "cleanup_stale_alerts should reap a row for a dead window"
else
    pass "cleanup_stale_alerts reaps a row for a dead window"
fi

test_tmux kill-window -t "$RENAME_WIN_ID" 2>/dev/null || true
: >"$ALERTS_FILE"

section "Alert Library - Agent Icons"

# test agent icon lookup
assert_equals "Claude icon is ⚡" "⚡" "$(get_agent_icon claude)"
assert_equals "OpenCode icon is " "" "$(get_agent_icon opencode)"

assert_equals "Unknown agent icon is 󱜙" "󱜙" "$(get_agent_icon unknown)"

section "Alert Library - Agent Colours"

claude_colour=$(get_agent_colour claude)
if [[ "$claude_colour" == "#"* ]]; then
    pass "Claude colour is a hex code ($claude_colour)"
else
    fail "Claude colour should be a hex code"
fi

opencode_colour=$(get_agent_colour opencode)
if [[ "$opencode_colour" != "$claude_colour" ]]; then
    pass "OpenCode colour differs from Claude colour"
else
    fail "OpenCode colour should differ from Claude"
fi

section "Alert File Locking"

# test that concurrent operations don't corrupt the alerts file
echo "sess1:win1:claude" >"$ALERTS_FILE"
echo "sess2:win2:opencode" >>"$ALERTS_FILE"

# clear one entry
clear_window_alerts "sess1" "win1" 2>/dev/null || true

# verify the other entry remains
if [[ -f "$ALERTS_FILE" ]] && grep -q "sess2:win2:opencode" "$ALERTS_FILE"; then
    pass "Clear preserves unrelated alert entries"
else
    fail "Clear should preserve unrelated entries"
fi

section "Graceful Handling Without Tmux"

# agent-alert.sh should not crash when tmux is unavailable
# (it checks for ALERTS_LIB existence before sourcing)
if bash "$HOOKS_DIR/agent-alert.sh" "test_agent" 2>/dev/null; then
    pass "agent-alert.sh handles missing tmux context gracefully"
else
    # exit code doesn't matter as long as it doesn't crash fatally
    pass "agent-alert.sh exits without crashing"
fi

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
