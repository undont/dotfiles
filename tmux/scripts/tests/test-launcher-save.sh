#!/usr/bin/env bash
# test suite for launchers/save.sh
# maps captured sessions onto launchers, then replays the saved launcher on the
# isolated test server and checks the session it builds

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/_test-helpers.sh"

TEST_DIR="$(mktemp -d)"
TEST_DIR="$(cd "$TEST_DIR" && pwd -P)"
mkdir -p "$TEST_DIR/proj" "$TEST_DIR/config"
# USER_LAUNCHERS (common.sh) is derived from XDG_CONFIG_HOME at source time
export XDG_CONFIG_HOME="$TEST_DIR/config"

CAPTURE="$SCRIPT_DIR/../launchers/capture.sh"
# shellcheck source=tmux/scripts/launchers/save.sh
source "$SCRIPT_DIR/../launchers/save.sh"

# shellcheck disable=SC2329  # Called indirectly via trap
_cleanup_save_tests() {
    cleanup_test_server
    rm -rf "$TEST_DIR"
}
trap _cleanup_save_tests EXIT INT TERM

# poll until a pane runs something other than the idle shell
wait_for_command() {
    local target="$1" i
    for ((i = 0; i < 50; i++)); do
        [[ "$(tmux display-message -p -t "$target" '#{pane_current_command}' 2>/dev/null)" != "sh" ]] && return 0
        sleep 0.1
    done
    return 1
}

# window name / first-pane command / split / split command, one line per window
describe_state() {
    local i
    for ((i = 0; i < ${#win_names[@]}; i++)); do
        printf '%s|%s|%s|%s\n' "${win_names[$i]}" "${win_cmds[$i]}" "${win_splits[$i]}" "${win_split_cmds[$i]}"
    done
}

echo ""
echo "${CYAN}═══════════════════════════════════════════${NC}"
echo "${CYAN}  Launcher Save Tests${NC}"
echo "${CYAN}═══════════════════════════════════════════${NC}"
echo ""

# ═══════════════════════════════════════════════════════════════════════════
section "Helpers"
# ═══════════════════════════════════════════════════════════════════════════

assert_equals "--resume <id> is dropped" "claude" "$(strip_resume_args "claude --resume abc")"
assert_equals "-r <id> is dropped, other flags kept" "claude --model opus" "$(strip_resume_args "claude -r abc --model opus")"
assert_equals "a bare --resume is kept (opens the resume picker)" "claude --resume --model opus" "$(strip_resume_args "claude --resume --model opus")"
assert_equals "a bare -r at the end is kept" "claude -r" "$(strip_resume_args "claude -r")"
assert_equals "--resume=<id> is dropped" "codex" "$(strip_resume_args "codex --resume=xyz")"
assert_equals "--continue is kept" "claude --continue" "$(strip_resume_args "claude --continue")"
assert_equals "other programs are untouched" "npm run -r x" "$(strip_resume_args "npm run -r x")"

assert_equals "dots become dashes (not a pane target)" "2-1-308" "$(sanitise_window_name "2.1.308")"
assert_equals "all-digit names get a prefix (not an index)" "w12" "$(sanitise_window_name "12")"
assert_equals "spaces and colons become dashes" "a-b-c" "$(sanitise_window_name "a b:c")"
assert_equals "empty names get a placeholder" "window" "$(sanitise_window_name "")"

assert_equals "\$HOME maps to the generator form" "\$HOME" "$(generator_path "$HOME")"
assert_equals "paths under \$HOME map to \$HOME/..." "\$HOME/src/x" "$(generator_path "$HOME/src/x")"
# shellcheck disable=SC2088  # a literal ~ is the input under test
assert_equals "~ paths map to \$HOME/..." "\$HOME/src/x" "$(generator_path "~/src/x")"
assert_equals "paths outside \$HOME are kept" "/opt/x" "$(generator_path "/opt/x")"

# ═══════════════════════════════════════════════════════════════════════════
section "Mapping captured rows"
# ═══════════════════════════════════════════════════════════════════════════

rows=$'session\tdemo\nlauncher\t\ndir\t/p\n'
# a 200x50 window per layout: pane rows are window, pane, left, top, width,
# height, cwd, cmd, note
rows+=$'window\t1\tcode\t3\nwindow\t2\tcode\t2\nwindow\t3\tagent\t1\nwindow\t4\tlogs\t2\n'
rows+=$'pane\t1\t1\t0\t0\t99\t50\t/p\tnvim\t\npane\t1\t2\t100\t0\t100\t24\t/p\tnpm run dev\t\n'
rows+=$'pane\t1\t3\t100\t25\t100\t25\t/p\t\t\n'
rows+=$'pane\t2\t1\t0\t0\t99\t50\t/p\t\t\npane\t2\t2\t100\t0\t100\t50\t/p\t\t\n'
rows+=$'pane\t3\t1\t0\t0\t200\t50\t/p\tclaude --resume abc\tresumes a specific session\n'
rows+=$'pane\t4\t1\t0\t0\t200\t24\t/p\tless log\tpager\npane\t4\t2\t0\t25\t200\t25\t/p\t\t\n'
rows+=$'window\t5\tnvim\t2\nwindow\t6\tbare\t1\n'
rows+=$'pane\t5\t1\t0\t0\t99\t50\t/p\tnvim\t\n'
rows+=$'pane\t5\t2\t100\t0\t100\t50\t/p\tclaude -r abc\tresumes a specific session\n'
rows+=$'pane\t6\t1\t0\t0\t200\t50\t/p\tclaude -r\t\n'
build_state_from_capture "$rows"

expected_state="code|nvim|yes|npm run dev
code-2||yes|
agent|claude|no|
logs|less log|yes|
nvim|nvim|yes|claude
bare|claude -r|no|"
assert_equals "windows map to name|cmd|split|split cmd" "$expected_state" "$(describe_state)"
assert_equals "session, tag and dir are read" "demo||/p" "$cap_session|$cap_tag|$cap_dir"

notes=$(printf '%s\n' "${save_notes[@]}")
for want in "code window: 3 panes, saving the first 2 side by side" \
    "agent window: 'claude --resume abc' → 'claude'" \
    "logs window, top pane: 'less log' is a pager, may not replay well" \
    "logs window: stacked split, saving it side by side" \
    "nvim window, right pane: 'claude -r abc' → 'claude'"; do
    if [[ "$notes" == *"$want"* ]]; then
        pass "note: $want"
    else
        fail "missing note: $want (got: $notes)"
    fi
done
if [[ "$notes" != *"code-2"* && "$notes" != *"bare"* ]]; then
    pass "a plain split and a bare claude -r get no note"
else
    fail "a plain split and a bare claude -r should get no note (got: $notes)"
fi
assert_equals "one note per finding" "5" "${#save_notes[@]}"

# ═══════════════════════════════════════════════════════════════════════════
section "Save as new, then replay"
# ═══════════════════════════════════════════════════════════════════════════

setup_test_server
tmux set-option -g default-shell /bin/sh
# mirror the real config: generated launchers select window 1, pane 1
tmux set-option -g base-index 1
tmux set-option -g pane-base-index 1

tmux new-session -d -s orig -n code -c "$TEST_DIR/proj" -x 200 -y 50
tmux split-window -h -t "=orig:code" -c "$TEST_DIR/proj"
tmux new-window -t "=orig:" -n srv -c "$TEST_DIR/proj"
tmux send-keys -t "=orig:code.2" 'sleep 300 | cat -u' Enter
printf 'x\n' >"$TEST_DIR/proj/my notes.txt"
tmux send-keys -t "=orig:srv" "tail -f '$TEST_DIR/proj/my notes.txt'" Enter
wait_for_command "=orig:code.2" || fail "pipeline did not start"
wait_for_command "=orig:srv" || fail "srv command did not start"

build_state_from_capture "$("$CAPTURE" orig)"
original_state=$(describe_state)
assert_equals "captures the original session" "code||yes|sleep 300 | cat -u
srv|tail -f '$TEST_DIR/proj/my notes.txt'|no|" "$original_state"
write_new_launcher "saved"
saved="$USER_LAUNCHERS/saved"

if [[ -x "$saved" ]] && bash -n "$saved"; then
    pass "writes an executable, valid launcher"
else
    fail "should write an executable, valid launcher"
fi
if is_generated_launcher "$saved"; then
    pass "saved launcher carries the @generated marker"
else
    fail "saved launcher should carry the @generated marker"
fi
assert_equals "description names the source session" "# @description: Saved from the 'orig' session" \
    "$(grep -m1 '^# @description:' "$saved")"
assert_equals "project dir is the session's dir" "_SAVED_ROOT_DEFAULT=\"$TEST_DIR/proj\"" \
    "$(grep -m1 '^_SAVED_ROOT_DEFAULT=' "$saved")"

# the launcher attaches at the end, which fails without a terminal; the session
# is built before that
SESSION_NAME=replay bash "$saved" >/dev/null 2>&1 || true
if tmux has-session -t "=replay" 2>/dev/null; then
    pass "saved launcher builds a session"
else
    fail "saved launcher should build a session"
fi
assert_equals "replayed session is tagged with the launcher" "saved" \
    "$(tmux show-options -qv -t "=replay:" @launcher)"
wait_for_command "=replay:code.2" || true
wait_for_command "=replay:srv" || true
build_state_from_capture "$("$CAPTURE" replay)"
assert_equals "replayed session matches the original (windows, splits, commands)" \
    "$original_state" "$(describe_state)"

# ═══════════════════════════════════════════════════════════════════════════
section "Update in place"
# ═══════════════════════════════════════════════════════════════════════════

# a wizard launcher with settings the session can't know about
(
    name="proj"
    description="Original description"
    instance_mode="y"
    project_dir="\$HOME/src/proj"
    worktree_aware="y"
    worktrees_dir="\$HOME/src/proj-worktrees"
    win_names=(old)
    win_cmds=(top)
    win_splits=(no)
    win_split_cmds=("")
    generate_launcher >"$USER_LAUNCHERS/proj"
)
printf '#!/usr/bin/env bash\n# @description: hand-written\n' >"$USER_LAUNCHERS/hand"

tmux set-option -t "=orig:" @launcher proj
build_state_from_capture "$("$CAPTURE" orig)"
assert_equals "a tagged session can update its generated launcher" "proj" "$(update_target || true)"

update_launcher "proj"
updated="$USER_LAUNCHERS/proj"
assert_equals "update keeps the description" "# @description: Original description" \
    "$(grep -m1 '^# @description:' "$updated")"
if grep -q '^# @instance: prompt' "$updated" && grep -q '^_PROJ_WORKTREES_DEFAULT="$HOME/src/proj-worktrees"' "$updated" &&
    grep -q '^_PROJ_ROOT_DEFAULT="$HOME/src/proj"' "$updated"; then
    pass "update keeps instance mode, worktrees and project dir"
else
    fail "update should keep instance mode, worktrees and project dir"
fi
if grep -q -- '-n "code"' "$updated" && grep -q -- '-n "srv"' "$updated" && ! grep -q -- '-n "old"' "$updated"; then
    pass "update replaces the windows"
else
    fail "update should replace the windows with the session's"
fi
if bash -n "$updated"; then
    pass "updated launcher is valid bash"
else
    fail "updated launcher has a syntax error"
fi

# no worktrees: load_existing_launcher used to leave worktrees_dir unset, which
# killed the update under set -u
(
    name="plain"
    description="Plain launcher"
    instance_mode="n"
    project_dir="\$HOME/src/plain"
    worktree_aware="n"
    worktrees_dir=""
    win_names=(old)
    win_cmds=("")
    win_splits=(no)
    win_split_cmds=("")
    generate_launcher >"$USER_LAUNCHERS/plain"
)
if (
    unset worktrees_dir
    update_launcher "plain"
) 2>/dev/null && grep -q -- '-n "srv"' "$USER_LAUNCHERS/plain"; then
    pass "updates a launcher without worktree settings"
else
    fail "should update a launcher without worktree settings"
fi

# a failed capture (session gone) leaves no windows: neither path may write
cp "$USER_LAUNCHERS/plain" "$TEST_DIR/plain.before"
build_state_from_capture ""
if ! update_launcher "plain" && ! write_new_launcher "empty" &&
    cmp -s "$TEST_DIR/plain.before" "$USER_LAUNCHERS/plain" && [[ ! -e "$USER_LAUNCHERS/empty" ]]; then
    pass "an empty capture writes nothing"
else
    fail "an empty capture must not write or overwrite a launcher"
fi

tmux set-option -t "=orig:" @launcher hand
build_state_from_capture "$("$CAPTURE" orig)"
if update_target >/dev/null; then
    fail "a hand-written launcher must not be offered for update"
else
    pass "a hand-written launcher is not offered for update"
fi

tmux set-option -t "=orig:" @launcher dev
build_state_from_capture "$("$CAPTURE" orig)"
if update_target >/dev/null; then
    fail "a built-in launcher must not be offered for update"
else
    pass "a built-in launcher is not offered for update"
fi

cleanup_test_server

print_summary
[[ $FAIL -eq 0 ]]
