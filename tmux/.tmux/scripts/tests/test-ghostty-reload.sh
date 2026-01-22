#!/usr/bin/env bash
set -euo pipefail

# Unit tests for Ghostty config reload script
# Tests the ghostty-reload.sh helper script

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GHOSTTY_RELOAD="$SCRIPT_DIR/../ghostty-reload.sh"

# Test counters
PASS=0
FAIL=0
SKIP=0

# Colours
GREEN=$'\033[0;32m'
RED=$'\033[0;31m'
YELLOW=$'\033[0;33m'
NC=$'\033[0m'

pass() {
    PASS=$((PASS + 1))
    printf "${GREEN}✓${NC} %s\n" "$1"
}

fail() {
    FAIL=$((FAIL + 1))
    printf "${RED}✗${NC} %s\n" "$1"
}

skip() {
    SKIP=$((SKIP + 1))
    printf "${YELLOW}○${NC} %s (skipped)\n" "$1"
}

section() {
    echo ""
    echo "─────────────────────────────────────────"
    echo "$1"
    echo "─────────────────────────────────────────"
}

# ===========================================================================
# Tests
# ===========================================================================

section "Script Exists and Is Executable"

if [[ -f "$GHOSTTY_RELOAD" ]]; then
    pass "ghostty-reload.sh exists"
else
    fail "ghostty-reload.sh not found"
    exit 1
fi

if [[ -x "$GHOSTTY_RELOAD" ]]; then
    pass "ghostty-reload.sh is executable"
else
    fail "ghostty-reload.sh is not executable"
fi

section "ShellCheck Validation"

if command -v shellcheck &>/dev/null; then
    if shellcheck -x -S warning -e SC1091 "$GHOSTTY_RELOAD" 2>/dev/null; then
        pass "ghostty-reload.sh passes shellcheck"
    else
        fail "ghostty-reload.sh has shellcheck warnings"
    fi
else
    skip "shellcheck not installed"
fi

section "Platform Detection"

# Test that script only runs on macOS
if [[ "$(uname)" == "Darwin" ]]; then
    pass "running on macOS (script will check for ghostty process)"

    section "Ghostty Process Detection"

    if pgrep -x ghostty >/dev/null 2>&1; then
        pass "ghostty process is running"

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

        # Test that multiple reload methods are implemented
        if grep -q "touch" "$GHOSTTY_RELOAD"; then
            pass "script uses touch for file-based reload"
        else
            fail "script should use touch to trigger auto-reload"
        fi

        # Test that osascript command is present
        if grep -q "osascript" "$GHOSTTY_RELOAD"; then
            pass "script uses osascript for macOS automation"
        else
            fail "script should use osascript for macOS automation"
        fi

        # Test that keystroke reload is implemented
        if grep -q "keystroke" "$GHOSTTY_RELOAD"; then
            pass "script uses keystroke for reload"
        else
            fail "script should use keystroke for reload"
        fi

    else
        skip "ghostty process not running (script will exit early)"
        skip "script execution test (ghostty not running)"
        skip "multiple invocation test (ghostty not running)"

        # Still test script structure even if ghostty isn't running
        if grep -q "touch" "$GHOSTTY_RELOAD"; then
            pass "script uses touch for file-based reload"
        else
            fail "script should use touch to trigger auto-reload"
        fi

        if grep -q "osascript" "$GHOSTTY_RELOAD"; then
            pass "script uses osascript for macOS automation"
        else
            fail "script should use osascript for macOS automation"
        fi

        if grep -q "keystroke" "$GHOSTTY_RELOAD"; then
            pass "script uses keystroke for reload"
        else
            fail "script should use keystroke for reload"
        fi
    fi
else
    skip "not running on macOS (script only works on macOS)"
    skip "ghostty process detection (not macOS)"
    skip "script execution (not macOS)"
fi

section "Script Content Validation"

# Test that script checks for ghostty process (case-insensitive to handle both "ghostty" and "Ghostty")
if grep -qE "pgrep.*-i.*ghostty" "$GHOSTTY_RELOAD"; then
    pass "script checks for ghostty process (case-insensitive)"
else
    fail "script should check for ghostty process (case-insensitive)"
fi

# Test that script checks platform
if grep -q 'uname.*Darwin' "$GHOSTTY_RELOAD"; then
    pass "script checks for macOS platform"
else
    fail "script should check for macOS platform"
fi

# Test that script has fallback activation method
if grep -q "activate" "$GHOSTTY_RELOAD"; then
    pass "script has fallback activation method"
else
    fail "script should have fallback activation method"
fi

# ===========================================================================
# Summary
# ===========================================================================

echo ""
echo "─────────────────────────────────────────"
echo "Test Summary"
echo "─────────────────────────────────────────"
printf "${GREEN}Passed:${NC}  %d\n" "$PASS"
printf "${RED}Failed:${NC}  %d\n" "$FAIL"
printf "${YELLOW}Skipped:${NC} %d\n" "$SKIP"
echo "─────────────────────────────────────────"

if [[ $FAIL -gt 0 ]]; then
    exit 1
fi
