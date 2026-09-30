#!/usr/bin/env bash
set -euo pipefail

# runs the lua unit tests; run-tests.sh discovers only test-*.sh files

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/_test-helpers.sh"

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

if "$LUA" "$SCRIPT_DIR/test-colour-utils.lua"; then
    pass "colour-utils.lua tests passed"
else
    fail "colour-utils.lua tests failed"
fi

if "$LUA" "$SCRIPT_DIR/test-generate-theme.lua"; then
    pass "generate-theme.lua tests passed"
else
    fail "generate-theme.lua tests failed"
fi

print_summary
[[ "$FAIL" -eq 0 ]] || exit 1
