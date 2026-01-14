#!/usr/bin/env bash
# Test fzf-confirm-kill.sh functionality

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_DIR="$SCRIPT_DIR/.."
FZF_CONFIRM="$SCRIPTS_DIR/fzf-confirm-kill.sh"

# Test colours
GREEN=$'\033[0;32m'
RED=$'\033[0;31m'
YELLOW=$'\033[0;33m'
NC=$'\033[0m'

pass() { echo "${GREEN}✓${NC} $1"; }
fail() { echo "${RED}✗${NC} $1"; }
section() { echo ""; echo "${YELLOW}=== $1 ===${NC}"; }

PASSED=0
FAILED=0

section "Script existence and structure"

if [[ -f "$FZF_CONFIRM" ]]; then
    pass "fzf-confirm-kill.sh exists"
    ((PASSED++))
else
    fail "fzf-confirm-kill.sh not found"
    ((FAILED++))
    exit 1
fi

if [[ -x "$FZF_CONFIRM" ]]; then
    pass "fzf-confirm-kill.sh is executable"
    ((PASSED++))
else
    fail "fzf-confirm-kill.sh is not executable"
    ((FAILED++))
fi

section "Script structure validation"

# Check for required parameters
if grep -q "TYPE=\"\$1\"" "$FZF_CONFIRM"; then
    pass "Script accepts TYPE parameter"
    ((PASSED++))
else
    fail "Script missing TYPE parameter"
    ((FAILED++))
fi

if grep -q "TARGET=\"\$2\"" "$FZF_CONFIRM"; then
    pass "Script accepts TARGET parameter"
    ((PASSED++))
else
    fail "Script missing TARGET parameter"
    ((FAILED++))
fi

if grep -q "IS_CURRENT=\"\${3:-}\"" "$FZF_CONFIRM"; then
    pass "Script accepts optional IS_CURRENT flag"
    ((PASSED++))
else
    fail "Script missing IS_CURRENT flag handling"
    ((FAILED++))
fi

section "Sources required libraries"

if grep -q "source.*_lib/common.sh" "$FZF_CONFIRM"; then
    pass "Sources common.sh library"
    ((PASSED++))
else
    fail "Doesn't source common.sh"
    ((FAILED++))
fi

if grep -q "source.*_lib/session.sh" "$FZF_CONFIRM"; then
    pass "Sources session.sh library"
    ((PASSED++))
else
    fail "Doesn't source session.sh"
    ((FAILED++))
fi

if grep -q "source.*_lib/alerts.sh" "$FZF_CONFIRM"; then
    pass "Sources alerts.sh library"
    ((PASSED++))
else
    fail "Doesn't source alerts.sh"
    ((FAILED++))
fi

section "FZF confirmation dialog"

if grep -q "printf \"y\\\\nn\"" "$FZF_CONFIRM"; then
    pass "Uses y/n options for confirmation"
    ((PASSED++))
else
    fail "Doesn't use y/n confirmation pattern"
    ((FAILED++))
fi

if grep -q "fzf" "$FZF_CONFIRM"; then
    pass "Uses fzf for confirmation dialog"
    ((PASSED++))
else
    fail "Doesn't use fzf"
    ((FAILED++))
fi

if grep -q "\-\-height=~100%" "$FZF_CONFIRM"; then
    pass "Uses adaptive height for compact display"
    ((PASSED++))
else
    fail "Doesn't use adaptive height"
    ((FAILED++))
fi

if grep -q "\-\-border-label.*Kill.*TYPE.*TARGET" "$FZF_CONFIRM"; then
    pass "Shows descriptive border label"
    ((PASSED++))
else
    fail "Missing descriptive border label"
    ((FAILED++))
fi

section "Kill operations handling"

if grep -q "case \"\$TYPE\" in" "$FZF_CONFIRM"; then
    pass "Uses case statement for different types"
    ((PASSED++))
else
    fail "Doesn't handle different types properly"
    ((FAILED++))
fi

if grep -q "session)" "$FZF_CONFIRM" && grep -q "window)" "$FZF_CONFIRM" && grep -q "pane)" "$FZF_CONFIRM"; then
    pass "Handles session, window, and pane types"
    ((PASSED++))
else
    fail "Missing handler for some types"
    ((FAILED++))
fi

section "Alert cleanup integration"

if grep -q "clear_session_alerts" "$FZF_CONFIRM"; then
    pass "Clears session alerts before kill"
    ((PASSED++))
else
    fail "Doesn't clear session alerts"
    ((FAILED++))
fi

if grep -q "clear_window_alerts" "$FZF_CONFIRM"; then
    pass "Clears window alerts before kill"
    ((PASSED++))
else
    fail "Doesn't clear window alerts"
    ((FAILED++))
fi

section "Session switching logic"

if grep -q "find_other_session" "$FZF_CONFIRM"; then
    pass "Uses find_other_session for current session kills"
    ((PASSED++))
else
    fail "Doesn't handle session switching"
    ((FAILED++))
fi

if grep -q "switch-client.*kill-session" "$FZF_CONFIRM"; then
    pass "Switches client before killing current session"
    ((PASSED++))
else
    fail "Doesn't switch client properly"
    ((FAILED++))
fi

section "Exit codes"

if grep -q "exit 0" "$FZF_CONFIRM" && grep -q "exit 1" "$FZF_CONFIRM"; then
    pass "Has proper exit codes for success/failure"
    ((PASSED++))
else
    fail "Missing proper exit codes"
    ((FAILED++))
fi

section "Keybinding support"

if grep -q "bind 'j:down,k:up'" "$FZF_CONFIRM"; then
    pass "Supports j/k navigation"
    ((PASSED++))
else
    fail "Doesn't support j/k navigation"
    ((FAILED++))
fi

if grep -q "bind 'y:accept'" "$FZF_CONFIRM"; then
    pass "Supports direct 'y' to confirm"
    ((PASSED++))
else
    fail "Doesn't support direct 'y' key"
    ((FAILED++))
fi

if grep -q "bind 'n:abort'" "$FZF_CONFIRM"; then
    pass "Supports direct 'n' to cancel"
    ((PASSED++))
else
    fail "Doesn't support direct 'n' key"
    ((FAILED++))
fi

if grep -q "bind 'esc:abort'" "$FZF_CONFIRM"; then
    pass "Supports Esc to cancel"
    ((PASSED++))
else
    fail "Doesn't support Esc key"
    ((FAILED++))
fi

echo ""
echo "==========================================="
echo "Test Results: ${GREEN}${PASSED} passed${NC}, ${RED}${FAILED} failed${NC}"
echo "==========================================="

[[ $FAILED -eq 0 ]]
