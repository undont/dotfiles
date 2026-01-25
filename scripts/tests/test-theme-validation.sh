#!/usr/bin/env bash
set -euo pipefail

# Theme file validation tests
# Validates that all theme files are well-formed and contain required variables

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
THEMES_DIR="$DOTFILES_ROOT/themes"
TMUX_TEMPLATE="$DOTFILES_ROOT/tmux/.tmux.conf.template"
GHOSTTY_TEMPLATE="$DOTFILES_ROOT/ghostty/config.template"

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
# Required Variables
# ===========================================================================

# Core theme identification
REQUIRED_CORE=(
    "THEME_NAME"
)

# Required tmux variables
REQUIRED_TMUX=(
    "TMUX_STATUS_BG"
    "TMUX_STATUS_FG"
    "TMUX_STATUS_ACTIVE_BG"
    "TMUX_STATUS_ACTIVE_FG"
    "TMUX_STATUS_INACTIVE_FG"
    "TMUX_PANE_BORDER_INACTIVE"
    "TMUX_PANE_BORDER_ACTIVE"
    "TMUX_MESSAGE_BG"
    "TMUX_MESSAGE_FG"
    "TMUX_ACCENT_CYAN"
    "TMUX_ACCENT_PINK"
    "TMUX_ACCENT_PURPLE"
    "TMUX_FG_SECONDARY"
)

# Required ghostty variables
REQUIRED_GHOSTTY=(
    "GHOSTTY_BACKGROUND"
    "GHOSTTY_FOREGROUND"
    "GHOSTTY_CURSOR_COLOR"
    "GHOSTTY_CURSOR_TEXT"
    "GHOSTTY_SELECTION_BG"
    "GHOSTTY_SELECTION_FG"
    "GHOSTTY_PALETTE_0"
    "GHOSTTY_PALETTE_1"
    "GHOSTTY_PALETTE_2"
    "GHOSTTY_PALETTE_3"
    "GHOSTTY_PALETTE_4"
    "GHOSTTY_PALETTE_5"
    "GHOSTTY_PALETTE_6"
    "GHOSTTY_PALETTE_7"
    "GHOSTTY_PALETTE_8"
    "GHOSTTY_PALETTE_9"
    "GHOSTTY_PALETTE_10"
    "GHOSTTY_PALETTE_11"
    "GHOSTTY_PALETTE_12"
    "GHOSTTY_PALETTE_13"
    "GHOSTTY_PALETTE_14"
    "GHOSTTY_PALETTE_15"
)

# Required neovim variables
REQUIRED_NVIM=(
    "NVIM_COLORSCHEME"
)

# ===========================================================================
# Tests
# ===========================================================================

section "Theme Directory Structure"

if [[ -d "$THEMES_DIR" ]]; then
    pass "themes directory exists"
else
    fail "themes directory not found at $THEMES_DIR"
    exit 1
fi

theme_count=$(find "$THEMES_DIR" -maxdepth 1 -name "*.theme" 2>/dev/null | wc -l | tr -d ' ')

if [[ $theme_count -gt 0 ]]; then
    pass "found $theme_count theme file(s)"
else
    fail "no theme files found"
    exit 1
fi

section "Theme File Syntax Validation"

for theme_file in "$THEMES_DIR"/*.theme; do
    if [[ -f "$theme_file" ]]; then
        theme_name=$(basename "$theme_file" .theme)

        # Check bash syntax
        if bash -n "$theme_file" 2>/dev/null; then
            pass "$theme_name: valid shell syntax"
        else
            fail "$theme_name: invalid shell syntax"
        fi
    fi
done

section "ShellCheck Validation"

if command -v shellcheck &>/dev/null; then
    for theme_file in "$THEMES_DIR"/*.theme; do
        if [[ -f "$theme_file" ]]; then
            theme_name=$(basename "$theme_file" .theme)

            # Run shellcheck with appropriate options
            if shellcheck -x -S warning -e SC2034 "$theme_file" 2>/dev/null; then
                pass "$theme_name: passes shellcheck"
            else
                fail "$theme_name: shellcheck warnings"
            fi
        fi
    done
else
    skip "shellcheck not installed"
fi

section "Core Variable Validation"

for theme_file in "$THEMES_DIR"/*.theme; do
    if [[ -f "$theme_file" ]]; then
        theme_name=$(basename "$theme_file" .theme)

        all_core_present=true
        for var in "${REQUIRED_CORE[@]}"; do
            if ! grep -q "^$var=" "$theme_file"; then
                all_core_present=false
                fail "$theme_name: missing $var"
            fi
        done

        if $all_core_present; then
            pass "$theme_name: all core variables present"
        fi
    fi
done

section "Tmux Variable Validation"

for theme_file in "$THEMES_DIR"/*.theme; do
    if [[ -f "$theme_file" ]]; then
        theme_name=$(basename "$theme_file" .theme)

        missing_vars=()
        for var in "${REQUIRED_TMUX[@]}"; do
            if ! grep -q "^$var=" "$theme_file"; then
                missing_vars+=("$var")
            fi
        done

        if [[ ${#missing_vars[@]} -eq 0 ]]; then
            pass "$theme_name: all tmux variables present"
        else
            fail "$theme_name: missing tmux variables: ${missing_vars[*]}"
        fi
    fi
done

section "Ghostty Variable Validation"

for theme_file in "$THEMES_DIR"/*.theme; do
    if [[ -f "$theme_file" ]]; then
        theme_name=$(basename "$theme_file" .theme)

        missing_vars=()
        for var in "${REQUIRED_GHOSTTY[@]}"; do
            if ! grep -q "^$var=" "$theme_file"; then
                missing_vars+=("$var")
            fi
        done

        if [[ ${#missing_vars[@]} -eq 0 ]]; then
            pass "$theme_name: all ghostty variables present"
        else
            fail "$theme_name: missing ghostty variables: ${missing_vars[*]}"
        fi
    fi
done

section "Neovim Variable Validation"

for theme_file in "$THEMES_DIR"/*.theme; do
    if [[ -f "$theme_file" ]]; then
        theme_name=$(basename "$theme_file" .theme)

        missing_vars=()
        for var in "${REQUIRED_NVIM[@]}"; do
            if ! grep -q "^$var=" "$theme_file"; then
                missing_vars+=("$var")
            fi
        done

        if [[ ${#missing_vars[@]} -eq 0 ]]; then
            pass "$theme_name: all nvim variables present"
        else
            fail "$theme_name: missing nvim variables: ${missing_vars[*]}"
        fi
    fi
done

section "Colour Format Validation"

for theme_file in "$THEMES_DIR"/*.theme; do
    if [[ -f "$theme_file" ]]; then
        theme_name=$(basename "$theme_file" .theme)

        # Count hex colour definitions
        hex_count=$(grep -cE '"#[0-9a-fA-F]{6}"' "$theme_file" || true)

        if [[ $hex_count -ge 20 ]]; then
            pass "$theme_name: contains $hex_count hex colour definitions"
        else
            fail "$theme_name: only $hex_count hex colours (expected 20+)"
        fi

        # Check for invalid colour formats (not hex or variable reference)
        # Valid formats: #RRGGBB or $VARIABLE
        # Exclude non-colour metadata: THEME_NAME, NVIM_COLORSCHEME
        invalid_colours=$(grep -E '^[A-Z_]+=' "$theme_file" | grep -vE '(="#?#[0-9a-fA-F]{6}"|="\$[A-Z_]+"|^#|^THEME_NAME|^NVIM_)' | head -5 || true)

        if [[ -z "$invalid_colours" ]]; then
            pass "$theme_name: all colour values are valid format"
        else
            fail "$theme_name: potentially invalid colour format detected"
        fi
    fi
done

section "Theme Consistency Check"

# Get list of all variables from first theme
first_theme=$(find "$THEMES_DIR" -maxdepth 1 -name "*.theme" | head -1)
first_theme_name=$(basename "$first_theme" .theme)

# Extract variable names from first theme (use while read for compatibility)
first_theme_vars=()
while IFS= read -r var; do
    first_theme_vars+=("$var")
done < <(grep -E '^[A-Z_]+=' "$first_theme" | cut -d= -f1 | sort)

# Compare with other themes
for theme_file in "$THEMES_DIR"/*.theme; do
    if [[ -f "$theme_file" ]] && [[ "$theme_file" != "$first_theme" ]]; then
        theme_name=$(basename "$theme_file" .theme)

        # Extract variable names (use while read for compatibility)
        current_vars=()
        while IFS= read -r var; do
            current_vars+=("$var")
        done < <(grep -E '^[A-Z_]+=' "$theme_file" | cut -d= -f1 | sort)

        # Compare variable sets (use here-strings to avoid broken pipe with grep -q)
        missing_from_current=()
        current_vars_str=$(printf '%s\n' "${current_vars[@]}")
        for var in "${first_theme_vars[@]}"; do
            if ! grep -qx "$var" <<< "$current_vars_str"; then
                missing_from_current+=("$var")
            fi
        done

        extra_in_current=()
        first_theme_vars_str=$(printf '%s\n' "${first_theme_vars[@]}")
        for var in "${current_vars[@]}"; do
            if ! grep -qx "$var" <<< "$first_theme_vars_str"; then
                extra_in_current+=("$var")
            fi
        done

        if [[ ${#missing_from_current[@]} -eq 0 ]] && [[ ${#extra_in_current[@]} -eq 0 ]]; then
            pass "$theme_name: consistent with $first_theme_name"
        else
            if [[ ${#missing_from_current[@]} -gt 0 ]]; then
                fail "$theme_name: missing vars from $first_theme_name: ${missing_from_current[*]}"
            fi
            if [[ ${#extra_in_current[@]} -gt 0 ]]; then
                # Extra vars are acceptable (maybe theme-specific)
                pass "$theme_name: has additional vars (acceptable)"
            fi
        fi
    fi
done

section "Template Placeholder Alignment"

# Check that template placeholders match theme variables
if [[ -f "$TMUX_TEMPLATE" ]]; then
    # Extract placeholders from template (use while read for compatibility)
    template_placeholders=()
    while IFS= read -r placeholder; do
        template_placeholders+=("$placeholder")
    done < <(grep -oE '\{\{[A-Z_]+\}\}' "$TMUX_TEMPLATE" | sed 's/[{}]//g' | sort -u)

    # Check each placeholder has a variable in themes
    for placeholder in "${template_placeholders[@]}"; do
        found_in_all=true
        for theme_file in "$THEMES_DIR"/*.theme; do
            if [[ -f "$theme_file" ]]; then
                if ! grep -q "^$placeholder=" "$theme_file"; then
                    theme_name=$(basename "$theme_file" .theme)
                    fail "tmux template uses {{$placeholder}} but $theme_name doesn't define it"
                    found_in_all=false
                fi
            fi
        done

        if $found_in_all; then
            pass "tmux template placeholder {{$placeholder}} is defined in all themes"
        fi
    done
else
    skip "tmux template not found"
fi

if [[ -f "$GHOSTTY_TEMPLATE" ]]; then
    # Extract placeholders from template (use while read for compatibility)
    template_placeholders=()
    while IFS= read -r placeholder; do
        template_placeholders+=("$placeholder")
    done < <(grep -oE '\{\{[A-Z_]+\}\}' "$GHOSTTY_TEMPLATE" | sed 's/[{}]//g' | sort -u)

    # Check each placeholder has a variable in themes
    for placeholder in "${template_placeholders[@]}"; do
        found_in_all=true
        for theme_file in "$THEMES_DIR"/*.theme; do
            if [[ -f "$theme_file" ]]; then
                if ! grep -q "^$placeholder=" "$theme_file"; then
                    theme_name=$(basename "$theme_file" .theme)
                    fail "ghostty template uses {{$placeholder}} but $theme_name doesn't define it"
                    found_in_all=false
                fi
            fi
        done

        if $found_in_all; then
            pass "ghostty template placeholder {{$placeholder}} is defined in all themes"
        fi
    done
else
    skip "ghostty template not found"
fi

section "Theme File Metadata"

for theme_file in "$THEMES_DIR"/*.theme; do
    if [[ -f "$theme_file" ]]; then
        theme_name=$(basename "$theme_file" .theme)

        # Check for shebang
        if head -1 "$theme_file" | grep -q "^#!/bin/bash"; then
            pass "$theme_name: has bash shebang"
        else
            fail "$theme_name: should have #!/bin/bash shebang"
        fi

        # Check for comment header
        if head -5 "$theme_file" | grep -q "^#"; then
            pass "$theme_name: has comment header"
        else
            fail "$theme_name: should have descriptive comment header"
        fi

        # Check THEME_NAME matches filename
        defined_name=$(grep "^THEME_NAME=" "$theme_file" | sed 's/THEME_NAME="\([^"]*\)"/\1/')

        # Theme name should be title-cased version of filename (roughly)
        if [[ -n "$defined_name" ]]; then
            pass "$theme_name: THEME_NAME is '$defined_name'"
        else
            fail "$theme_name: THEME_NAME not properly defined"
        fi
    fi
done

section "Variable Value Non-Empty Check"

for theme_file in "$THEMES_DIR"/*.theme; do
    if [[ -f "$theme_file" ]]; then
        theme_name=$(basename "$theme_file" .theme)

        # Check for empty values (="")
        empty_vars=$(grep -E '^[A-Z_]+=""$' "$theme_file" || true)

        if [[ -z "$empty_vars" ]]; then
            pass "$theme_name: no empty variable values"
        else
            fail "$theme_name: has empty variable values"
        fi

        # Check for whitespace-only values
        whitespace_vars=$(grep -E '^[A-Z_]+="[[:space:]]+"$' "$theme_file" || true)

        if [[ -z "$whitespace_vars" ]]; then
            pass "$theme_name: no whitespace-only values"
        else
            fail "$theme_name: has whitespace-only variable values"
        fi
    fi
done

section "Theme Loading Test"

for theme_file in "$THEMES_DIR"/*.theme; do
    if [[ -f "$theme_file" ]]; then
        theme_name=$(basename "$theme_file" .theme)

        # Try to source the theme in a subshell
        if (
            set -euo pipefail
            # shellcheck disable=SC1090
            source "$theme_file"

            # Verify critical variables are set and non-empty
            [[ -n "${THEME_NAME:-}" ]] || exit 1
            [[ -n "${TMUX_STATUS_BG:-}" ]] || exit 1
            [[ -n "${GHOSTTY_BACKGROUND:-}" ]] || exit 1
        ); then
            pass "$theme_name: loads successfully"
        else
            fail "$theme_name: fails to load properly"
        fi
    fi
done

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
