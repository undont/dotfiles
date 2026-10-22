#!/usr/bin/env bash
# test suite for _lib/layout.sh
# checks the split steps for known layouts, then replays them on the isolated
# test server and compares the panes tmux builds with the originals

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/_test-helpers.sh"
source "$SCRIPT_DIR/../_lib/common.sh"
# shellcheck source=tmux/scripts/_lib/layout.sh
source "$SCRIPT_DIR/../_lib/layout.sh"

# shellcheck disable=SC2329  # Called indirectly via trap
_cleanup_layout_tests() {
    cleanup_test_server
}
trap _cleanup_layout_tests EXIT INT TERM

# layouts as "<id> <left> <top> <width> <height>" lines, all in a 200x50 window
SINGLE="1 0 0 200 50"
TWO_H=$'1 0 0 100 50\n2 101 0 99 50'
TWO_V=$'1 0 0 200 24\n2 0 25 200 25'
UNEVEN=$'1 0 0 60 50\n2 61 0 139 50'
THREE_H=$'1 0 0 66 50\n2 67 0 66 50\n3 134 0 66 50'
# one pane on the left, two stacked on the right
LEFT_STACK=$'1 0 0 60 50\n2 61 0 139 25\n3 61 26 139 24'
GRID=$'1 0 0 100 24\n2 101 0 99 24\n3 0 25 100 25\n4 101 25 99 25'
# a stack whose bottom row is split again: v[1, h[2, v[3, 4]]]
NESTED=$'1 0 0 200 20\n2 0 21 80 29\n3 81 21 119 14\n4 81 36 119 14'
# not a tmux layout: pane 4 floats in the middle of the others
BROKEN=$'1 0 0 100 30\n2 101 0 99 50\n3 0 31 100 19\n4 50 10 20 10'

splits() { printf '%s\n' "$1" | layout_splits; }

# build a layout on the test server from its split steps and print the panes
# tmux made, as layout lines, with ids mapped back to the input's
# usage: replay NAME WIDTH HEIGHT LAYOUT
replay() {
    local session="$1" width="$2" height="$3" layout="$4"
    local first holder dir pct new
    local -A pane_of=()
    first=$(printf '%s\n' "$layout" | awk 'NR == 1 || $3 < t || ($3 == t && $2 < l) { t = $3; l = $2; id = $1 } END { print id }')
    tmux new-session -d -s "$session" -x "$width" -y "$height"
    pane_of[$first]=$(tmux display-message -p -t "=$session:" '#{pane_id}')
    while read -r holder dir pct new; do
        [[ -n "$holder" ]] || continue
        pane_of[$new]=$(tmux split-window -d -t "${pane_of[$holder]}" "-$dir" -l "$pct%" -P -F '#{pane_id}')
    done < <(splits "$layout")
    local id
    for id in "${!pane_of[@]}"; do
        tmux display-message -p -t "${pane_of[$id]}" "$id #{pane_left} #{pane_top} #{pane_width} #{pane_height}"
    done | sort -n
    tmux kill-session -t "=$session"
}

# every value within TOLERANCE of the original, line by line
# usage: geometry_close ORIGINAL REPLAYED TOLERANCE
geometry_close() {
    paste -d' ' <(printf '%s\n' "$1" | sort -n) <(printf '%s\n' "$2") | awk -v tol="$3" '
        { for (i = 2; i <= 5; i++) { d = $i - $(i + 5); if (d < 0) d = -d; if (d > tol) bad = 1 }
          if ($1 != $6) bad = 1 }
        END { exit bad }'
}

# same split structure and ids, percentages within TOLERANCE
# usage: splits_close SPLITS_A SPLITS_B TOLERANCE
splits_close() {
    [[ $(printf '%s\n' "$1" | wc -l) -eq $(printf '%s\n' "$2" | wc -l) ]] || return 1
    paste -d' ' <(printf '%s\n' "$1") <(printf '%s\n' "$2") | awk -v tol="$3" '
        { d = $3 - $7; if (d < 0) d = -d
          if ($1 != $5 || $2 != $6 || $4 != $8 || d > tol) bad = 1 }
        END { exit bad }'
}

echo ""
echo "${CYAN}═══════════════════════════════════════════${NC}"
echo "${CYAN}  Layout Tests${NC}"
echo "${CYAN}═══════════════════════════════════════════${NC}"
echo ""

# ═══════════════════════════════════════════════════════════════════════════
section "Split steps"
# ═══════════════════════════════════════════════════════════════════════════

assert_equals "a single pane needs no splits" "" "$(splits "$SINGLE")"
assert_equals "two side by side" "1 h 50 2" "$(splits "$TWO_H")"
assert_equals "two stacked" "1 v 50 2" "$(splits "$TWO_V")"
assert_equals "uneven widths keep their proportion" "1 h 70 2" "$(splits "$UNEVEN")"
assert_equals "three in a row" $'1 h 67 2\n2 h 50 3' "$(splits "$THREE_H")"
assert_equals "one left, two stacked right" $'1 h 70 2\n2 v 48 3' "$(splits "$LEFT_STACK")"
assert_equals "2x2 grid" $'1 h 50 2\n1 v 50 3\n2 v 50 4' "$(splits "$GRID")"
assert_equals "nested stack and split" $'1 v 58 2\n2 h 60 3\n3 v 48 4' "$(splits "$NESTED")"

shuffled=$(printf '%s\n' "$LEFT_STACK" | sort -r)
assert_equals "input order doesn't matter" $'1 h 70 2\n2 v 48 3' "$(splits "$shuffled")"

if printf '%s\n' "$BROKEN" | layout_splits >/dev/null; then
    fail "a layout tmux can't build should be rejected"
else
    pass "a layout tmux can't build is rejected"
fi

# ═══════════════════════════════════════════════════════════════════════════
section "Replay on tmux"
# ═══════════════════════════════════════════════════════════════════════════

setup_test_server

i=0
for name in SINGLE TWO_H TWO_V UNEVEN THREE_H LEFT_STACK GRID NESTED; do
    layout="${!name}"
    i=$((i + 1))

    # same window size: the panes come back where they were
    replayed=$(replay "same$i" 200 50 "$layout")
    if geometry_close "$layout" "$replayed" 2; then
        pass "$name rebuilds at the same size"
    else
        fail "$name should rebuild at the same size (got: $(printf '%s' "$replayed" | tr '\n' ';'))"
    fi

    # smaller window: same structure, same proportions
    replayed=$(replay "small$i" 120 30 "$layout")
    if splits_close "$(splits "$layout")" "$(splits "$replayed")" 3; then
        pass "$name keeps its proportions in a smaller window"
    else
        fail "$name should keep its proportions at 120x30 (got: $(splits "$replayed" | tr '\n' ';'))"
    fi
done

cleanup_test_server

print_summary
[[ $FAIL -eq 0 ]]
