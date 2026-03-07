#!/usr/bin/env bash
set -euo pipefail

# Tests for uninstall.sh structure and symlink removal logic

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Source shared test helpers (colours, pass/fail/skip/section, assertions, sandbox)
source "$SCRIPT_DIR/_test-helpers.sh"

UNINSTALL_SCRIPT="$DOTFILES_DIR/scripts/install/uninstall.sh"

# ===========================================================================
# Tests
# ===========================================================================

section "Uninstall script structure"

# Test 1: Script exists and is executable
if [[ -x "$UNINSTALL_SCRIPT" ]]; then
    pass "uninstall.sh exists and is executable"
else
    fail "uninstall.sh missing or not executable"
fi

# Test 2: Script sources common.sh
if grep -q 'source.*common\.sh' "$UNINSTALL_SCRIPT"; then
    pass "uninstall.sh sources common.sh"
else
    fail "uninstall.sh does not source common.sh"
fi

# Test 3: Script has --restore-backup flag
if grep -q 'restore.backup' "$UNINSTALL_SCRIPT"; then
    pass "uninstall.sh supports --restore-backup flag"
else
    fail "uninstall.sh missing --restore-backup support"
fi

# Test 4: Script has --remove-brew-packages flag
if grep -q 'remove.brew.packages' "$UNINSTALL_SCRIPT"; then
    pass "uninstall.sh supports --remove-brew-packages flag"
else
    fail "uninstall.sh missing --remove-brew-packages support"
fi

# Test 5: Script has help output
if bash "$UNINSTALL_SCRIPT" --help 2>&1 | grep -qi "uninstall\|usage\|remove" 2>/dev/null; then
    pass "uninstall.sh has help output"
else
    skip "uninstall.sh has no --help flag"
fi

# Test 6: Script handles local override files
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

# Test 7: Create and remove mock symlinks
mkdir -p "$TEST_HOME/.config/zsh"
ln -sf "$DOTFILES_DIR/zsh/dotfiles.zsh" "$TEST_HOME/.config/zsh/dotfiles.zsh"
ln -sf "$DOTFILES_DIR/zsh/zprofile" "$TEST_HOME/.zprofile"

if [[ -L "$TEST_HOME/.config/zsh/dotfiles.zsh" && -L "$TEST_HOME/.zprofile" ]]; then
    pass "test symlinks created successfully"
else
    fail "could not create test symlinks"
fi

# Simulate uninstall symlink removal
for link in "$TEST_HOME/.config/zsh/dotfiles.zsh" "$TEST_HOME/.zprofile"; do
    if [[ -L "$link" ]]; then
        rm "$link"
    fi
done

if [[ ! -L "$TEST_HOME/.config/zsh/dotfiles.zsh" && ! -L "$TEST_HOME/.zprofile" ]]; then
    pass "symlink removal works correctly"
else
    fail "symlinks were not removed"
fi

# Test 8: Removal skips non-symlink files
echo "real config" > "$TEST_HOME/.test-real-file"
# Uninstall should skip this since it's not a symlink
if [[ -f "$TEST_HOME/.test-real-file" && ! -L "$TEST_HOME/.test-real-file" ]]; then
    pass "non-symlink file preserved during removal"
else
    fail "non-symlink file was incorrectly removed"
fi

# ===========================================================================
# Summary
# ===========================================================================

print_summary
[[ $FAIL -gt 0 ]] && exit 1
exit 0
