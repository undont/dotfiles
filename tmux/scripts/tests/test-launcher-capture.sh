#!/usr/bin/env bash
# test suite for launchers/capture.sh
# reads a live session on the isolated test server and checks the rows it prints

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/_test-helpers.sh"
CAPTURE="$SCRIPT_DIR/../launchers/capture.sh"
# shellcheck source=tmux/scripts/launchers/capture.sh
source "$CAPTURE"

TEST_DIR="$(mktemp -d)"
TEST_DIR="$(cd "$TEST_DIR" && pwd -P)"
mkdir -p "$TEST_DIR/proj/sub"

# shellcheck disable=SC2329  # Called indirectly via trap
_cleanup_capture_tests() {
    cleanup_test_server
    rm -rf "$TEST_DIR"
}
trap _cleanup_capture_tests EXIT INT TERM

# field N (1-based) of the first row whose leading fields match the given prefix
# usage: row_field "$output" $'pane\t0\t1' 7
row_field() {
    printf '%s\n' "$1" | awk -F'\t' -v prefix="$2" -v n="$3" \
        'index($0, prefix "\t") == 1 { print $n; exit }'
}

# processes start asynchronously after send-keys; poll until the pane's
# foreground command changes from the idle shell
wait_for_command() {
    local target="$1" i
    for ((i = 0; i < 50; i++)); do
        [[ "$(tmux display-message -p -t "$target" '#{pane_current_command}')" != "sh" ]] && return 0
        sleep 0.1
    done
    return 1
}

echo ""
echo "${CYAN}═══════════════════════════════════════════${NC}"
echo "${CYAN}  Launcher Capture Tests${NC}"
echo "${CYAN}═══════════════════════════════════════════${NC}"
echo ""

# ═══════════════════════════════════════════════════════════════════════════
section "Helpers: idle shell detection"
# ═══════════════════════════════════════════════════════════════════════════

for s in zsh -zsh bash /bin/sh -sh fish; do
    if is_shell "$s"; then pass "'$s' is an idle shell"; else fail "'$s' should be an idle shell"; fi
done
for s in "bash -c sleep 1" "zsh script.zsh" nvim "npm run dev"; do
    if is_shell "$s"; then fail "'$s' should be a command"; else pass "'$s' is a command"; fi
done

# ═══════════════════════════════════════════════════════════════════════════
section "Helpers: replay notes"
# ═══════════════════════════════════════════════════════════════════════════

assert_equals "ssh is flagged" "remote session" "$(replay_note "ssh host")"
assert_equals "less via full path is flagged" "pager" "$(replay_note "/usr/bin/less file")"
assert_equals "sudo is flagged" "needs a password" "$(replay_note "sudo make install")"
assert_equals "claude --resume is flagged" "resumes a specific session" "$(replay_note "claude --resume abc")"
assert_equals "codex --resume= is flagged" "resumes a specific session" "$(replay_note "codex --resume=abc")"
assert_equals "claude -r is flagged" "resumes a specific session" "$(replay_note "claude -r abc")"
assert_equals "plain claude is not flagged" "" "$(replay_note "claude")"
assert_equals "claude --continue is not flagged" "" "$(replay_note "claude --continue")"
assert_equals "nvim is not flagged" "" "$(replay_note "nvim")"

# ═══════════════════════════════════════════════════════════════════════════
section "Session capture"
# ═══════════════════════════════════════════════════════════════════════════

setup_test_server
tmux set-option -g default-shell /bin/sh

# window "code": two panes side by side, the right one running a pipeline
# window "srv":  one pane in a subdirectory running a parent with a child process
tmux new-session -d -s cap -n code -c "$TEST_DIR/proj" -x 200 -y 50
tmux split-window -h -t "=cap:code" -c "$TEST_DIR/proj"
tmux new-window -t "=cap:" -n srv -c "$TEST_DIR/proj/sub"
tmux send-keys -t "=cap:code.1" 'sleep 300 | cat -u' Enter
tmux send-keys -t "=cap:srv" "sh -c 'sleep 301; :'" Enter
wait_for_command "=cap:code.1" || fail "pipeline did not start"
wait_for_command "=cap:srv" || fail "child-process command did not start"

out=$("$CAPTURE" cap)
code_idx=$(tmux display-message -p -t "=cap:code" '#{window_index}')
srv_idx=$(tmux display-message -p -t "=cap:srv" '#{window_index}')
left_pane=$(tmux display-message -p -t "=cap:code.0" '#{pane_index}' 2>/dev/null || echo 0)

assert_equals "session row names the session" "cap" "$(row_field "$out" "session" 2)"
assert_equals "untagged session has an empty launcher row" "" "$(row_field "$out" "launcher" 2)"
assert_equals "dir is the most common pane cwd" "$TEST_DIR/proj" "$(row_field "$out" "dir" 2)"

assert_equals "window row carries the name" "code" "$(row_field "$out" $'window\t'"$code_idx" 3)"
assert_equals "window row carries the pane count" "2" "$(row_field "$out" $'window\t'"$code_idx" 4)"
if [[ -n "$(row_field "$out" $'window\t'"$code_idx" 5)" ]]; then
    pass "window row carries the layout"
else
    fail "window row should carry the layout"
fi

pane_rows=$(printf '%s\n' "$out" | grep -c '^pane' || true)
assert_equals "one pane row per pane" "3" "$pane_rows"

assert_equals "idle shell pane has no command" "" "$(row_field "$out" $'pane\t'"$code_idx"$'\t'"$left_pane" 7)"
assert_equals "pipeline is rebuilt from its stages" "sleep 300 | cat -u" "$(row_field "$out" $'pane\t'"$code_idx"$'\t'"$((left_pane + 1))" 7)"
assert_equals "left pane is at x=0" "0" "$(row_field "$out" $'pane\t'"$code_idx"$'\t'"$left_pane" 4)"
if [[ "$(row_field "$out" $'pane\t'"$code_idx"$'\t'"$((left_pane + 1))" 4)" -gt 0 ]]; then
    pass "right pane has a positive x offset"
else
    fail "right pane should have a positive x offset"
fi

assert_equals "child processes of the foreground job are left out" "sh -c sleep 301; :" "$(row_field "$out" $'pane\t'"$srv_idx"$'\t'"$left_pane" 7)"
assert_equals "pane row carries its own cwd" "$TEST_DIR/proj/sub" "$(row_field "$out" $'pane\t'"$srv_idx"$'\t'"$left_pane" 6)"

# ═══════════════════════════════════════════════════════════════════════════
section "Session capture: tag and tie-break"
# ═══════════════════════════════════════════════════════════════════════════

# two panes, one cwd each: the tie goes to the earliest pane
tmux new-session -d -s tie -c "$TEST_DIR/proj/sub"
tmux split-window -t "=tie:" -c "$TEST_DIR/proj"
tmux set-option -t "=tie:" @launcher tie-launcher

out=$("$CAPTURE" tie)
assert_equals "launcher row reads the @launcher tag" "tie-launcher" "$(row_field "$out" "launcher" 2)"
assert_equals "dir tie goes to the earliest pane" "$TEST_DIR/proj/sub" "$(row_field "$out" "dir" 2)"

# exact-match: "ca" must not prefix-match the "cap" session
if "$CAPTURE" ca >/dev/null 2>&1; then
    fail "unknown session should fail, not prefix-match"
else
    pass "unknown session exits non-zero (no prefix match)"
fi

cleanup_test_server

print_summary
[[ $FAIL -eq 0 ]]
