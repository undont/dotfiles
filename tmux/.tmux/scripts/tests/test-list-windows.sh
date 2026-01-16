#!/usr/bin/env bash
set -euo pipefail

# Unit tests for list-windows.sh
# Tests the window listing and agent alert emoji display logic

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIST_WINDOWS_SCRIPT="$SCRIPT_DIR/../list-windows.sh"
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

if [[ -f "$LIST_WINDOWS_SCRIPT" ]]; then
    pass "list-windows.sh exists"
else
    fail "list-windows.sh not found at $LIST_WINDOWS_SCRIPT"
    exit 1
fi

if [[ -x "$LIST_WINDOWS_SCRIPT" ]]; then
    pass "list-windows.sh is executable"
else
    fail "list-windows.sh is not executable"
fi

section "ShellCheck Validation"

if command -v shellcheck &>/dev/null; then
    if shellcheck -x -e SC1091 -e SC2059 -e SC2015 -e SC2016 -e SC2034 "$LIST_WINDOWS_SCRIPT" 2>/dev/null; then
        pass "list-windows.sh passes shellcheck"
    else
        fail "list-windows.sh has shellcheck warnings"
    fi
else
    skip "shellcheck not installed"
fi

section "Bash Syntax Check"

if bash -n "$LIST_WINDOWS_SCRIPT" 2>/dev/null; then
    pass "list-windows.sh has valid bash syntax"
else
    fail "list-windows.sh has syntax errors"
fi

section "Script Structure"

# Check for required usage patterns
script_content=$(cat "$LIST_WINDOWS_SCRIPT")

if [[ "$script_content" == *'source "$SCRIPT_DIR/_lib/alerts.sh"'* ]]; then
    pass "Sources alerts.sh library"
else
    fail "Should source alerts.sh library"
fi

if [[ "$script_content" == *'tmux list-windows'* ]]; then
    pass "Uses tmux list-windows to get windows"
else
    fail "Should use tmux list-windows"
fi

section "Command-Line Arguments"

# Check for --all flag support
if [[ "$script_content" == *'[[ "$1" == "--all" ]]'* ]]; then
    pass "Supports --all flag for all sessions"
else
    fail "Should support --all flag"
fi

# Check for -a flag usage with --all
if [[ "$script_content" == *'tmux list-windows -a'* ]]; then
    pass "Uses -a flag for all sessions mode"
else
    fail "Should use -a flag with --all"
fi

section "Sorting and Formatting"

# Check for last-viewed sorting
if [[ "$script_content" == *'@last-viewed'* ]]; then
    pass "Uses @last-viewed for sorting"
else
    fail "Should use @last-viewed for sorting"
fi

# Check for reverse numeric sort
if [[ "$script_content" == *'sort -rn'* ]]; then
    pass "Sorts by last-viewed (reverse numeric)"
else
    fail "Should sort by last-viewed"
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
    pass "Collects unique agents per window"
else
    fail "Should collect unique agents per window"
fi

section "Alert File Handling"

# Check for alert file existence check
if [[ "$script_content" == *'[[ -f "$ALERTS_FILE" ]]'* ]]; then
    pass "Checks if alert file exists"
else
    fail "Should check if alert file exists"
fi

# Check for correct grep pattern (session:window:agent)
if [[ "$script_content" == *'grep "^${alert_key}"'* ]]; then
    pass "Uses correct grep pattern for window alerts"
else
    fail "Should use correct grep pattern"
fi

section "Output Format"

# Check for window format (session:index window_name icons)
if [[ "$script_content" == *'echo "$line ${icons}"'* ]]; then
    pass "Outputs window info with alert icons"
else
    fail "Should output window info with icons"
fi

section "Agent Display Function Tests"

# Test get_agent_display function directly
source "$ALERTS_LIB"

# Test all agents
agents=("claude" "gemini" "opencode")
expected_displays=("⚡|#f1fa8c" "🧬|#8be9fd" "🔮|#bd93f9")
expected_icons=("⚡" "🧬" "🔮")

for i in "${!agents[@]}"; do
    agent="${agents[$i]}"
    expected="${expected_displays[$i]}"
    expected_icon="${expected_icons[$i]}"
    
    display=$(get_agent_display "$agent")
    icon="${display%%|*}"
    
    if [[ "$display" == "$expected" ]]; then
        pass "get_agent_display returns correct format for $agent"
    else
        fail "get_agent_display should return '$expected' for $agent (got: $display)"
    fi
    
    if [[ "$icon" == "$expected_icon" ]]; then
        pass "Correctly extracts $agent emoji ($expected_icon)"
    else
        fail "Should extract $expected_icon from $agent display (got: $icon)"
    fi
done

section "Alert File Format Tests"

# Test grep pattern with sample alert file content
TEMP_ALERTS=$(mktemp)
cat > "$TEMP_ALERTS" <<'EOF'
dotfiles:dot:opencode
dotfiles:dev:claude
dotfiles:dev:gemini
dana:backend:gemini
EOF

# Test finding all agents for a window
test_session="dotfiles"
test_window="dev"
alert_key="${test_session}:${test_window}:"
test_agents=$(grep "^${alert_key}" "$TEMP_ALERTS" 2>/dev/null | cut -d: -f3 | sort -u)
expected_agents="claude
gemini"

if [[ "$test_agents" == "$expected_agents" ]]; then
    pass "Correctly extracts unique agents for window"
else
    fail "Should extract 'claude' and 'gemini' for dotfiles:dev (got: $test_agents)"
fi

# Test building icons for window
icons=""
while IFS= read -r agent; do
    display=$(get_agent_display "$agent")
    icon="${display%%|*}"
    icons="${icons}${icon}"
done <<< "$test_agents"

if [[ "$icons" == "⚡🧬" ]]; then
    pass "Correctly builds icons for window with multiple agents"
else
    fail "Should build '⚡🧬' for dotfiles:dev (got: $icons)"
fi

# Test single agent window
alert_key="dotfiles:dot:"
test_agents=$(grep "^${alert_key}" "$TEMP_ALERTS" 2>/dev/null | cut -d: -f3 | sort -u)
icons=""
while IFS= read -r agent; do
    display=$(get_agent_display "$agent")
    icon="${display%%|*}"
    icons="${icons}${icon}"
done <<< "$test_agents"

if [[ "$icons" == "🔮" ]]; then
    pass "Correctly builds icon for window with single agent"
else
    fail "Should build '🔮' for dotfiles:dot (got: $icons)"
fi

rm -f "$TEMP_ALERTS"

section "Window Name Parsing Tests"

# Test parsing window line format
test_line="dotfiles:1 dev"
session_idx=$(echo "$test_line" | cut -d' ' -f1)
session_name="${session_idx%%:*}"
window_name=$(echo "$test_line" | cut -d' ' -f2-)

if [[ "$session_idx" == "dotfiles:1" ]]; then
    pass "Correctly extracts session:index"
else
    fail "Should extract 'dotfiles:1' (got: $session_idx)"
fi

if [[ "$session_name" == "dotfiles" ]]; then
    pass "Correctly extracts session name"
else
    fail "Should extract 'dotfiles' (got: $session_name)"
fi

if [[ "$window_name" == "dev" ]]; then
    pass "Correctly extracts window name"
else
    fail "Should extract 'dev' (got: $window_name)"
fi

# Test with multi-word window name
test_line="dana:2 backend server"
window_name=$(echo "$test_line" | cut -d' ' -f2-)

if [[ "$window_name" == "backend server" ]]; then
    pass "Correctly extracts multi-word window name"
else
    fail "Should extract 'backend server' (got: $window_name)"
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
    # Test current session mode
    if output=$("$LIST_WINDOWS_SCRIPT" 2>/dev/null); then
        pass "Runs successfully (current session mode)"
        
        # Check output contains window info
        if echo "$output" | grep -qE '^[a-zA-Z0-9_-]+:[0-9]+ '; then
            pass "Output contains window info (session:index name)"
        else
            fail "Output should contain window info"
        fi
        
        # Check if output contains emojis when alerts exist
        if [[ -f ~/.claude/alerts ]] && grep -q ":" ~/.claude/alerts; then
            if echo "$output" | grep -qE '[⚡🧬🔮]'; then
                pass "Output contains agent emojis when alerts exist"
            else
                skip "No emojis in output (alerts may not match current windows)"
            fi
        else
            skip "No alert file or alerts to test emoji display"
        fi
    else
        fail "Failed to run list-windows.sh (current session)"
    fi
    
    # Test all sessions mode
    if output=$("$LIST_WINDOWS_SCRIPT" --all 2>/dev/null); then
        pass "Runs successfully (--all mode)"
        
        # Check output contains session:index format
        if echo "$output" | grep -qE '^[a-zA-Z0-9_-]+:[0-9]+ '; then
            pass "Output contains session:index in --all mode"
        else
            fail "Output should contain session:index in --all mode"
        fi
    else
        fail "Failed to run list-windows.sh --all"
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
