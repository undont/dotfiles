#!/usr/bin/env bash
set -euo pipefail

# unit tests for instances/agents.sh
# static checks on the codex/copilot lister's row format, mirroring
# test-list-claude.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIST_AGENTS_SCRIPT="$SCRIPT_DIR/../instances/agents.sh"

source "$SCRIPT_DIR/_test-helpers.sh"

section "Script Exists and Is Executable"

if [[ -f "$LIST_AGENTS_SCRIPT" ]]; then
    pass "agents.sh exists"
else
    fail "agents.sh not found at $LIST_AGENTS_SCRIPT"
    exit 1
fi

if [[ -x "$LIST_AGENTS_SCRIPT" ]]; then
    pass "agents.sh is executable"
else
    fail "agents.sh is not executable"
fi

section "ShellCheck Validation"

if command -v shellcheck &>/dev/null; then
    if shellcheck -x -e SC1091 -e SC2059 -e SC2015 -e SC2016 -e SC2034 "$LIST_AGENTS_SCRIPT" 2>/dev/null; then
        pass "agents.sh passes shellcheck"
    else
        fail "agents.sh has shellcheck warnings"
    fi
else
    skip "shellcheck not installed"
fi

section "Row Format"

script_content=$(<"$LIST_AGENTS_SCRIPT")

if [[ "$script_content" == *'${TAB}${target}")'* ]]; then
    pass "Emits tab-delimited display/target rows like claude.sh"
else
    fail "Should emit display<TAB>target rows"
fi

if [[ "$script_content" == *'usage: agents.sh <codex|copilot>'* ]]; then
    pass "Lists codex and copilot only"
else
    fail "Should list codex and copilot only (opencode has opencode.sh)"
fi

if [[ "$script_content" != *'AGENT_STATE_DIR'* && "$script_content" != *'agent_state_'* ]]; then
    pass "Shows alert icons, not agent state"
else
    fail "Should not read the agent-state registry (state listers are separate)"
fi

print_summary
