#!/usr/bin/env bash
set -euo pipefail

# tests for set-default-shell.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/_test-helpers.sh"

SET_SHELL_SCRIPT="$SCRIPT_DIR/../install/set-default-shell.sh"

section "set-default-shell Tests"

output=$(SHELL=/usr/bin/zsh "$SET_SHELL_SCRIPT" 2>&1 || true)
if [[ "$output" == *"already zsh"* ]]; then
    pass "Exits early when shell is already zsh"
else
    fail "Should skip when shell is already zsh (got: $output)"
fi

# PATH is a dir holding only bash, plus /usr/bin (env); passes only where
# /usr/bin has no zsh
BASH_DIR="$(dirname "$(command -v bash)")"
FAKE_DIR=$(mktemp -d)
ln -sf "$(command -v bash)" "$FAKE_DIR/bash"
output=$(PATH="$FAKE_DIR:/usr/bin" SHELL=/bin/bash "$SET_SHELL_SCRIPT" 2>&1 || true)
rm -rf "$FAKE_DIR"
if [[ "$output" == *"zsh not found"* ]]; then
    pass "Warns when zsh not in PATH"
else
    fail "Should warn when zsh not found (got: $output)"
fi

skip "chsh path requires sudo and modifies /etc/shells"

print_summary

if [[ $FAIL -gt 0 ]]; then
    exit 1
fi
