#!/usr/bin/env bash
set -euo pipefail

# Unit tests for list-claude.sh
# Tests the Claude Code instance listing and formatting logic

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIST_CLAUDE_SCRIPT="$SCRIPT_DIR/../list-claude.sh"

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

if [[ -f "$LIST_CLAUDE_SCRIPT" ]]; then
    pass "list-claude.sh exists"
else
    fail "list-claude.sh not found at $LIST_CLAUDE_SCRIPT"
    exit 1
fi

if [[ -x "$LIST_CLAUDE_SCRIPT" ]]; then
    pass "list-claude.sh is executable"
else
    fail "list-claude.sh is not executable"
fi

section "ShellCheck Validation"

if command -v shellcheck &>/dev/null; then
    if shellcheck -x -e SC1091 -e SC2059 -e SC2015 -e SC2016 -e SC2034 "$LIST_CLAUDE_SCRIPT" 2>/dev/null; then
        pass "list-claude.sh passes shellcheck"
    else
        fail "list-claude.sh has shellcheck warnings"
    fi
else
    skip "shellcheck not installed"
fi

section "Bash Syntax Check"

if bash -n "$LIST_CLAUDE_SCRIPT" 2>/dev/null; then
    pass "list-claude.sh has valid bash syntax"
else
    fail "list-claude.sh has syntax errors"
fi

section "Script Structure"

# Check for required usage patterns
script_content=$(cat "$LIST_CLAUDE_SCRIPT")

if [[ "$script_content" == *'source "$SCRIPT_DIR/_lib/alerts.sh"'* ]]; then
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

# Check for FZF-friendly format (target first)
if [[ "$script_content" == *'target="${session}:${window_idx}.${pane_idx}"'* ]]; then
    pass "Builds target in session:window.pane format"
else
    fail "Should build target in correct format"
fi

# Check for alert indicator integration
if [[ "$script_content" == *'ALERTS_FILE'* ]]; then
    pass "Integrates with Claude alerts system"
else
    fail "Should integrate with Claude alerts"
fi

if [[ "$script_content" == *'get_agent_display'* ]]; then
    pass "Uses agent-specific indicator for alerts"
else
    fail "Should use agent-specific indicator"
fi

section "Ghost Decoration"

# Check for Claude Code ghost in Anthropic orange
if [[ "$script_content" == *'▐▛███▜▌'* ]]; then
    pass "Includes Claude Code ghost decoration"
else
    fail "Should include Claude Code ghost decoration"
fi

if [[ "$script_content" == *'38;5;173'* ]]; then
    pass "Ghost uses Anthropic orange colour (173)"
else
    fail "Ghost should use Anthropic orange (colour 173)"
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

# Script should handle no Claude instances gracefully
if [[ "$script_content" == *'${#claude_panes[@]} -eq 0'* ]]; then
    pass "Handles case with no Claude instances"
else
    fail "Should handle case with no Claude instances"
fi

section "Command Detection"

# Script should specifically look for "claude" command
if [[ "$script_content" == *'if [[ "$command" == "claude" ]]'* ]]; then
    pass "Filters for claude command specifically"
else
    fail "Should filter for claude command"
fi

# ===========================================================================
# Integration test (only if tmux is running)
# ===========================================================================

section "Integration (Live Execution)"

if ! command -v tmux &>/dev/null; then
    skip "tmux not installed"
elif ! tmux list-sessions &>/dev/null 2>&1; then
    skip "no tmux sessions running"
else
    # Test default (fzf) mode
    if output=$("$LIST_CLAUDE_SCRIPT" 2>/dev/null); then
        pass "Runs successfully in fzf mode"

        # Check output format
        if echo "$output" | grep -qE '^[a-zA-Z0-9_-]+:[0-9]+\.[0-9]+ '; then
            pass "FZF output format is correct (target first)"
        elif [[ -z "$output" ]] || echo "$output" | grep -q "▐▛███▜▌"; then
            pass "FZF output is empty or has ghost only (no Claude instances)"
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
