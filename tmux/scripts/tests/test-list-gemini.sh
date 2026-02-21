#!/usr/bin/env bash
set -euo pipefail

# Unit tests for gemini.sh
# Tests the Gemini instance listing and formatting logic

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIST_GEMINI_SCRIPT="$SCRIPT_DIR/../instances/gemini.sh"

# Test counters
PASS=0
FAIL=0

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

if [[ -f "$LIST_GEMINI_SCRIPT" ]]; then
    pass "gemini.sh exists"
else
    fail "gemini.sh not found at $LIST_GEMINI_SCRIPT"
    exit 1
fi

if [[ -x "$LIST_GEMINI_SCRIPT" ]]; then
    pass "gemini.sh is executable"
else
    fail "gemini.sh is not executable"
fi

section "ShellCheck Validation"

if command -v shellcheck &>/dev/null; then
    if shellcheck -x -e SC1091 -e SC2059 -e SC2015 -e SC2016 -e SC2034 "$LIST_GEMINI_SCRIPT" 2>/dev/null; then
        pass "gemini.sh passes shellcheck"
    else
        fail "gemini.sh has shellcheck warnings"
    fi
else
    skip "shellcheck not installed"
fi

section "Bash Syntax Check"

if bash -n "$LIST_GEMINI_SCRIPT" 2>/dev/null; then
    pass "gemini.sh has valid bash syntax"
else
    fail "gemini.sh has syntax errors"
fi

section "Script Structure"

# Check for required usage patterns
script_content=$(cat "$LIST_GEMINI_SCRIPT")

if [[ "$script_content" == *'source "$SCRIPT_DIR/../_lib/common.sh"'* ]]; then
    pass "Sources common.sh library"
else
    fail "Should source common.sh library"
fi

if [[ "$script_content" == *'source "$SCRIPT_DIR/../_lib/alerts.sh"'* ]]; then
    pass "Sources alerts.sh library"
else
    fail "Should source alerts.sh library"
fi

if [[ "$script_content" == *'tmux list-panes -a'* ]]; then
    pass "Uses tmux list-panes to find instances"
else
    fail "Should use tmux list-panes"
fi

section "Output Format"

# Check for FZF-friendly format (target from tmux output)
if [[ "$script_content" == *'target='* ]]; then
    pass "Builds target for session:window.pane format"
else
    fail "Should build target in correct format"
fi

# Check for alert indicator integration
if [[ "$script_content" == *'ALERTS_FILE'* ]]; then
    pass "Integrates with Gemini alerts system"
else
    fail "Should integrate with Gemini alerts"
fi

if [[ "$script_content" == *'get_agent_display'* ]]; then
    pass "Uses agent-specific indicator for alerts"
else
    fail "Should use agent-specific indicator"
fi

section "Logo Decoration"

# Check for Gemini logo (using box-drawing characters)
if [[ "$script_content" == *'██╗'* ]] && [[ "$script_content" == *'██████'* ]]; then
    pass "Includes Gemini logo decoration"
else
    fail "Should include Gemini logo decoration"
fi

# Check for cyan colour (117)
if [[ "$script_content" == *'38;5;117'* ]]; then
    pass "Logo uses cyan colour (117)"
else
    fail "Logo should use cyan colour (117)"
fi

# Check that it doesn't redefine readonly CYAN variable
if [[ "$script_content" == *'LOGO_CYAN='* ]] || [[ "$script_content" != *'CYAN="\033'* ]]; then
    pass "Uses non-conflicting variable name for logo colour"
else
    fail "Should not redefine readonly CYAN variable from colours.sh"
fi

section "Error Handling"

# Script should handle missing tmux gracefully
if [[ "$script_content" == *'command -v tmux'* ]]; then
    pass "Checks if tmux is installed"
else
    fail "Should check if tmux is installed"
fi

# Script should handle no sessions gracefully
if [[ "$script_content" == *'tmux list-sessions'* ]]; then
    pass "Checks if tmux sessions exist"
else
    fail "Should check if tmux sessions exist"
fi

# Script should handle no Gemini instances gracefully
if [[ "$script_content" == *'${#gemini_panes[@]} -eq 0'* ]]; then
    pass "Handles case with no Gemini instances"
else
    fail "Should handle case with no Gemini instances"
fi

section "Command Detection"

# Script should batch-detect Gemini processes via pgrep and process tree
if [[ "$script_content" == *'pgrep -f gemini'* ]]; then
    pass "Uses pgrep -f to find Gemini processes"
else
    fail "Should use pgrep -f to find Gemini processes"
fi

# Script should filter out suspended processes
if [[ "$script_content" == *'T*'* ]]; then
    pass "Filters out suspended (Ctrl+Z) processes"
else
    fail "Should filter out suspended processes"
fi

section "Process Tree Ancestor Walking"

# Script should build a set of ancestor PIDs by walking up the process tree
if [[ "$script_content" == *'active_gemini_ppids'* ]]; then
    pass "Uses active_gemini_ppids associative array"
else
    fail "Should use active_gemini_ppids for ancestor tracking"
fi

# Should walk up via ppid loop
if [[ "$script_content" == *'ppid=$(ps -o ppid='* ]]; then
    pass "Walks process tree via ps -o ppid="
else
    fail "Should walk process tree via ps -o ppid="
fi

# Should terminate walk at PID 0 or 1 (init)
if [[ "$script_content" == *'"0"'* ]] && [[ "$script_content" == *'"1"'* ]]; then
    pass "Terminates ancestor walk at PID 0 or 1"
else
    fail "Should terminate ancestor walk at PID 0 or 1"
fi

# Should match pane PIDs against the ancestor set (not just direct children)
if [[ "$script_content" == *'active_gemini_ppids[$pane_pid]'* ]]; then
    pass "Matches pane PIDs against ancestor set"
else
    fail "Should match pane PIDs against ancestor set (not just direct children)"
fi

# Should handle wrapper scripts via ancestor walking
if [[ "$script_content" == *'wrapper'* ]] || [[ "$script_content" == *'Walks up'* ]] || [[ "$script_content" == *'ancestor'* ]]; then
    pass "Documents wrapper script support via ancestor walking"
else
    # The implementation handles it even without explicit docs
    if [[ "$script_content" == *'while true'* ]] && [[ "$script_content" == *'ppid='* ]]; then
        pass "Ancestor walk loop enables wrapper script detection"
    else
        fail "Should support wrapper scripts via ancestor walking"
    fi
fi

section "Alert Integration"

# Check for gemini-specific alert checking
if [[ "$script_content" == *':gemini$'* ]]; then
    pass "Checks for gemini-specific alerts in alerts file"
else
    fail "Should check for gemini-specific alerts"
fi

# ===========================================================================
# Integration test (only if tmux is running)
# ===========================================================================

section "Integration (Live Execution)"

if ! command -v tmux &>/dev/null; then
    skip "tmux not installed"
elif ! command tmux list-sessions &>/dev/null 2>&1; then
    # Intentionally queries the real tmux server (not the test socket) to check
    # whether there are live sessions to run the integration smoke-test against.
    skip "no tmux sessions running"
else
    # Test default (fzf) mode
    if output=$("$LIST_GEMINI_SCRIPT" 2>/dev/null); then
        pass "Runs successfully in fzf mode"

        # Check output format
        if echo "$output" | grep -qE '^[a-zA-Z0-9_-]+:[0-9]+\.[0-9]+ '; then
            pass "FZF output format is correct (target first)"
        elif [[ -z "$output" ]] || echo "$output" | grep -q "██╗"; then
            pass "FZF output is empty or has logo only (no Gemini instances)"
        else
            fail "Unexpected FZF output format"
        fi
    else
        fail "Failed to run in fzf mode"
    fi
fi

# ===========================================================================
# Summary
# ===========================================================================

echo ""
echo "==========================================="
echo "Test Results: ${GREEN}${PASS} passed${NC}, ${RED}${FAIL} failed${NC}"
echo "==========================================="

if [[ $FAIL -gt 0 ]]; then
    exit 1
fi
