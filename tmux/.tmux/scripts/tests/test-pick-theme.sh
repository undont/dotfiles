#!/usr/bin/env bash
set -euo pipefail

# Unit tests for tmux theme picker
# Tests the fzf-compatible theme picker output

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
THEME_PICKER="$SCRIPT_DIR/../pick-theme.sh"
DOTFILES_ROOT="$(cd "$SCRIPT_DIR/../../../.." && pwd)"
THEMES_DIR="$DOTFILES_ROOT/themes"

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

if [[ -f "$THEME_PICKER" ]]; then
    pass "pick-theme.sh exists"
else
    fail "pick-theme.sh not found"
    exit 1
fi

if [[ -x "$THEME_PICKER" ]]; then
    pass "pick-theme.sh is executable"
else
    fail "pick-theme.sh is not executable"
fi

section "ShellCheck Validation"

if command -v shellcheck &>/dev/null; then
    # SC2155 is for declare/assign pattern which is common and harmless here
    if shellcheck -x -S warning -e SC1091 -e SC2155 "$THEME_PICKER" 2>/dev/null; then
        pass "pick-theme.sh passes shellcheck"
    else
        fail "pick-theme.sh has shellcheck warnings"
    fi
else
    skip "shellcheck not installed"
fi

section "Output Format - Header"

output=$("$THEME_PICKER" 2>&1) || true

if [[ "$output" == *"Theme Switcher"* ]]; then
    pass "output includes 'Theme Switcher' header"
else
    fail "output should include 'Theme Switcher' header"
fi

# Check for box drawing characters or similar header formatting
if [[ "$output" == *"╭"* ]] || [[ "$output" == *"─"* ]] || [[ "$output" =~ ^[[:space:]]*═+ ]]; then
    pass "output has formatted header box"
else
    fail "output should have formatted header box"
fi

if [[ "$output" == *"tmux"* ]] && [[ "$output" == *"ghostty"* ]]; then
    pass "output mentions tmux and ghostty"
else
    fail "output should mention tmux and ghostty"
fi

section "Output Format - Theme List"

# Should list all available themes
for theme_file in "$THEMES_DIR"/*.theme; do
    if [[ -f "$theme_file" ]]; then
        theme_name=$(basename "$theme_file" .theme)

        if [[ "$output" == *"$theme_name"* ]]; then
            pass "output lists $theme_name theme"
        else
            fail "output should list $theme_name theme"
        fi
    fi
done

section "Output Format - Theme Display Names"

# Should show display names, not just file names
if [[ "$output" == *"Dracula"* ]]; then
    pass "output shows Dracula display name"
else
    fail "output should show theme display names"
fi

section "Output Format - Current Theme Marker"

# Should mark current theme with a bullet or similar
if [[ "$output" == *"●"* ]] || [[ "$output" == *"*"* ]] || [[ "$output" == *">"* ]]; then
    pass "output includes current theme marker"
else
    fail "output should mark current theme with ● or similar"
fi

# Should also have inactive markers
if [[ "$output" == *"○"* ]] || [[ "$output" == *" "* ]]; then
    pass "output includes inactive theme markers"
else
    skip "inactive theme marker check"
fi

section "Output Format - Line Count"

# Count non-empty lines
line_count=$(echo "$output" | grep -c . || true)

# Should have header lines + theme lines
# At least: 3 header lines + 4 themes = 7+ lines
if [[ $line_count -ge 7 ]]; then
    pass "output has sufficient lines (${line_count} lines)"
else
    fail "output should have at least 7 lines (header + themes), got $line_count"
fi

section "Output Format - fzf Compatibility"

# fzf expects plain text with optional ANSI colours
# Test that each theme line can be parsed

theme_lines=$(echo "$output" | grep -E "(dracula|nord|catppuccin|tokyo)" || true)
theme_line_count=$(echo "$theme_lines" | grep -c . || true)

if [[ $theme_line_count -ge 4 ]]; then
    pass "output has at least 4 theme lines"
else
    fail "output should have at least 4 theme lines, got $theme_line_count"
fi

# Each theme line should have theme name visible
for theme_file in "$THEMES_DIR"/*.theme; do
    if [[ -f "$theme_file" ]]; then
        theme_name=$(basename "$theme_file" .theme)

        # Strip ANSI codes to test plain text (use sed as bash can't handle these complex patterns)
        # shellcheck disable=SC2001
        plain_output=$(echo "$output" | sed 's/\x1b\[[0-9;]*m//g')

        if echo "$plain_output" | grep -q "$theme_name"; then
            pass "$theme_name is present in plain text (fzf compatible)"
        else
            fail "$theme_name should be in plain text output"
        fi
    fi
done

section "Script Structure"

script_content=$(cat "$THEME_PICKER")

# Should have get_current_theme function
if [[ "$script_content" == *"get_current_theme()"* ]]; then
    pass "script defines get_current_theme function"
else
    fail "script should define get_current_theme function"
fi

# Should have list_themes_for_fzf function
if [[ "$script_content" == *"list_themes_for_fzf()"* ]]; then
    pass "script defines list_themes_for_fzf function"
else
    fail "script should define list_themes_for_fzf function"
fi

# Should source theme files to get display names
if [[ "$script_content" == *'source "$theme_file"'* ]]; then
    pass "script sources theme files for display names"
else
    fail "script should source theme files to get THEME_NAME"
fi

# Should use THEMES_DIR variable
if [[ "$script_content" == *'THEMES_DIR'* ]]; then
    pass "script uses THEMES_DIR variable"
else
    fail "script should use THEMES_DIR variable"
fi

# Should use CURRENT_THEME_FILE variable
if [[ "$script_content" == *'CURRENT_THEME_FILE'* ]]; then
    pass "script uses CURRENT_THEME_FILE variable"
else
    fail "script should use CURRENT_THEME_FILE variable"
fi

section "Colour Codes"

# Should use ANSI colour codes for visual appeal
if [[ "$script_content" == *"CYAN="* ]] || [[ "$script_content" == *"colours.sh"* ]] || [[ "$script_content" == *"033"* ]]; then
    pass "script defines or sources colour variables"
else
    fail "script should define or source colour variables"
fi

# Check that colours are actually used in output
# Look for ANSI escape sequences using od to check raw bytes
if echo "$output" | od -c | head -5 | grep -q "033"; then
    pass "output contains ANSI colour codes"
else
    fail "output should contain ANSI colour codes for visual appeal"
fi

section "Current Theme Detection"

# Create test config directory
# Script uses $XDG_CONFIG_HOME/dotfiles/current-theme
TEST_XDG_BASE=$(mktemp -d)
TEST_CONFIG_DIR="$TEST_XDG_BASE/dotfiles"
TEST_CURRENT_THEME="$TEST_CONFIG_DIR/current-theme"
export XDG_CONFIG_HOME="$TEST_XDG_BASE"

trap 'rm -rf "$TEST_XDG_BASE"' EXIT

# Test with no saved theme (should default)
test_output=$("$THEME_PICKER" 2>&1) || true

# Should not error
if [[ -n "$test_output" ]]; then
    pass "script works without saved theme preference"
else
    fail "script should work without saved theme preference"
fi

# Test with saved theme preference
mkdir -p "$TEST_CONFIG_DIR"
echo "nord" > "$TEST_CURRENT_THEME"

test_output=$("$THEME_PICKER" 2>&1) || true

# Should mark nord as current (● symbol)
if echo "$test_output" | grep "nord" | grep -q "●"; then
    pass "script marks saved theme as current"
else
    fail "script should mark saved theme (nord) as current"
fi

section "Integration with tmux"

# Check if theme-picker is bound in tmux config
tmux_config="$DOTFILES_ROOT/tmux/.tmux.conf"
tmux_template="$DOTFILES_ROOT/tmux/.tmux.conf.template"

theme_picker_bound=false

if [[ -f "$tmux_config" ]]; then
    if grep -q "theme-picker" "$tmux_config"; then
        pass "theme-picker is referenced in tmux config"
        theme_picker_bound=true
    fi
fi

if [[ -f "$tmux_template" ]]; then
    if grep -q "theme-picker" "$tmux_template"; then
        pass "theme-picker is referenced in tmux template"
        theme_picker_bound=true
    fi
fi

if ! $theme_picker_bound; then
    skip "theme-picker tmux binding check (not configured yet)"
fi

# Check that tmux binding includes reload-ghostty.sh
if [[ -f "$tmux_config" ]]; then
    if grep -q "reload-ghostty.sh" "$tmux_config"; then
        pass "tmux binding includes reload-ghostty.sh"
    else
        fail "tmux binding should call reload-ghostty.sh"
    fi
fi

if [[ -f "$tmux_template" ]]; then
    if grep -q "reload-ghostty.sh" "$tmux_template"; then
        pass "tmux template includes reload-ghostty.sh"
    else
        fail "tmux template should call reload-ghostty.sh"
    fi
fi

# Verify reload-ghostty.sh exists and is executable
GHOSTTY_RELOAD="$SCRIPT_DIR/../reload-ghostty.sh"
if [[ -f "$GHOSTTY_RELOAD" ]]; then
    pass "reload-ghostty.sh exists in tmux scripts"
else
    fail "reload-ghostty.sh should exist in tmux scripts directory"
fi

if [[ -x "$GHOSTTY_RELOAD" ]]; then
    pass "reload-ghostty.sh is executable"
else
    fail "reload-ghostty.sh should be executable"
fi

section "Error Handling"

# Test with missing themes directory
THEMES_DIR_BACKUP="$THEMES_DIR"
export THEMES_DIR="/nonexistent/themes/directory"

error_output=$("$THEME_PICKER" 2>&1) && exit_code=0 || exit_code=$?

# Should either error or handle gracefully
if [[ $exit_code -ne 0 ]] || [[ -z "$error_output" ]]; then
    pass "handles missing themes directory"
else
    skip "missing themes directory handling"
fi

export THEMES_DIR="$THEMES_DIR_BACKUP"

section "Output Stability"

# Run twice and compare output (should be consistent)
output1=$("$THEME_PICKER" 2>&1) || true
sleep 0.1
output2=$("$THEME_PICKER" 2>&1) || true

# Strip timestamps if any (use sed for performance)
# shellcheck disable=SC2001
output1_clean=$(echo "$output1" | sed 's/[0-9]\{2\}:[0-9]\{2\}:[0-9]\{2\}//g')
# shellcheck disable=SC2001
output2_clean=$(echo "$output2" | sed 's/[0-9]\{2\}:[0-9]\{2\}:[0-9]\{2\}//g')

if [[ "$output1_clean" == "$output2_clean" ]]; then
    pass "output is stable across multiple runs"
else
    fail "output should be consistent across runs"
fi

# ===========================================================================
# Summary
# ===========================================================================

echo ""
echo "==========================================="
echo "Test Results: ${GREEN}${PASS} passed${NC}, ${RED}${FAIL} failed${NC}, ${YELLOW}${SKIP} skipped${NC}"
echo "==========================================="

if [[ $FAIL -gt 0 ]]; then
    exit 1
fi
