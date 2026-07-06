#!/usr/bin/env bash
set -euo pipefail

# test suite for set-default-apps.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/_test-helpers.sh"
source "$SCRIPT_DIR/../_lib/common.sh"

SET_APPS_SCRIPT="$SCRIPT_DIR/../install/set-default-apps.sh"

section "set-default-apps Tests"

# test: non-macOS early exit
if is_macos; then
    skip "macOS early-exit test (not on Linux)"
else
    output=$("$SET_APPS_SCRIPT" 2>&1 || true)
    if [[ "$output" == *"macOS-only"* ]]; then
        pass "Skips cleanly on Linux"
    else
        fail "Should skip default-app setup off macOS (got: $output)"
    fi
fi

# test: duti missing, should warn and exit without touching handlers.
# duti lives in the Homebrew prefix, so a /usr/bin-only PATH hides it.
if is_macos; then
    output=$(PATH="/usr/bin:/bin" "$SET_APPS_SCRIPT" 2>&1 || true)
    if [[ "$output" == *"duti not installed"* ]]; then
        pass "Warns and exits when duti is missing"
    else
        fail "Should warn when duti not found (got: $output)"
    fi
else
    skip "duti-missing test (macOS only)"
fi

# note: the binding path mutates LaunchServices, skip in the suite
skip "handler-binding path modifies LaunchServices defaults"

print_summary

if [[ $FAIL -gt 0 ]]; then
    exit 1
fi
