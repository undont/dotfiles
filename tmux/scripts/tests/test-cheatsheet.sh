#!/usr/bin/env bash
# tests for cheatsheet.sh rendering and the -N note convention in tmux.conf.template
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CHEATSHEET="$SCRIPT_DIR/../utils/cheatsheet.sh"
TEMPLATE="$SCRIPT_DIR/../../tmux.conf.template"

source "$SCRIPT_DIR/_test-helpers.sh"

eval "$(sed -n '/^render()/,/^}/p' "$CHEATSHEET")"

section "cheatsheet.sh existence and syntax"

if [[ -x "$CHEATSHEET" ]]; then
    pass "cheatsheet.sh is executable"
else
    fail "cheatsheet.sh is missing or not executable"
fi

assert_success "valid bash syntax" bash -n "$CHEATSHEET"

section "render"

rows=$(printf '%s\t%s\t%s\n' \
    prefix j "panes: join marked pane" \
    root M-t "tabs: new window" \
    root C-S-Enter "" \
    prefix d "Detach the current client" \
    copy-mode-vi C-f "scroll: page down" \
    prefix J "tools: jump to a hint")

output=$(printf '%s\n' "$rows" | render Opt | sed $'s/\033\\[[0-9;]*m//g')

assert_equals "rows grouped by note prefix, defaults last" \
    "$(printf '%s\n' \
        $'\tTABS' \
        $'  Opt+t            new window\t' \
        '' \
        $'\tPANES' \
        $'  ` j              join marked pane\t' \
        '' \
        $'\tSCROLL MODE' \
        $'  Ctrl+f           page down\t' \
        '' \
        $'\tPICKERS / TOOLS' \
        $'  ` J              jump to a hint\t' \
        '' \
        $'\tTMUX DEFAULTS' \
        $'  ` d              Detach the current client\t')" \
    "$output"
assert_equals "Alt is used when passed" \
    $'  Alt+t            new window\t' "$(printf '%s\n' "$rows" | render Alt | grep 'new window')"

section "tmux.conf.template notes"

# a bind describes itself with -N, not a trailing comment
trailing=$(grep -nE '^bind(-key)? .*[[:space:]]# ' "$TEMPLATE" || true)
if [[ -z "$trailing" ]]; then
    pass "no bind line carries a trailing description comment"
else
    fail "bind lines with trailing comments (use -N):"$'\n'"$trailing"
fi

print_summary
[[ $FAIL -gt 0 ]] && exit 1
exit 0
