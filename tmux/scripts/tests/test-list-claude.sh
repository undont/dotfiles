#!/usr/bin/env bash
set -euo pipefail

# unit tests for instances/claude.sh
# tests the Claude Code instance listing and formatting logic

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIST_CLAUDE_SCRIPT="$SCRIPT_DIR/../instances/claude.sh"

source "$SCRIPT_DIR/_test-helpers.sh"

# ===========================================================================
# tests
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

# check for required usage patterns
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

if [[ "$script_content" == *'source "$SCRIPT_DIR/../_lib/process.sh"'* ]]; then
    pass "Sources process.sh library"
else
    fail "Should source process.sh library (agent_pane_pids)"
fi

if [[ "$script_content" == *'tmux list-panes -a'* ]]; then
    pass "Uses tmux list-panes to find instances"
else
    fail "Should use tmux list-panes"
fi

section "Output Format"

# check for FZF-friendly format (target from tmux output)
if [[ "$script_content" == *'target='* ]]; then
    pass "Builds target for session:window.pane format"
else
    fail "Should build target in correct format"
fi

# rows are tab-delimited: display column shown, target hidden ({2} in fzf)
if [[ "$script_content" == *'${row}${TAB}${target}'* ]]; then
    pass "Emits tab-delimited display/target rows"
else
    fail "Should emit tab-delimited display/target rows"
fi

# agent-state's idle/needs-input dot carries the alert signal in this
# claude-only view, so there is no per-row alert lookup
if [[ "$script_content" != *'ALERTS_FILE'* ]]; then
    pass "Does not duplicate alerts with the state indicator"
else
    fail "Should not integrate with the alerts file (state indicator covers it)"
fi

section "Agent State Rendering"

if [[ "$script_content" == *'AGENT_STATE_DIR'* ]]; then
    pass "Reads the agent-state registry"
else
    fail "Should read the agent-state registry (AGENT_STATE_DIR)"
fi

if [[ "$script_content" == *'get_agent_state_display'* ]]; then
    pass "Renders states via get_agent_state_display"
else
    fail "Should render states via get_agent_state_display"
fi

if [[ "$script_content" == *'AGENT_STUCK_SECS'* ]]; then
    pass "Stuck threshold is env-overridable (AGENT_STUCK_SECS)"
else
    fail "Should expose AGENT_STUCK_SECS override"
fi

if [[ "$script_content" == *'_title_has_spinner'* ]] && [[ "$script_content" == *'pane_title'* ]]; then
    pass "Corroborates stuck via pane title spinner"
else
    fail "Should corroborate stuck via pane title spinner"
fi

# no hook fires when a permission prompt is approved, so a stale needs-input
# must flip back to working once the title spinner returns
if [[ "$script_content" == *'"needs-input"'*'_title_has_spinner'* ]]; then
    pass "Flips stale needs-input to working when the spinner returns"
else
    fail "Should flip stale needs-input to working via the title spinner"
fi

# the spinner check must be locale-independent (byte-based, not a codepoint
# range that a C locale would mis-match)
if [[ "$script_content" == *'od -An -tx1'* ]]; then
    pass "Spinner check tests raw utf-8 bytes (locale-independent)"
else
    fail "Spinner check should be byte-based, not a locale-sensitive range"
fi

if [[ "$script_content" == *'_fmt_elapsed'* ]]; then
    pass "Humanises state age via _fmt_elapsed"
else
    fail "Should humanise state age via _fmt_elapsed"
fi

section "Ghost Decoration"

# check for Claude Code ghost in Anthropic orange
if [[ "$script_content" == *'▐▛███▜▌'* ]]; then
    pass "Includes Claude Code ghost decoration"
else
    fail "Should include Claude Code ghost decoration"
fi

if [[ "$script_content" == *'38;2;215;119;87'* ]]; then
    pass "Ghost uses Anthropic terracotta truecolor (#D77757)"
else
    fail "Ghost should use Anthropic terracotta truecolor (#D77757 = 215;119;87)"
fi

section "Error Handling"

# script should handle missing tmux gracefully
if [[ "$script_content" == *'command -v tmux'* ]]; then
    pass "Checks if tmux is installed"
else
    fail "Should check if tmux is installed"
fi

# script should handle no sessions gracefully
if [[ "$script_content" == *'tmux list-sessions'* ]]; then
    pass "Checks if tmux sessions exist"
else
    fail "Should check if tmux sessions exist"
fi

# script should handle no Claude instances gracefully
if [[ "$script_content" == *'${#claude_panes[@]} -eq 0'* ]]; then
    pass "Handles case with no Claude instances"
else
    fail "Should handle case with no Claude instances"
fi

section "Command Detection"

# agent_pane_pids (process.sh) finds non-stopped claude processes and their
# ancestors; its behaviour is covered in test-tmux-libs.sh
if [[ "$script_content" == *'agent_pane_pids claude'* ]]; then
    pass "Uses agent_pane_pids to find Claude panes"
else
    fail "Should use agent_pane_pids to find Claude panes"
fi

if [[ "$script_content" == *'active_claude_ppids[$pane_pid]'* ]]; then
    pass "Matches pane PIDs against the agent_pane_pids set"
else
    fail "Should match pane PIDs against the agent_pane_pids set"
fi

# ===========================================================================
# integration test (only if tmux is running)
# ===========================================================================

section "Integration (Live Execution)"

if ! command -v tmux &>/dev/null; then
    skip "tmux not installed"
elif ! command tmux list-sessions &>/dev/null 2>&1; then
    # intentionally queries the real tmux server (not the test socket) to check
    # whether there are live sessions to run the integration smoke-test against
    skip "no tmux sessions running"
else
    # test default (fzf) mode
    if output=$("$LIST_CLAUDE_SCRIPT" 2>/dev/null); then
        pass "Runs successfully in fzf mode"

        # check output format: rows end with a hidden tab-separated jump target
        if echo "$output" | grep -qE $'\t''[a-zA-Z0-9_.-]+:[0-9]+\.[0-9]+$'; then
            pass "FZF output format is correct (tab-delimited, target last)"
        elif [[ -z "$output" ]] || echo "$output" | grep -q "▐▛███▜▌"; then
            pass "FZF output is empty or has header only (no Claude instances)"
        else
            fail "Unexpected FZF output format"
        fi
    else
        fail "Failed to run in fzf mode"
    fi
fi

# ===========================================================================
# summary
# ===========================================================================

print_summary
[[ $FAIL -gt 0 ]] && exit 1
exit 0
