#!/usr/bin/env bash
# tests for show-help.sh template rendering
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SHOW_HELP="$SCRIPT_DIR/../utils/show-help.sh"
TEMPLATE="$SCRIPT_DIR/../../tmux-help.template"

source "$SCRIPT_DIR/_test-helpers.sh"

section "show-help.sh existence and syntax"

if [[ -f "$SHOW_HELP" ]]; then
    pass "show-help.sh exists"
else
    fail "show-help.sh not found"
    exit 1
fi

if [[ -x "$SHOW_HELP" ]]; then
    pass "show-help.sh is executable"
else
    fail "show-help.sh is not executable"
fi

assert_success "valid bash syntax" bash -n "$SHOW_HELP"

section "Template file"

if [[ -f "$TEMPLATE" ]]; then
    pass "tmux-help.template exists"
else
    fail "tmux-help.template not found"
    exit 1
fi

# template should contain {{M}} placeholders
if grep -q '{{M}}' "$TEMPLATE"; then
    pass "template contains {{M}} placeholders"
else
    fail "template should contain {{M}} placeholders"
fi

section "Template rendering"

output=$("$SHOW_HELP" 2>/dev/null)

# output should NOT contain any unresolved placeholders
if [[ "$output" != *'{{M}}'* ]]; then
    pass "no unreplaced {{M}} placeholders in output"
else
    fail "output contains unreplaced {{M}} placeholders"
fi

# output should contain the correct modifier key for the platform
if [[ "$(uname)" == "Darwin" ]]; then
    EXPECTED_MOD="Opt"
else
    EXPECTED_MOD="Alt"
fi

if [[ "$output" == *"${EXPECTED_MOD}+"* ]]; then
    pass "output contains '${EXPECTED_MOD}+' (correct for platform)"
else
    fail "output should contain '${EXPECTED_MOD}+' for this platform"
fi

# output should contain key structural elements from the help template
if [[ "$output" == *"TABS"* && "$output" == *"PANES"* ]]; then
    pass "output contains expected help sections"
else
    fail "output should contain TABS and PANES sections"
fi

print_summary
[[ $FAIL -gt 0 ]] && exit 1
exit 0
