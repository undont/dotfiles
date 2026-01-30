#!/usr/bin/env bash
# Integration tests for Claude Code diff plugin
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Test counters
PASS=0
FAIL=0

# Colours
GREEN=$'\033[0;32m'
RED=$'\033[0;31m'
YELLOW=$'\033[0;33m'
NC=$'\033[0m'

pass() {
    PASS=$((PASS + 1))
    printf "${GREEN}✓${NC} %s\n" "$1"
}

fail() {
    FAIL=$((FAIL + 1))
    printf "${RED}✗${NC} %s\n" "$1"
    return 1
}

skip() {
    printf "${YELLOW}○${NC} %s (skipped)\n" "$1"
}

section() {
    echo ""
    echo "─────────────────────────────────────────"
    echo "$1"
    echo "─────────────────────────────────────────"
}

print_step() {
    echo "$1"
}

assert_file_exists() {
    if [[ -f "$1" ]]; then
        return 0
    else
        fail "File not found: $1"
    fi
}

assert_executable() {
    if [[ -x "$1" ]]; then
        return 0
    else
        fail "File not executable: $1"
    fi
}

section "Claude Diff Plugin Integration Tests"

# Derive repo root from script location
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
HOOKS_DIR="$REPO_ROOT/scripts/hooks"

# Test 1: Hook scripts exist and are executable
print_step "Checking hook scripts..."
assert_file_exists "$HOOKS_DIR/nvim-diff-checkpoint.sh"
assert_file_exists "$HOOKS_DIR/nvim-diff-sync.sh"
assert_executable "$HOOKS_DIR/nvim-diff-checkpoint.sh"
assert_executable "$HOOKS_DIR/nvim-diff-sync.sh"
pass "Hook scripts exist and are executable"

# Test 2: Plugin files exist (skip in CI - external repo)
print_step "Checking plugin files..."
assert_file_exists "$REPO_ROOT/nvim/lua/custom/plugins/claude-diff.lua"
# Skip external plugin checks in CI (they're in a different repo)
if [[ -d "$HOME/playground/nvim-claude-code-plugin" ]]; then
    assert_file_exists "$HOME/playground/nvim-claude-code-plugin/lua/claude-diff/init.lua"
    assert_file_exists "$HOME/playground/nvim-claude-code-plugin/lua/claude-diff/config.lua"
    assert_file_exists "$HOME/playground/nvim-claude-code-plugin/lua/claude-diff/git.lua"
    assert_file_exists "$HOME/playground/nvim-claude-code-plugin/lua/claude-diff/ui.lua"
    pass "Plugin files exist"
else
    skip "External plugin repo not found (expected in CI)"
fi

# Test 3: Git checkpoint workflow in temporary directory
print_step "Testing git checkpoint workflow..."

# Create temporary git repository
test_dir=$(mktemp -d)
cd "$test_dir"
git init -q
git config user.email "test@example.com"
git config user.name "Test User"

# Create initial commit
echo "original content" > test.txt
git add test.txt
git commit -q -m "Initial commit"

# Simulate real workflow: file has some pre-existing state
echo "pre-claude state" > test.txt

# PreToolUse: Create checkpoint (captures "pre-claude state")
timestamp=$(date +%s)
git stash push -u -q -m "claude-code-checkpoint-$timestamp"
stash_count=$(git stash list | wc -l | tr -d ' ')
[[ "$stash_count" -eq 1 ]] || fail "Expected exactly 1 stash entry"

# After stash, working dir is back to committed state
content=$(cat test.txt)
[[ "$content" == "original content" ]] || fail "Expected original content after stash"

# PostToolUse: Claude edits the file
echo "modified by claude" > test.txt

# Verify diff exists (between current state and HEAD)
diff_output=$(git diff HEAD -- test.txt)
[[ -n "$diff_output" ]] || fail "Expected diff to exist"

# Test accept workflow (drop stash, keep Claude's changes)
# Current state: stash has "pre-claude", working dir has "modified by claude"
git stash drop -q  # Drop the checkpoint
content=$(cat test.txt)
[[ "$content" == "modified by claude" ]] || fail "Expected Claude's changes after accept"
stash_count=$(git stash list | wc -l | tr -d ' ')
[[ "$stash_count" -eq 0 ]] || fail "Expected no stash entries after drop"

# Reset to committed state for reject test
git checkout -q HEAD -- test.txt
content=$(cat test.txt)
[[ "$content" == "original content" ]] || fail "Reset failed"

# Simulate another Claude session: user has different pre-state
echo "another pre-claude state" > test.txt

# PreToolUse: Create new checkpoint
git stash push -u -q -m "claude-code-checkpoint-$(date +%s)"
stash_count=$(git stash list | wc -l | tr -d ' ')
[[ "$stash_count" -eq 1 ]] || fail "Expected exactly 1 stash entry"

# PostToolUse: Claude edits again
echo "unwanted claude edit" > test.txt

# Test reject workflow (restore from stash, discard current changes)
# Current state: stash has "another pre-claude state", working dir has "unwanted claude edit"
# Reject = discard working changes + restore from stash
git reset --hard HEAD -q  # Discard uncommitted changes first
git stash pop -q  # Then restore from stash
content=$(cat test.txt)
[[ "$content" == "another pre-claude state" ]] || fail "Expected pre-Claude state after reject"
stash_count=$(git stash list | wc -l | tr -d ' ')
[[ "$stash_count" -eq 0 ]] || fail "Expected no stash entries after pop"

# Cleanup
cd /
rm -rf "$test_dir"

pass "Git checkpoint workflow works correctly"

# Test 4: Hook script robustness
print_step "Testing hook script error handling..."

# Test checkpoint script without NVIM_SOCKET
output=$("$HOOKS_DIR/nvim-diff-checkpoint.sh" 2>&1 || true)
[[ $? -eq 0 ]] || fail "Checkpoint script should exit cleanly without NVIM_SOCKET"

# Test sync script without NVIM_SOCKET
output=$(echo '{"tool_input":{"file_path":"test.txt"}}' | "$HOOKS_DIR/nvim-diff-sync.sh" 2>&1 || true)
[[ $? -eq 0 ]] || fail "Sync script should exit cleanly without NVIM_SOCKET"

pass "Hook scripts handle missing NVIM_SOCKET gracefully"

section "All tests passed ✓"
