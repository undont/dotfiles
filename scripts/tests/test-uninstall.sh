#!/usr/bin/env bash
set -euo pipefail

# tests for uninstall.sh structure and symlink removal logic

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

source "$SCRIPT_DIR/_test-helpers.sh"

UNINSTALL_SCRIPT="$DOTFILES_DIR/scripts/install/uninstall.sh"

# ===========================================================================
# Tests
# ===========================================================================

section "Uninstall script structure"

if [[ -x "$UNINSTALL_SCRIPT" ]]; then
    pass "uninstall.sh exists and is executable"
else
    fail "uninstall.sh missing or not executable"
fi

if grep -q 'source.*common\.sh' "$UNINSTALL_SCRIPT"; then
    pass "uninstall.sh sources common.sh"
else
    fail "uninstall.sh does not source common.sh"
fi

if grep -q 'restore.backup' "$UNINSTALL_SCRIPT"; then
    pass "uninstall.sh supports --restore-backup flag"
else
    fail "uninstall.sh missing --restore-backup support"
fi

if grep -q 'remove.brew.packages' "$UNINSTALL_SCRIPT"; then
    pass "uninstall.sh supports --remove-brew-packages flag"
else
    fail "uninstall.sh missing --remove-brew-packages support"
fi

if bash "$UNINSTALL_SCRIPT" --help 2>&1 | grep -qi "uninstall\|usage\|remove" 2>/dev/null; then
    pass "uninstall.sh has help output"
else
    skip "uninstall.sh has no --help flag"
fi

for override in ghostty tmux nvim; do
    if grep -q "$override.*local" "$UNINSTALL_SCRIPT"; then
        pass "uninstall.sh handles $override local override"
    else
        fail "uninstall.sh missing $override local override handling"
    fi
done

section "Symlink removal logic (sandboxed)"

setup_sandbox
trap cleanup_sandbox EXIT

# a copy of uninstall.sh's removal loop and its `[[ -L "$link" ]]` guard; the
# script itself prompts for confirmation, so it is not executed. the real file
# is in the list, so only the guard keeps it
mkdir -p "$TEST_HOME/.config/zsh"
ln -sf "$DOTFILES_DIR/zsh/dotfiles.zsh" "$TEST_HOME/.config/zsh/dotfiles.zsh"
ln -sf "$DOTFILES_DIR/zsh/zprofile" "$TEST_HOME/.zprofile"
echo "real config" >"$TEST_HOME/.test-real-file"

if [[ -L "$TEST_HOME/.config/zsh/dotfiles.zsh" && -L "$TEST_HOME/.zprofile" ]]; then
    pass "test symlinks created successfully"
else
    fail "could not create test symlinks"
fi

for link in "$TEST_HOME/.config/zsh/dotfiles.zsh" "$TEST_HOME/.zprofile" \
    "$TEST_HOME/.test-real-file"; do
    if [[ -L "$link" ]]; then
        rm -f "$link"
    fi
done

if [[ ! -e "$TEST_HOME/.config/zsh/dotfiles.zsh" && ! -e "$TEST_HOME/.zprofile" ]]; then
    pass "symlink removal works correctly"
else
    fail "symlinks were not removed"
fi

if [[ -f "$TEST_HOME/.test-real-file" && ! -L "$TEST_HOME/.test-real-file" ]]; then
    pass "non-symlink file in the removal list is preserved"
else
    fail "non-symlink file was incorrectly removed"
fi

# ===========================================================================
# Summary
# ===========================================================================

print_summary
[[ $FAIL -gt 0 ]] && exit 1
exit 0
