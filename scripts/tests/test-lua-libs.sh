#!/usr/bin/env bash
set -euo pipefail

# bash wrapper to run lua unit tests via the test runner
# discovered by run-tests.sh as scripts/tests/test-lua-libs.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/_test-helpers.sh"

# find lua interpreter
find_lua() {
    if command -v luajit >/dev/null 2>&1; then
        echo "luajit"
    elif command -v lua >/dev/null 2>&1; then
        echo "lua"
    else
        return 1
    fi
}

LUA=$(find_lua) || {
    skip "No Lua interpreter found"
    print_summary
    exit 0
}

section "Lua Library Tests (via $LUA)"

# run colour-utils tests
if "$LUA" "$SCRIPT_DIR/test-colour-utils.lua"; then
    pass "colour-utils.lua tests passed"
else
    fail "colour-utils.lua tests failed"
fi

# run generate-theme tests
if "$LUA" "$SCRIPT_DIR/test-generate-theme.lua"; then
    pass "generate-theme.lua tests passed"
else
    fail "generate-theme.lua tests failed"
fi

print_summary
[[ "$FAIL" -eq 0 ]] || exit 1
