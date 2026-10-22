#!/usr/bin/env bash
set -euo pipefail

# unit tests for instances/opencode.sh
# static checks on the opencode lister's row format and state rendering,
# mirroring test-list-claude.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIST_OPENCODE_SCRIPT="$SCRIPT_DIR/../instances/opencode.sh"

source "$SCRIPT_DIR/_test-helpers.sh"

section "Script Exists and Is Executable"

if [[ -f "$LIST_OPENCODE_SCRIPT" ]]; then
    pass "opencode.sh exists"
else
    fail "opencode.sh not found at $LIST_OPENCODE_SCRIPT"
    exit 1
fi

if [[ -x "$LIST_OPENCODE_SCRIPT" ]]; then
    pass "opencode.sh is executable"
else
    fail "opencode.sh is not executable"
fi

section "ShellCheck Validation"

if command -v shellcheck &>/dev/null; then
    if shellcheck -x -e SC1091 -e SC2059 -e SC2015 -e SC2016 -e SC2034 "$LIST_OPENCODE_SCRIPT" 2>/dev/null; then
        pass "opencode.sh passes shellcheck"
    else
        fail "opencode.sh has shellcheck warnings"
    fi
else
    skip "shellcheck not installed"
fi

section "Row Format and State"

script_content=$(<"$LIST_OPENCODE_SCRIPT")

if [[ "$script_content" == *'${row}${TAB}${target}'* ]]; then
    pass "Emits tab-delimited display/target rows like claude.sh"
else
    fail "Should emit display<TAB>target rows"
fi

if [[ "$script_content" == *'#{pane_title}"'* ]]; then
    pass "Reads pane_title as the last list-panes field"
else
    fail "Should read pane_title last in the list-panes format"
fi

if [[ "$script_content" == *'"OC | "'* ]]; then
    pass "Labels rows with the session title from the pane title"
else
    fail "Should strip the 'OC | ' pane title prefix for labels"
fi

if [[ "$script_content" == *'agent_state_read opencode'* ]]; then
    pass "Reads opencode records from the agent-state registry"
else
    fail "Should read the agent-state registry via agent_state_read opencode"
fi

if [[ "$script_content" == *'agent_state_row'* ]]; then
    pass "Renders rows via agent_state_row"
else
    fail "Should render rows via agent_state_row"
fi

if [[ "$script_content" == *'agent_state_sweep opencode'* ]]; then
    pass "Sweeps stale state files via agent_state_sweep"
else
    fail "Should sweep stale state files via agent_state_sweep opencode"
fi

if [[ "$script_content" != *'STUCK_SECS'* && "$script_content" != *'agent_state_legend stuck'* ]]; then
    pass "No stuck derivation for opencode"
else
    fail "opencode.sh should not derive or list a stuck state"
fi

print_summary
