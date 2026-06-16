#!/usr/bin/env bash
set -euo pipefail

# test suite for set-default-shell.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/_test-helpers.sh"

SET_SHELL_SCRIPT="$SCRIPT_DIR/../install/set-default-shell.sh"

section "set-default-shell Tests"

# test: shell already zsh, should exit early
output=$(SHELL=/usr/bin/zsh "$SET_SHELL_SCRIPT" 2>&1 || true)
if [[ "$output" == *"already zsh"* ]]; then
    pass "Exits early when shell is already zsh"
else
    fail "Should skip when shell is already zsh (got: $output)"
fi

# test: zsh not in PATH, should warn and exit
# build a PATH that has bash but not zsh by using the actual bash location
BASH_DIR="$(dirname "$(command -v bash)")"
FAKE_DIR=$(mktemp -d)
# symlink only bash into the fake dir so zsh won't be found
ln -sf "$(command -v bash)" "$FAKE_DIR/bash"
output=$(PATH="$FAKE_DIR:/usr/bin" SHELL=/bin/bash "$SET_SHELL_SCRIPT" 2>&1 || true)
rm -rf "$FAKE_DIR"
if [[ "$output" == *"zsh not found"* ]]; then
    pass "Warns when zsh not in PATH"
else
    fail "Should warn when zsh not found (got: $output)"
fi

# note: chsh and /etc/shells paths require sudo, skip in CI
skip "chsh path requires sudo and modifies /etc/shells"

print_summary

if [[ $FAIL -gt 0 ]]; then
    exit 1
fi
