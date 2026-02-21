#!/usr/bin/env bash
# Tests for reload-ghostty.sh
# Tests the ghostty-reload.sh helper script

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GHOSTTY_RELOAD="$SCRIPT_DIR/../themes/reload-ghostty.sh"

# Source test helpers
source "$SCRIPT_DIR/_test-helpers.sh"

# ══════════════════════════════════════════════════════════════
# Test Suite
# ══════════════════════════════════════════════════════════════

section "Script Existence and Permissions"

if [[ -f "$GHOSTTY_RELOAD" ]]; then
    pass "reload-ghostty.sh exists"
else
    fail "reload-ghostty.sh not found"
    exit 1
fi

if [[ -x "$GHOSTTY_RELOAD" ]]; then
    pass "reload-ghostty.sh is executable"
else
    fail "reload-ghostty.sh is not executable"
fi

section "ShellCheck Validation"

if command -v shellcheck &>/dev/null; then
    if shellcheck -x -S warning -e SC1091 "$GHOSTTY_RELOAD" 2>/dev/null; then
        pass "reload-ghostty.sh passes shellcheck"
    else
        fail "reload-ghostty.sh has shellcheck warnings"
    fi
else
    skip "shellcheck not installed"
fi

section "Script Content Validation"

# Test that script uses ps to find ghostty process (cross-platform)
if grep -q "ps -eo" "$GHOSTTY_RELOAD"; then
    pass "script uses ps to find ghostty process"
else
    fail "script should use ps to find ghostty process"
fi

# Test that script uses SIGUSR2 to reload
if grep -qE "kill.*USR2|USR2" "$GHOSTTY_RELOAD"; then
    pass "script uses SIGUSR2 signal to reload"
else
    fail "script should use SIGUSR2 signal to reload"
fi

# Test that script greps for ghostty in process list
if grep -q "grep.*ghostty" "$GHOSTTY_RELOAD"; then
    pass "script searches for ghostty process"
else
    fail "script should search for ghostty process"
fi

section "Ghostty Process Detection"

# Check if ghostty is running
ghostty_pid=$(ps -eo pid,comm | grep -E '/ghostty$' | awk '{print $1}' | head -1)

if [[ -n "$ghostty_pid" ]]; then
    pass "ghostty process found (PID: $ghostty_pid)"

    section "Script Execution"

    # Test that script runs without error
    if "$GHOSTTY_RELOAD" 2>&1; then
        pass "script executes without errors"
    else
        fail "script execution failed"
    fi

    # Test that script handles being called multiple times
    if "$GHOSTTY_RELOAD" 2>&1 && "$GHOSTTY_RELOAD" 2>&1; then
        pass "script can be called multiple times"
    else
        fail "script fails when called multiple times"
    fi
else
    skip "ghostty process not running"
    skip "script execution test (ghostty not running)"
    skip "multiple invocation test (ghostty not running)"
fi

echo ""
echo "${CYAN}═══════════════════════════════════════════${NC}"
if [[ $FAIL -eq 0 ]]; then
    echo "${GREEN}✓ All tests passed${NC} ($PASS passed)"
    exit 0
else
    echo "${RED}✗ Some tests failed${NC} ($PASS passed, $FAIL failed)"
    exit 1
fi
