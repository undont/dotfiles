#!/usr/bin/env bash
set -euo pipefail

# Unit tests for list-claude.sh
# Tests the Claude Code instance listing and formatting logic

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIST_CLAUDE_SCRIPT="$SCRIPT_DIR/../instances/claude.sh"

source "$SCRIPT_DIR/_test-helpers.sh"

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

if [[ "$script_content" == *'38;5;174'* ]]; then
    pass "Ghost uses Anthropic orange colour (174)"
else
    fail "Ghost should use Anthropic orange (colour 174)"
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

# Script should batch-detect Claude processes via pgrep and process tree
if [[ "$script_content" == *'pgrep -x claude'* ]]; then
    pass "Uses pgrep to find Claude processes"
else
    fail "Should use pgrep to find Claude processes"
fi

# Script should filter out suspended processes
if [[ "$script_content" == *'T*'* ]]; then
    pass "Filters out suspended (Ctrl+Z) processes"
else
    fail "Should filter out suspended processes"
fi

section "Process Tree Ancestor Walking"

# Script should build a set of ancestor PIDs by walking up the process tree
if [[ "$script_content" == *'active_claude_ppids'* ]]; then
    pass "Uses active_claude_ppids associative array"
else
    fail "Should use active_claude_ppids for ancestor tracking"
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
if [[ "$script_content" == *'active_claude_ppids[$pane_pid]'* ]]; then
    pass "Matches pane PIDs against ancestor set"
else
    fail "Should match pane PIDs against ancestor set (not just direct children)"
fi

# Should handle wrapper scripts (e.g. ralph → claude)
# The ancestor walk means any wrapper that eventually spawns claude will be detected
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

print_summary
[[ $FAIL -gt 0 ]] && exit 1
exit 0
