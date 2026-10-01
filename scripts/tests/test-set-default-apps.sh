#!/usr/bin/env bash
set -euo pipefail

# tests for set-default-apps.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/_test-helpers.sh"
source "$SCRIPT_DIR/../_lib/common.sh"

SET_APPS_SCRIPT="$SCRIPT_DIR/../install/set-default-apps.sh"

section "set-default-apps Tests"

if is_macos; then
    skip "non-macOS early-exit test (on macOS)"
else
    output=$("$SET_APPS_SCRIPT" 2>&1 || true)
    if [[ "$output" == *"macOS-only"* ]]; then
        pass "Skips cleanly on Linux"
    else
        fail "Should skip default-app setup off macOS (got: $output)"
    fi
fi

# duti lives in the homebrew prefix, so a /usr/bin-only PATH hides it
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

# /bin/bash is 3.2 on macOS. `bash -n` catches syntax 3.2 cannot parse, not
# `declare -A`, which parses and fails at runtime
if [[ -x /bin/bash ]]; then
    if /bin/bash -n "$SET_APPS_SCRIPT" 2>/dev/null; then
        pass "Parses under system bash 3.2"
    else
        fail "Should parse under system bash 3.2 (no bash 4+ syntax)"
    fi
else
    skip "bash 3.2 parse test (/bin/bash absent)"
fi

skip "handler-binding path modifies LaunchServices defaults"

print_summary

if [[ $FAIL -gt 0 ]]; then
    exit 1
fi
