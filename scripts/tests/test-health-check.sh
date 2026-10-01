#!/usr/bin/env bash
set -euo pipefail

# tests for health-check.sh structure and validation logic

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

source "$SCRIPT_DIR/_test-helpers.sh"

HEALTH_SCRIPT="$DOTFILES_DIR/scripts/install/health-check.sh"

# ===========================================================================
# Tests
# ===========================================================================

section "Health check script structure"

if [[ -x "$HEALTH_SCRIPT" ]]; then
    pass "health-check.sh exists and is executable"
else
    fail "health-check.sh missing or not executable"
fi

if bash "$HEALTH_SCRIPT" --help 2>&1 | grep -qi "health\|check\|usage" 2>/dev/null; then
    pass "health-check.sh has help output"
else
    skip "health-check.sh has no --help flag"
fi

if grep -q 'source.*common\.sh' "$HEALTH_SCRIPT"; then
    pass "health-check.sh sources common.sh"
else
    fail "health-check.sh does not source common.sh"
fi

section "Health check coverage"

for item in zsh tmux nvim; do
    if grep -q "$item" "$HEALTH_SCRIPT"; then
        pass "health-check.sh validates $item configuration"
    else
        fail "health-check.sh missing $item validation"
    fi
done

for plugin in tpm lazy; do
    if grep -q "$plugin" "$HEALTH_SCRIPT"; then
        pass "health-check.sh validates $plugin plugins"
    else
        fail "health-check.sh missing $plugin validation"
    fi
done

if grep -q 'check_symlink' "$HEALTH_SCRIPT"; then
    pass "health-check.sh has symlink validation function"
else
    fail "health-check.sh missing symlink validation"
fi

if grep -q 'Generated Configs\|generated' "$HEALTH_SCRIPT"; then
    pass "health-check.sh checks generated config files"
else
    fail "health-check.sh missing generated config checks"
fi

if grep -q 'Local Override\|local.conf\|local.lua\|local.yml' "$HEALTH_SCRIPT"; then
    pass "health-check.sh checks local override files"
else
    fail "health-check.sh missing local override checks"
fi

section "Health check with sandboxed HOME"

setup_sandbox
trap cleanup_sandbox EXIT

# exit 1 (issues found) is expected with an empty HOME; anything higher is a crash
export DOTFILES_DIR
PRESET="minimal"
export DOTFILES_PRESET="$PRESET"
exit_code=0
bash "$HEALTH_SCRIPT" >/dev/null 2>&1 || exit_code=$?

if [[ $exit_code -le 1 ]]; then
    pass "health-check.sh exits with expected code ($exit_code) in empty HOME"
else
    fail "health-check.sh crashed with unexpected exit code: $exit_code"
fi

# ===========================================================================
# Summary
# ===========================================================================

print_summary
[[ $FAIL -gt 0 ]] && exit 1
exit 0
