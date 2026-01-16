#!/usr/bin/env bash
set -euo pipefail

# Unit tests for list-sessions.sh
# Tests the session listing and agent alert emoji display logic

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIST_SESSIONS_SCRIPT="$SCRIPT_DIR/../list-sessions.sh"
ALERTS_LIB="$SCRIPT_DIR/../_lib/alerts.sh"

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

if [[ -f "$LIST_SESSIONS_SCRIPT" ]]; then
    pass "list-sessions.sh exists"
else
    fail "list-sessions.sh not found at $LIST_SESSIONS_SCRIPT"
    exit 1
fi

if [[ -x "$LIST_SESSIONS_SCRIPT" ]]; then
    pass "list-sessions.sh is executable"
else
    fail "list-sessions.sh is not executable"
fi

section "ShellCheck Validation"

if command -v shellcheck &>/dev/null; then
    if shellcheck -x -e SC1091 -e SC2059 -e SC2015 -e SC2016 -e SC2034 "$LIST_SESSIONS_SCRIPT" 2>/dev/null; then
        pass "list-sessions.sh passes shellcheck"
    else
        fail "list-sessions.sh has shellcheck warnings"
    fi
else
    skip "shellcheck not installed"
fi

section "Bash Syntax Check"

if bash -n "$LIST_SESSIONS_SCRIPT" 2>/dev/null; then
    pass "list-sessions.sh has valid bash syntax"
else
    fail "list-sessions.sh has syntax errors"
fi

section "Script Structure"

# Check for required usage patterns
script_content=$(cat "$LIST_SESSIONS_SCRIPT")

if [[ "$script_content" == *'source "$SCRIPT_DIR/_lib/alerts.sh"'* ]]; then
    pass "Sources alerts.sh library"
else
    fail "Should source alerts.sh library"
fi

if [[ "$script_content" == *'tmux list-sessions'* ]]; then
    pass "Uses tmux list-sessions to get sessions"
else
    fail "Should use tmux list-sessions"
fi

section "Agent Alert Integration"

# Check for agent display function usage
if [[ "$script_content" == *'get_agent_display'* ]]; then
    pass "Uses get_agent_display function"
else
    fail "Should use get_agent_display function"
fi

# Check for emoji extraction
if [[ "$script_content" == *'icon="${display%%|*}"'* ]]; then
    pass "Extracts emoji icon from display string"
else
    fail "Should extract emoji icon from display string"
fi

# Check for unique agent collection
if [[ "$script_content" == *'sort -u'* ]]; then
    pass "Collects unique agents per session"
else
    fail "Should collect unique agents per session"
fi

section "Alert File Handling"

# Check for alert file existence check
if [[ "$script_content" == *'[[ -f "$ALERTS_FILE" ]]'* ]]; then
    pass "Checks if alert file exists"
else
    fail "Should check if alert file exists"
fi

# Check for correct grep pattern (session:window:agent)
if [[ "$script_content" == *'grep "^${session}:"'* ]]; then
    pass "Uses correct grep pattern for session alerts"
else
    fail "Should use correct grep pattern"
fi

section "Output Format"

# Check for FZF-friendly format (session name with icons)
if [[ "$script_content" == *'echo "${session} ${icons}"'* ]]; then
    pass "Outputs session name with alert icons"
else
    fail "Should output session name with icons"
fi

section "Agent Display Function Tests"

# Test get_agent_display function directly
source "$ALERTS_LIB"

# Test Claude
claude_display=$(get_agent_display "claude")
if [[ "$claude_display" == "⚡|#f1fa8c" ]]; then
    pass "get_agent_display returns correct format for claude"
else
    fail "get_agent_display should return '⚡|#f1fa8c' for claude (got: $claude_display)"
fi

# Test Gemini
gemini_display=$(get_agent_display "gemini")
if [[ "$gemini_display" == "🧬|#8be9fd" ]]; then
    pass "get_agent_display returns correct format for gemini"
else
    fail "get_agent_display should return '🧬|#8be9fd' for gemini (got: $gemini_display)"
fi

# Test OpenCode
opencode_display=$(get_agent_display "opencode")
if [[ "$opencode_display" == "🔮|#bd93f9" ]]; then
    pass "get_agent_display returns correct format for opencode"
else
    fail "get_agent_display should return '🔮|#bd93f9' for opencode (got: $opencode_display)"
fi

section "Emoji Icon Extraction Tests"

# Test emoji extraction from display string
claude_icon="${claude_display%%|*}"
if [[ "$claude_icon" == "⚡" ]]; then
    pass "Correctly extracts Claude emoji (⚡) from display string"
else
    fail "Should extract ⚡ from claude display (got: $claude_icon)"
fi

gemini_icon="${gemini_display%%|*}"
if [[ "$gemini_icon" == "🧬" ]]; then
    pass "Correctly extracts Gemini emoji (🧬) from display string"
else
    fail "Should extract 🧬 from gemini display (got: $gemini_icon)"
fi

opencode_icon="${opencode_display%%|*}"
if [[ "$opencode_icon" == "🔮" ]]; then
    pass "Correctly extracts OpenCode emoji (🔮) from display string"
else
    fail "Should extract 🔮 from opencode display (got: $opencode_icon)"
fi

section "Multiple Agents Icon Building"

# Test building icon string for multiple agents
agents="claude
gemini
opencode"

icons=""
while IFS= read -r agent; do
    display=$(get_agent_display "$agent")
    icon="${display%%|*}"
    icons="${icons}${icon}"
done <<< "$agents"

if [[ "$icons" == "⚡🧬🔮" ]]; then
    pass "Correctly builds icon string for multiple agents"
else
    fail "Should build '⚡🧬🔮' for multiple agents (got: $icons)"
fi

section "Alert File Format Tests"

# Test grep pattern with sample alert file content
TEMP_ALERTS=$(mktemp)
cat > "$TEMP_ALERTS" <<'EOF'
dotfiles:dot:opencode
dotfiles:dev:claude
dana:backend:gemini
dana:frontend:claude
EOF

# Test finding all agents for a session
test_session="dotfiles"
test_agents=$(grep "^${test_session}:" "$TEMP_ALERTS" 2>/dev/null | cut -d: -f3 | sort -u)
expected_agents="claude
opencode"

if [[ "$test_agents" == "$expected_agents" ]]; then
    pass "Correctly extracts unique agents for session"
else
    fail "Should extract 'claude' and 'opencode' for dotfiles session (got: $test_agents)"
fi

# Test building icons for session
icons=""
while IFS= read -r agent; do
    display=$(get_agent_display "$agent")
    icon="${display%%|*}"
    icons="${icons}${icon}"
done <<< "$test_agents"

if [[ "$icons" == "⚡🔮" ]]; then
    pass "Correctly builds icons for session with multiple agents"
else
    fail "Should build '⚡🔮' for dotfiles session (got: $icons)"
fi

rm -f "$TEMP_ALERTS"

# ===========================================================================
# Integration test (only if tmux is running)
# ===========================================================================

section "Integration (Live Execution)"

if ! command -v tmux &>/dev/null; then
    skip "tmux not installed"
elif ! tmux list-sessions &>/dev/null 2>&1; then
    skip "no tmux sessions running"
else
    # Test execution
    if output=$("$LIST_SESSIONS_SCRIPT" 2>/dev/null); then
        pass "Runs successfully"
        
        # Check output contains session names
        if echo "$output" | grep -qE '^[a-zA-Z0-9_-]+'; then
            pass "Output contains session names"
        else
            fail "Output should contain session names"
        fi
        
        # Check if output contains emojis when alerts exist
        if [[ -f ~/.claude/alerts ]] && grep -q ":" ~/.claude/alerts; then
            if echo "$output" | grep -qE '[⚡🧬🔮]'; then
                pass "Output contains agent emojis when alerts exist"
            else
                skip "No emojis in output (alerts may not match current sessions)"
            fi
        else
            skip "No alert file or alerts to test emoji display"
        fi
    else
        fail "Failed to run list-sessions.sh"
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
