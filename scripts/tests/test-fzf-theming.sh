#!/usr/bin/env bash
# tests for FZF theming functionality
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# shellcheck source=scripts/_lib/common.sh
source "$SCRIPT_DIR/../_lib/common.sh"

source "$SCRIPT_DIR/_test-helpers.sh"

# ══════════════════════════════════════════════════════════════
# Test Suite
# ══════════════════════════════════════════════════════════════

main() {
    print_header "FZF Theming Tests"

    section "Theme File Validation"

    for theme_file in "$DOTFILES_ROOT/themes"/*.theme; do
        theme_name=$(basename "$theme_file" .theme)

        if (
            # shellcheck disable=SC1090
            source "$theme_file"

            # shellcheck disable=SC1091
            source "$DOTFILES_ROOT/themes/theme-defaults.sh"
            apply_theme_defaults

            missing_vars=()
            [[ -z "${FZF_BG:-}" ]] && missing_vars+=("FZF_BG")
            [[ -z "${FZF_FG:-}" ]] && missing_vars+=("FZF_FG")
            [[ -z "${FZF_BORDER:-}" ]] && missing_vars+=("FZF_BORDER")
            [[ -z "${FZF_PROMPT:-}" ]] && missing_vars+=("FZF_PROMPT")
            [[ -z "${FZF_POINTER:-}" ]] && missing_vars+=("FZF_POINTER")
            [[ -z "${FZF_HEADER:-}" ]] && missing_vars+=("FZF_HEADER")

            [[ ${#missing_vars[@]} -eq 0 ]]
        ); then
            pass "$theme_name has all required FZF variables"
        else
            fail "$theme_name is missing FZF variables"
        fi
    done

    section "FZF Theme Script"

    if [[ -f "$DOTFILES_ROOT/scripts/fzf-theme.sh" ]]; then
        pass "fzf-theme.sh exists"
    else
        fail "fzf-theme.sh not found"
        return 1
    fi

    if source "$DOTFILES_ROOT/scripts/fzf-theme.sh" 2>/dev/null; then
        pass "fzf-theme.sh can be sourced"
    else
        fail "fzf-theme.sh failed to source"
        return 1
    fi

    if [[ -n "${FZF_DEFAULT_OPTS:-}" ]]; then
        pass "FZF_DEFAULT_OPTS is exported"
    else
        fail "FZF_DEFAULT_OPTS is not set"
    fi

    if echo "$FZF_DEFAULT_OPTS" | grep -q "color="; then
        pass "FZF_DEFAULT_OPTS contains colour definitions"
    else
        fail "FZF_DEFAULT_OPTS missing colour definitions"
    fi

    local theme_vars=("FZF_THEME_BG" "FZF_THEME_FG" "FZF_THEME_BORDER" "FZF_THEME_PROMPT" "FZF_THEME_POINTER" "FZF_THEME_HEADER")
    local missing_theme_vars=()
    for var in "${theme_vars[@]}"; do
        if [[ -z "${!var:-}" ]]; then
            missing_theme_vars+=("$var")
        fi
    done

    if [[ ${#missing_theme_vars[@]} -eq 0 ]]; then
        pass "All FZF_THEME_* variables are exported"
    else
        fail "Missing FZF_THEME_* variables" "${missing_theme_vars[*]}"
    fi

    section "Theme Switching"

    # theme-switch and fzf-theme.sh derive their output paths from
    # XDG_CONFIG_HOME, so a temp dir keeps the real config files untouched
    _THEME_TEST_XDG=$(mktemp -d)
    _ORIGINAL_XDG="${XDG_CONFIG_HOME:-}"

    local original_theme
    if [[ -f "${XDG_CONFIG_HOME:-$HOME/.config}/dotfiles/current-theme" ]]; then
        original_theme=$(cat "${XDG_CONFIG_HOME:-$HOME/.config}/dotfiles/current-theme")
    else
        original_theme="dracula"
    fi

    export XDG_CONFIG_HOME="$_THEME_TEST_XDG"
    mkdir -p "$_THEME_TEST_XDG/dotfiles" "$_THEME_TEST_XDG/tmux" "$_THEME_TEST_XDG/ghostty"
    echo "$original_theme" >"$_THEME_TEST_XDG/dotfiles/current-theme"

    # compares one colour per theme: FZF_THEME_BORDER against FZF_BORDER
    for theme_file in "$DOTFILES_ROOT/themes"/*.theme; do
        theme_name=$(basename "$theme_file" .theme)

        "$DOTFILES_ROOT/scripts/theme-switch" "$theme_name" --no-reload --quiet

        # shellcheck disable=SC1091
        source "$DOTFILES_ROOT/scripts/fzf-theme.sh"

        (
            # shellcheck disable=SC1090
            source "$theme_file"
            # shellcheck disable=SC1091
            source "$DOTFILES_ROOT/themes/theme-defaults.sh"
            apply_theme_defaults

            if [[ "$FZF_THEME_BORDER" == "$FZF_BORDER" ]]; then
                exit 0
            else
                exit 1
            fi
        ) && pass "$theme_name border colour loads" || fail "$theme_name border colour mismatch"
    done

    if [[ -n "$_ORIGINAL_XDG" ]]; then
        export XDG_CONFIG_HOME="$_ORIGINAL_XDG"
    else
        unset XDG_CONFIG_HOME
    fi
    rm -rf "$_THEME_TEST_XDG"

    section "Colour Format Validation"

    # shellcheck disable=SC1091
    source "$DOTFILES_ROOT/scripts/fzf-theme.sh"

    if [[ "$FZF_THEME_BORDER" =~ ^#[0-9a-fA-F]{6}$ ]]; then
        pass "FZF colours are in valid hex format"
    else
        fail "FZF colours are not in hex format" "Got: $FZF_THEME_BORDER"
    fi

    if echo "$FZF_DEFAULT_OPTS" | grep -qE '#[0-9a-fA-F]{6}'; then
        pass "FZF_DEFAULT_OPTS uses hex colours"
    else
        fail "FZF_DEFAULT_OPTS does not use hex colours"
    fi

    section "Integration with dotfiles.zsh"

    if grep -q "fzf-theme.sh" "$DOTFILES_ROOT/zsh/dotfiles.zsh"; then
        pass "dotfiles.zsh sources fzf-theme.sh"
    else
        fail "dotfiles.zsh does not source fzf-theme.sh"
    fi

    local fzf_line zsh_line
    fzf_line=$(grep -n "fzf --zsh" "$DOTFILES_ROOT/zsh/dotfiles.zsh" | head -1 | cut -d: -f1)
    zsh_line=$(grep -n "fzf-theme.sh" "$DOTFILES_ROOT/zsh/dotfiles.zsh" | head -1 | cut -d: -f1)

    if [[ -n "$fzf_line" && -n "$zsh_line" ]] && [[ "$zsh_line" -gt "$fzf_line" ]]; then
        pass "fzf-theme.sh sourced after fzf initialization"
    else
        fail "fzf-theme.sh not sourced after fzf initialization" "fzf line: $fzf_line, theme line: $zsh_line"
    fi

    section "Integration with tmux"

    if [[ -f "$DOTFILES_ROOT/tmux/scripts/themes/reload-fzf.sh" ]]; then
        pass "reload-fzf.sh exists"
    else
        fail "reload-fzf.sh not found"
    fi

    if [[ -x "$DOTFILES_ROOT/tmux/scripts/themes/reload-fzf.sh" ]]; then
        pass "reload-fzf.sh is executable"
    else
        fail "reload-fzf.sh is not executable"
    fi

    if grep -q "reload-fzf.sh" "$DOTFILES_ROOT/tmux/scripts/themes/picker.sh"; then
        pass "tmux theme picker calls reload-fzf.sh"
    else
        fail "tmux theme picker does not call reload-fzf.sh"
    fi

    if grep -q "fzf-theme.sh\|load_fzf_theme" "$DOTFILES_ROOT/tmux/scripts/themes/pick.sh"; then
        pass "themes/pick.sh loads FZF theme"
    else
        fail "themes/pick.sh does not load FZF theme"
    fi

    # ══════════════════════════════════════════════════════════════
    # Summary
    # ══════════════════════════════════════════════════════════════

    printf "\n"
    print_header "Test Summary"

    print_summary

    if [[ $FAIL -gt 0 ]]; then
        exit 1
    else
        exit 0
    fi
}

main "$@"
