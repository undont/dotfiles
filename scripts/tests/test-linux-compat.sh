#!/usr/bin/env bash
# shellcheck disable=SC2030,SC2031
set -euo pipefail

# tests sed_inplace, update_zshrc_export and clipboard detection, and greps
# the templates and scripts for their platform branches

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

source "$SCRIPT_DIR/_test-helpers.sh"

# shellcheck source=scripts/_lib/common.sh
source "$DOTFILES_ROOT/scripts/_lib/common.sh"

_TEST_TMPFILES=()
_TEST_TMPDIRS=()
trap 'rm -f "${_TEST_TMPFILES[@]}"; [[ ${#_TEST_TMPDIRS[@]} -gt 0 ]] && rm -rf "${_TEST_TMPDIRS[@]}"' EXIT

# ===========================================================================
# Tests
# ===========================================================================

section "sed_inplace Helper"

if declare -f sed_inplace &>/dev/null; then
    pass "sed_inplace function is defined"
else
    fail "sed_inplace function should be defined in common.sh"
fi

test_file=$(mktemp)
_TEST_TMPFILES+=("$test_file")
echo "hello world" >"$test_file"
sed_inplace "s/hello/goodbye/" "$test_file"
result=$(cat "$test_file")
if [[ "$result" == "goodbye world" ]]; then
    pass "sed_inplace performs simple substitution"
else
    fail "sed_inplace substitution failed (got: '$result')"
fi

test_file2=$(mktemp)
_TEST_TMPFILES+=("$test_file2")
echo "foo bar" >"$test_file2"
sed_inplace "s/foo/baz/" "$test_file2"
# BSD sed leaves file-e or file.bak backups
backup_files=$(find "$(dirname "$test_file2")" -name "$(basename "$test_file2")*" ! -name "$(basename "$test_file2")" 2>/dev/null || true)
if [[ -z "$backup_files" ]]; then
    pass "sed_inplace does not leave backup files"
else
    fail "sed_inplace left backup files behind: $backup_files"
fi

# the append command is what update_zshrc_export uses
test_file3=$(mktemp)
_TEST_TMPFILES+=("$test_file3")
cat >"$test_file3" <<'EOF'
line1
line2
line3
EOF
sed_inplace "2a\\
inserted" "$test_file3"
if grep -q "inserted" "$test_file3"; then
    pass "sed_inplace append command works"
else
    fail "sed_inplace append command failed"
fi


section "update_zshrc_export (Portable sed)"

# update_zshrc_export reads $HOME/.zshrc
setup_sandbox
cat >"$HOME/.zshrc" <<'EOF'
# YOUR PERSONAL CONFIGURATION
# Add your settings below

export EXISTING_VAR="old_value"
EOF

update_zshrc_export "EXISTING_VAR" "new_value"
if grep -q 'export EXISTING_VAR="new_value"' "$HOME/.zshrc"; then
    pass "update_zshrc_export updates existing variable"
else
    fail "update_zshrc_export should update existing variable"
fi

update_zshrc_export "NEW_VAR" "test_value"
if grep -q 'export NEW_VAR="test_value"' "$HOME/.zshrc"; then
    pass "update_zshrc_export adds new variable"
else
    fail "update_zshrc_export should add new variable"
fi

cleanup_sandbox

section "Ghostty Config Template"

if grep -q '{{PLATFORM_CONFIG}}' "$DOTFILES_ROOT/ghostty/config.template"; then
    pass "ghostty template uses PLATFORM_CONFIG placeholder"
else
    fail "ghostty template should use {{PLATFORM_CONFIG}} placeholder"
fi

if ! grep -q 'macos-icon' "$DOTFILES_ROOT/ghostty/config.template"; then
    pass "ghostty template has no hardcoded macos-icon"
else
    fail "ghostty template should not contain hardcoded macos-icon (use PLATFORM_CONFIG)"
fi

if ! grep -q 'macos-option-as-alt' "$DOTFILES_ROOT/ghostty/config.template"; then
    pass "ghostty template has no hardcoded macos-option-as-alt"
else
    fail "ghostty template should not contain hardcoded macos-option-as-alt"
fi

if ! grep -q 'keybind = opt+' "$DOTFILES_ROOT/ghostty/config.template"; then
    pass "ghostty template has no hardcoded opt+ keybindings"
else
    fail "ghostty template should not contain hardcoded opt+ keybindings"
fi

section "Tmux Config Template Clipboard"

if grep -q '{{CLIPBOARD_CMD}}' "$DOTFILES_ROOT/tmux/tmux.conf.template"; then
    pass "tmux template uses CLIPBOARD_CMD placeholder"
else
    fail "tmux template should use {{CLIPBOARD_CMD}} placeholder"
fi

if ! grep -q '"pbcopy"' "$DOTFILES_ROOT/tmux/tmux.conf.template"; then
    pass "tmux template has no hardcoded pbcopy"
else
    fail "tmux template should not contain hardcoded pbcopy"
fi

section "Theme-Switch Platform Handling"

THEME_SWITCH="$DOTFILES_ROOT/scripts/theme-switch"

if grep -q 'PLATFORM_CONFIG' "$THEME_SWITCH"; then
    pass "theme-switch handles PLATFORM_CONFIG substitution"
else
    fail "theme-switch should handle PLATFORM_CONFIG substitution"
fi

if grep -q 'mod="opt"' "$THEME_SWITCH" && grep -q 'mod="alt"' "$THEME_SWITCH"; then
    pass "theme-switch has both macOS (opt) and Linux (alt) modifier keys"
else
    fail "theme-switch should have both opt and alt modifier key variants"
fi

if grep -q 'macos-icon' "$THEME_SWITCH"; then
    pass "theme-switch mentions macos-icon"
else
    fail "theme-switch should mention macos-icon"
fi

if grep -q 'CLIPBOARD_CMD' "$THEME_SWITCH"; then
    pass "theme-switch handles CLIPBOARD_CMD substitution"
else
    fail "theme-switch should handle CLIPBOARD_CMD substitution"
fi

if grep -q '_lib/clipboard.sh' "$THEME_SWITCH" && grep -q 'clipboard_copy_cmd' "$THEME_SWITCH"; then
    pass "theme-switch resolves clipboard via the shared lib"
else
    fail "theme-switch should source _lib/clipboard.sh and call clipboard_copy_cmd"
fi

if ! grep -qE '^\s*(elif )?(command_exists|command -v) (wl-copy|xclip|xsel)' "$THEME_SWITCH"; then
    pass "theme-switch has no duplicate clipboard detection"
else
    fail "theme-switch should not re-implement clipboard detection"
fi

section "Generate-Theme Ghostty Path Fallbacks"

GENERATE_THEME="$DOTFILES_ROOT/scripts/generate-theme"

if grep -q '/usr/share/ghostty/themes' "$GENERATE_THEME" &&
    grep -q '/usr/local/share/ghostty/themes' "$GENERATE_THEME" &&
    grep -q '.local/share/ghostty/themes' "$GENERATE_THEME"; then
    pass "generate-theme searches multiple Linux Ghostty theme paths"
else
    fail "generate-theme should search multiple Linux paths for Ghostty themes"
fi

if grep -q 'find_ghostty_themes' "$GENERATE_THEME"; then
    pass "generate-theme uses find_ghostty_themes function"
else
    fail "generate-theme should use find_ghostty_themes for path discovery"
fi

section "Install Script Linux Compatibility"

INSTALL_PACKAGES="$DOTFILES_ROOT/scripts/install/install-packages.sh"
if grep -q 'pacman' "$INSTALL_PACKAGES" &&
    grep -q 'apt-get' "$INSTALL_PACKAGES" &&
    grep -q 'dnf' "$INSTALL_PACKAGES"; then
    pass "install-packages.sh handles multiple Linux distros for Ghostty"
else
    fail "install-packages.sh should handle pacman, apt-get, and dnf for Ghostty"
fi

# scans scripts/ and tmux/scripts/ (which has its own sed_inplace in
# tmux/scripts/_lib/common.sh) for `sed -i ''`, excluding the two common.sh
# files and this test
other_sed_files=$(grep -rl "sed -i ''" "$DOTFILES_ROOT/scripts/" "$DOTFILES_ROOT/tmux/scripts/" 2>/dev/null |
    grep -v '_lib/common.sh' | grep -v 'test-linux-compat.sh' || true)
if [[ -z "$other_sed_files" ]]; then
    pass "no sed -i '' calls outside of sed_inplace helper"
else
    fail "found sed -i '' calls outside of sed_inplace: $other_sed_files"
fi

section "Clipboard Detection (Functional)"

# sources the shared lib under a fake linux PATH holding only the named tools
# usage: clipboard_test "<tools>" "<WAYLAND_DISPLAY>" "<DISPLAY>"
_CLIP_FAKE_BIN="$(mktemp -d)"
_TEST_TMPDIRS+=("$_CLIP_FAKE_BIN")
_clipboard_call() {
    local fn="$1" available_cmds="$2" wayland="${3:-}" x11="${4:-}"
    local bin="$_CLIP_FAKE_BIN"

    rm -f "${bin:?}"/*
    printf '#!/bin/sh\necho Linux\n' >"$bin/uname"
    local c
    for c in $available_cmds; do
        printf '#!/bin/sh\nexit 0\n' >"$bin/$c"
    done
    chmod +x "$bin"/*

    (
        # PATH is set last: rm/chmod above still need the real one
        export PATH="$bin" WAYLAND_DISPLAY="$wayland" DISPLAY="$x11"
        unset _DOTFILES_CLIPBOARD_SH_LOADED
        # shellcheck source=scripts/_lib/clipboard.sh
        source "$DOTFILES_ROOT/scripts/_lib/clipboard.sh"
        "$fn"
    )
}

clipboard_test() { _clipboard_call clipboard_copy_cmd "$@"; }
clipboard_backend_test() { _clipboard_call clipboard_backend "$@"; }

# a wayland session with xclip installed (via XWayland) picks wl-copy
result=$(clipboard_test "wl-copy xclip xsel" "wayland-0" "")
assert_equals "prefers wl-copy on a wayland session" "wl-copy" "$result"

result=$(clipboard_test "wl-copy xclip xsel" "wayland-0" ":0")
assert_equals "prefers wl-copy when both display servers are set" "wl-copy" "$result"

result=$(clipboard_test "wl-copy xclip xsel" "" ":0")
assert_equals "prefers xclip on an X11 session" "xclip -selection clipboard" "$result"

result=$(clipboard_test "xsel" "" ":0")
assert_equals "falls back to xsel when no xclip" "xsel --clipboard --input" "$result"

# wl-copy present with no wayland session and no X11
result=$(clipboard_test "wl-copy xclip xsel" "" "")
assert_equals "ignores display tools when headless" "cat >/dev/null" "$result"

result=$(clipboard_test "" "" "")
assert_equals "discards when no clipboard tool is found" "cat >/dev/null" "$result"

# a running display server with no tool installed is `missing`, not `osc52`
result=$(clipboard_backend_test "" "wayland-0" "")
assert_equals "wayland session with no tool reports missing, not osc52" "missing" "$result"

result=$(clipboard_backend_test "" "" ":0")
assert_equals "X11 session with no tool reports missing, not osc52" "missing" "$result"

result=$(clipboard_backend_test "" "" "")
assert_equals "genuinely headless reports osc52" "osc52" "$result"

result=$(clipboard_backend_test "wl-copy" "wayland-0" "")
assert_equals "wayland session with wl-copy reports wayland" "wayland" "$result"

section "find_ghostty_themes Fallback (Functional)"

# a copy of find_ghostty_themes: generate-theme runs main when sourced
result=$(
    is_macos() { return 1; }
    HOME="/nonexistent"
    find_ghostty_themes() {
        if is_macos; then
            echo "/Applications/Ghostty.app/Contents/Resources/ghostty/themes"
            return
        fi
        local paths=(
            "/usr/share/ghostty/themes"
            "/usr/local/share/ghostty/themes"
            "$HOME/.local/share/ghostty/themes"
        )
        for p in "${paths[@]}"; do
            if [[ -d "$p" ]]; then
                echo "$p"
                return
            fi
        done
        echo "/usr/share/ghostty/themes"
    }
    find_ghostty_themes
)
if [[ "$result" == "/usr/share/ghostty/themes" ]]; then
    pass "find_ghostty_themes falls back to /usr/share/ghostty/themes"
else
    fail "find_ghostty_themes fallback returned: $result"
fi

section "update_zshrc_export Edge Cases"

setup_sandbox
cat >"$HOME/.zshrc" <<'EOF'
# YOUR PERSONAL CONFIGURATION
EOF
update_zshrc_export "DEV_ROOT" "/home/user/dev/projects"
if grep -q 'export DEV_ROOT="/home/user/dev/projects"' "$HOME/.zshrc"; then
    pass "update_zshrc_export handles paths with slashes"
else
    fail "update_zshrc_export should handle paths with slashes"
fi

# the sed a\ append branch strips unescaped backslashes
setup_sandbox
cat >"$HOME/.zshrc" <<'EOF'
# YOUR PERSONAL CONFIGURATION
EOF
update_zshrc_export "DEV_ROOT" '/home/user/a\b'
if grep -qF 'export DEV_ROOT="/home/user/a\b"' "$HOME/.zshrc"; then
    pass "update_zshrc_export preserves backslashes on first write"
else
    fail "update_zshrc_export dropped a backslash: $(grep '^export DEV_ROOT=' "$HOME/.zshrc")"
fi

cleanup_sandbox
setup_sandbox
echo "# Plain zshrc with no marker" >"$HOME/.zshrc"
update_zshrc_export "TEST_VAR" "some_value"
if grep -q 'export TEST_VAR="some_value"' "$HOME/.zshrc"; then
    pass "update_zshrc_export appends when no marker found"
else
    fail "update_zshrc_export should append to end when no marker"
fi
cleanup_sandbox

# ===========================================================================
# Summary
# ===========================================================================

print_summary

if [[ $FAIL -gt 0 ]]; then
    exit 1
fi
