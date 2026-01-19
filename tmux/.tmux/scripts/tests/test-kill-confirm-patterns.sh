#!/usr/bin/env bash
# Test kill and confirm patterns for windows, panes, and sessions
set -euo pipefail

# Determine repository root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../../.." && pwd)"
SCRIPTS_DIR="$REPO_ROOT/tmux/.tmux/scripts"
LIB_DIR="$SCRIPTS_DIR/_lib"

GREEN=$'\033[0;32m'
RED=$'\033[0;31m'
YELLOW=$'\033[0;33m'
NC=$'\033[0m'

PASS=0
FAIL=0

pass() {
    echo "  ${GREEN}✓${NC} $1"
    PASS=$((PASS + 1))
}

fail() {
    echo "  ${RED}✗${NC} $1"
    FAIL=$((FAIL + 1))
}

echo "${GREEN}Testing tmux kill/confirm patterns${NC}"
echo ""

# Test standardized confirmation functions
echo "${YELLOW}=== Standardized confirmation functions ===${NC}"
if grep -q "^show_visual_confirm()" "$LIB_DIR/ui.sh"; then
    pass "show_visual_confirm defined in ui.sh"
else
    fail "show_visual_confirm not found in ui.sh"
fi

if grep -q "^tmux_confirm_last_item()" "$LIB_DIR/ui.sh"; then
    pass "tmux_confirm_last_item defined in ui.sh"
else
    fail "tmux_confirm_last_item not found in ui.sh"
fi

# Test agent alert functions
echo ""
echo "${YELLOW}=== Agent alert functions ===${NC}"
if grep -q "^clear_window_alerts()" "$LIB_DIR/alerts.sh"; then
    pass "clear_window_alerts defined"
else
    fail "clear_window_alerts not found"
fi

if grep -q "^clear_session_alerts()" "$LIB_DIR/alerts.sh"; then
    pass "clear_session_alerts defined"
else
    fail "clear_session_alerts not found"
fi

if grep -q "^get_agent_display()" "$LIB_DIR/alerts.sh"; then
    pass "get_agent_display defined"
else
    fail "get_agent_display not found"
fi

# Test kill scripts exist
echo ""
echo "${YELLOW}=== Kill script files ===${NC}"
for script in kill-window.sh kill-pane.sh kill-session.sh; do
    if [[ -f "$SCRIPTS_DIR/$script" ]] && [[ -x "$SCRIPTS_DIR/$script" ]]; then
        pass "$script exists and is executable"
    else
        fail "$script missing or not executable"
    fi
done

# Test helper scripts exist
if [[ -f "$SCRIPTS_DIR/fzf-confirm.sh" ]] && [[ -x "$SCRIPTS_DIR/fzf-confirm.sh" ]]; then
    pass "fzf-confirm.sh helper exists and is executable"
else
    fail "fzf-confirm.sh helper missing or not executable"
fi

# Test uses standardized visual confirmation
echo ""
echo "${YELLOW}=== Using standardized visual confirmation ===${NC}"
for script in kill-window.sh kill-pane.sh kill-session.sh; do
    if grep -q "show_visual_confirm\|tmux_confirm_last_item" "$SCRIPTS_DIR/$script"; then
        pass "$script uses standardized confirmation"
    else
        fail "$script doesn't use standardized confirmation"
    fi
done

# Test no old confirmation pattern
echo ""
echo "${YELLOW}=== No deprecated confirmation patterns ===${NC}"
for script in kill-window.sh kill-pane.sh; do
    if ! grep -q "show_centered_confirm" "$SCRIPTS_DIR/$script"; then
        pass "$script doesn't use show_centered_confirm"
    else
        fail "$script still uses show_centered_confirm"
    fi
done

# Test agent terminology
echo ""
echo "${YELLOW}=== Agent-agnostic terminology ===${NC}"
for file in kill-session.sh session-rename.sh window-rename.sh update-timestamp.sh; do
    if grep -i "claude.*alert" "$SCRIPTS_DIR/$file" | grep -qv "ALERTS_FILE\|^#"; then
        fail "$file has claude-specific alert references"
    else
        pass "$file uses agent-agnostic terminology"
    fi
done

# Summary
echo ""
echo "==========================================="
echo "Test Results: ${GREEN}$PASS passed${NC}, ${RED}$FAIL failed${NC}"
echo "==========================================="

[[ $FAIL -eq 0 ]] && exit 0 || exit 1
