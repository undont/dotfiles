#!/usr/bin/env bash
set -euo pipefail

# Test suite for Brewfile filtering utilities

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../_lib/test.sh"
source "$SCRIPT_DIR/../_lib/brewfile.sh"

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

echo ""
echo "==========================================="
echo "Test Results: ${GREEN}${PASS} passed${NC}, ${RED}${FAIL} failed${NC}"
echo "==========================================="

if [[ $FAIL -gt 0 ]]; then
    exit 1
fi
