#!/usr/bin/env bash
set -euo pipefail

# Test suite for setup-keyd.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/_test-helpers.sh"
source "$SCRIPT_DIR/../_lib/common.sh"

SETUP_KEYD_SCRIPT="$SCRIPT_DIR/../install/setup-keyd.sh"

section "setup-keyd Tests"

# Test: macOS early exit
if is_macos; then
    output=$("$SETUP_KEYD_SCRIPT" 2>&1 || true)
    if [[ "$output" == *"Linux-only"* ]]; then
        pass "Exits cleanly on macOS"
    else
        fail "Should skip keyd setup on macOS (got: $output)"
    fi
else
    skip "macOS early-exit test (not on macOS)"
fi

# Test: missing config file
output=$(DOTFILES_DIR="/nonexistent/path" "$SETUP_KEYD_SCRIPT" 2>&1 || true)
if is_macos; then
    skip "Missing config test (macOS exits before config check)"
elif [[ "$output" == *"not found"* ]]; then
    pass "Errors when keyd config not found"
else
    fail "Should error when config not found (got: $output)"
fi

# Note: package installation and systemd paths require sudo — skip in CI
skip "Package install path requires sudo"
skip "systemd service management requires sudo"

print_summary

if [[ $FAIL -gt 0 ]]; then
    exit 1
fi
