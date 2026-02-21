#!/usr/bin/env bash
set -euo pipefail

# Test suite for Brewfile filtering utilities

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Note: Test scripts use full cd+pwd for absolute paths.
# Production scripts use simpler ${BASH_SOURCE%/*} pattern.
source "$SCRIPT_DIR/../_lib/brewfile.sh"
source "$SCRIPT_DIR/../_lib/common.sh"

# Source shared test helpers (colours, pass/fail/skip/section, assertions)
source "$SCRIPT_DIR/_test-helpers.sh"

section "Brewfile Library Tests"

# Create test Brewfile
TEST_BREWFILE=$(mktemp)
trap 'rm -f "$TEST_BREWFILE"' EXIT
cat > "$TEST_BREWFILE" << 'EOF'
tap "homebrew/bundle"
# @preset: minimal
brew "zsh"
brew "tmux"
# @preset: core
brew "neovim"
cask "ghostty"
# @preset: full
cask "hammerspoon"
EOF

section "filter_brewfile Function"

# Test minimal filtering
minimal_output=$(filter_brewfile "minimal" "$TEST_BREWFILE")
if [[ "$minimal_output" == *'brew "zsh"'* ]]; then
    pass "minimal preset includes zsh"
else
    fail "minimal preset should include zsh"
fi
if [[ "$minimal_output" != *'brew "neovim"'* ]]; then
    pass "minimal preset excludes neovim"
else
    fail "minimal preset should exclude neovim"
fi

# Test core filtering
core_output=$(filter_brewfile "core" "$TEST_BREWFILE")
if [[ "$core_output" == *'brew "neovim"'* ]]; then
    pass "core preset includes neovim"
else
    fail "core preset should include neovim"
fi
if [[ "$core_output" != *'cask "hammerspoon"'* ]]; then
    pass "core preset excludes hammerspoon"
else
    fail "core preset should exclude hammerspoon"
fi

# Test full filtering
full_output=$(filter_brewfile "full" "$TEST_BREWFILE")
if [[ "$full_output" == *'cask "hammerspoon"'* ]]; then
    pass "full preset includes hammerspoon"
else
    fail "full preset should include hammerspoon"
fi

# Test invalid preset handling
if ! filter_brewfile "invalid" "$TEST_BREWFILE" 2>/dev/null; then
    pass "Invalid preset returns error"
else
    fail "Invalid preset should return error"
fi

section "create_filtered_brewfile Function"

# Test that create_filtered_brewfile creates a file that persists
# This is a regression test for the EXIT trap bug where the trap fired
# in the command substitution subshell, deleting the file immediately
FILTERED=$(create_filtered_brewfile "full" "$TEST_BREWFILE")
if [[ -f "$FILTERED" ]]; then
    pass "Temp file persists after command substitution"
else
    fail "Temp file should persist after command substitution (regression: EXIT trap bug)"
fi

# Verify the filtered file contains expected content
if [[ -f "$FILTERED" ]]; then
    filtered_content=$(cat "$FILTERED")
    if [[ "$filtered_content" == *'cask "hammerspoon"'* ]]; then
        pass "Filtered file contains correct content"
    else
        fail "Filtered file should contain full preset content"
    fi

    # Clean up the temp file
    rm -f "$FILTERED"
fi

# Test that create_filtered_brewfile returns error for invalid preset
if ! FILTERED=$(create_filtered_brewfile "invalid" "$TEST_BREWFILE" 2>/dev/null); then
    pass "create_filtered_brewfile returns error for invalid preset"
else
    fail "create_filtered_brewfile should return error for invalid preset"
    rm -f "$FILTERED"
fi

print_summary

if [[ $FAIL -gt 0 ]]; then
    exit 1
fi
