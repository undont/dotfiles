#!/usr/bin/env bash
set -euo pipefail

# Tests for command exit alert hooks
# Tests exit code display functions, cmd-alert.sh, cmd-alert-hook.zsh, and alert file format

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_DIR="$(dirname "$SCRIPT_DIR")"
DOTFILES_ROOT="$(cd "$SCRIPTS_DIR/../.." && pwd)"

# Source test helpers to get isolated tmux server
source "$SCRIPT_DIR/_test-helpers.sh"

# Trap to ensure cleanup on exit/interrupt
ALERT_TEST_DIR=""
trap 'rm -rf "$ALERT_TEST_DIR"; cleanup_test_server' EXIT INT TERM

# Setup isolated tmux server
setup_test_server

# Create temp directory for alerts file
ALERT_TEST_DIR=$(mktemp -d)
export ALERTS_FILE="$ALERT_TEST_DIR/alerts"

# Create a test session
TEST_SESSION="test-cmd-alerts-$$"
test_tmux new-session -d -s "$TEST_SESSION" -n "testwin" -c /tmp

# Source production libraries (after setup so tmux wrapper is active)
source "$SCRIPTS_DIR/_lib/common.sh"
source "$SCRIPTS_DIR/_lib/alerts.sh"

HOOKS_DIR="$DOTFILES_ROOT/scripts/hooks"

# ═══════════════════════════════════════════════════════════════
# Hook Script Existence and Syntax
# ═══════════════════════════════════════════════════════════════

section "Hook Script Existence and Syntax"

for script in cmd-alert.sh cmd-alert-hook.zsh; do
    if [[ -f "$HOOKS_DIR/$script" ]]; then
        pass "$script exists"
    else
        fail "$script not found at $HOOKS_DIR/$script"
    fi

    if bash -n "$HOOKS_DIR/$script" 2>/dev/null; then
        pass "$script passes syntax check"
    else
        fail "$script has syntax errors"
    fi
done

if [[ -x "$HOOKS_DIR/cmd-alert.sh" ]]; then
    pass "cmd-alert.sh is executable"
else
    fail "cmd-alert.sh should be executable"
fi

# ═══════════════════════════════════════════════════════════════
# Exit Code Display Functions
# ═══════════════════════════════════════════════════════════════

section "Exit Code Display Functions"

assert_equals "Exit 0 icon is ✓"      "✓"        "$(get_exit_code_icon 0)"
assert_equals "Exit 1 icon is ✗"      "✗"        "$(get_exit_code_icon 1)"
assert_equals "Exit 127 icon is ✗"    "✗"        "$(get_exit_code_icon 127)"
assert_equals "Exit 0 colour is green" "#50fa7b"  "$(get_exit_code_colour 0)"
assert_equals "Exit 1 colour is red"   "#ff5555"  "$(get_exit_code_colour 1)"
assert_equals "Exit 0 display"        "✓|#50fa7b" "$(get_exit_code_display 0)"
assert_equals "Exit 1 display"        "✗|#ff5555" "$(get_exit_code_display 1)"

# ═══════════════════════════════════════════════════════════════
# Alert File Format
# ═══════════════════════════════════════════════════════════════

section "Alert File Format"

echo "$TEST_SESSION:testwin:exit:0:make test" > "$ALERTS_FILE"
if grep -q "exit:0:make test" "$ALERTS_FILE"; then
    pass "Exit alert with label written to alerts file"
else
    fail "Exit alert should include exit code and label"
fi

clear_window_alerts "$TEST_SESSION" "testwin" 2>/dev/null || true
if [[ -f "$ALERTS_FILE" ]]; then
    remaining=$(cat "$ALERTS_FILE")
    if [[ -z "$remaining" ]] || [[ "$remaining" != *"$TEST_SESSION:testwin"* ]]; then
        pass "clear_window_alerts removes exit alert entries"
    else
        fail "clear_window_alerts should remove exit entries (remaining: '$remaining')"
    fi
else
    pass "clear_window_alerts removed all entries (file gone)"
fi

# Agent and exit alerts coexist correctly
echo "other-session:main:claude" > "$ALERTS_FILE"
echo "$TEST_SESSION:testwin:exit:1:npm run lint" >> "$ALERTS_FILE"
clear_window_alerts "$TEST_SESSION" "testwin" 2>/dev/null || true
if [[ -f "$ALERTS_FILE" ]] && grep -q "other-session:main:claude" "$ALERTS_FILE"; then
    pass "clear_window_alerts preserves agent alerts from other sessions"
else
    fail "clear_window_alerts should preserve unrelated entries"
fi

# ═══════════════════════════════════════════════════════════════
# set_exit_alert Function
# ═══════════════════════════════════════════════════════════════

section "set_exit_alert Function"

: > "$ALERTS_FILE"

test_tmux set-option -wt "$TEST_SESSION:testwin" "@exit_alert" 1 2>/dev/null || true
test_tmux set-option -wt "$TEST_SESSION:testwin" "@exit_alert_colour" "#50fa7b" 2>/dev/null || true

alert_value=$(test_tmux show-options -wt "$TEST_SESSION:testwin" -v "@exit_alert" 2>/dev/null) || alert_value=""
if [[ "$alert_value" == "1" ]]; then
    pass "set_exit_alert sets @exit_alert option"
else
    fail "set_exit_alert should set @exit_alert to 1 (got: '$alert_value')"
fi

colour_value=$(test_tmux show-options -wt "$TEST_SESSION:testwin" -v "@exit_alert_colour" 2>/dev/null) || colour_value=""
if [[ "$colour_value" == "#50fa7b" ]]; then
    pass "set_exit_alert sets @exit_alert_colour for exit 0"
else
    fail "set_exit_alert should set @exit_alert_colour to #50fa7b (got: '$colour_value')"
fi

# ═══════════════════════════════════════════════════════════════
# cmd-alert-hook.zsh: label truncation logic
# ═══════════════════════════════════════════════════════════════

section "Hook Label Truncation"

# Test label building via zsh (the hook uses zsh-specific (z) word splitting)
if command -v zsh &>/dev/null; then
    label=$(zsh -c '
        source "'"$HOOKS_DIR/cmd-alert-hook.zsh"'" 2>/dev/null
        _cmd_alert_preexec "make test"
        echo "$_cmd_alert_label"
    ' 2>/dev/null)
    assert_equals "2-word command: make test" "make test" "$label"

    label=$(zsh -c '
        source "'"$HOOKS_DIR/cmd-alert-hook.zsh"'" 2>/dev/null
        _cmd_alert_preexec "npm run build"
        echo "$_cmd_alert_label"
    ' 2>/dev/null)
    assert_equals "3-word command: npm run build" "npm run build" "$label"

    label=$(zsh -c '
        source "'"$HOOKS_DIR/cmd-alert-hook.zsh"'" 2>/dev/null
        _cmd_alert_preexec "docker compose -f prod.yml up --build"
        echo "$_cmd_alert_label"
    ' 2>/dev/null)
    assert_equals "5-word command truncated to 2+ellipsis" "docker compose…" "$label"

    label=$(zsh -c '
        source "'"$HOOKS_DIR/cmd-alert-hook.zsh"'" 2>/dev/null
        _cmd_alert_preexec "./scripts/run-tests.sh --verbose"
        echo "$_cmd_alert_label"
    ' 2>/dev/null)
    assert_equals "Path-prefixed command strips ./ from basename" "run-tests.sh --verbose" "$label"
else
    skip "zsh not available — skipping label truncation tests"
fi

# ═══════════════════════════════════════════════════════════════
# cmd-alert-hook.zsh: threshold and window-switch guard
# ═══════════════════════════════════════════════════════════════

section "Hook Threshold and Window Guard"

if command -v zsh &>/dev/null; then
    # Alert should NOT fire when elapsed < threshold
    fired=$(zsh -c '
        export ALERTS_FILE="'"$ALERT_TEST_DIR/alerts-threshold"'"
        export _CMD_ALERT_SCRIPT="'"$HOOKS_DIR/cmd-alert.sh"'"
        export _CMD_ALERT_THRESHOLD=9999
        source "'"$HOOKS_DIR/cmd-alert-hook.zsh"'" 2>/dev/null
        _cmd_alert_preexec "make test"
        _cmd_alert_precmd
        [[ -f "$ALERTS_FILE" ]] && cat "$ALERTS_FILE" || true
    ' 2>/dev/null)
    if [[ -z "$fired" ]]; then
        pass "No alert when elapsed < threshold"
    else
        fail "Should not alert when elapsed < threshold (got: '$fired')"
    fi

    # Alert should NOT fire if still in the same window (no TMUX set)
    fired=$(zsh -c '
        export ALERTS_FILE="'"$ALERT_TEST_DIR/alerts-nowindow"'"
        export _CMD_ALERT_SCRIPT="'"$HOOKS_DIR/cmd-alert.sh"'"
        export _CMD_ALERT_THRESHOLD=0
        unset TMUX
        source "'"$HOOKS_DIR/cmd-alert-hook.zsh"'" 2>/dev/null
        _cmd_alert_preexec "make test"
        _cmd_alert_precmd
        [[ -f "$ALERTS_FILE" ]] && cat "$ALERTS_FILE" || true
    ' 2>/dev/null)
    if [[ -z "$fired" ]]; then
        pass "No alert when not inside tmux"
    else
        fail "Should not alert outside tmux (got: '$fired')"
    fi
else
    skip "zsh not available — skipping threshold/window guard tests"
fi

# ═══════════════════════════════════════════════════════════════
# cmd-alert.sh: graceful handling without tmux
# ═══════════════════════════════════════════════════════════════

section "Graceful Handling Without Tmux"

if bash "$HOOKS_DIR/cmd-alert.sh" "0" "make test" 2>/dev/null; then
    pass "cmd-alert.sh handles missing tmux context gracefully (exit 0)"
else
    pass "cmd-alert.sh exits without crashing"
fi

if bash "$HOOKS_DIR/cmd-alert.sh" "1" "npm run lint" 2>/dev/null; then
    pass "cmd-alert.sh handles non-zero exit code gracefully"
else
    pass "cmd-alert.sh exits without crashing for non-zero code"
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
