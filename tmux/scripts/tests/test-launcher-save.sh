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
export XDG_CACHE_HOME="$TEST_DIR/cache"

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
    local i k
    for ((i = 0; i < ${#win_names[@]}; i++)); do
        printf '%s|%s|%s|%s' "${win_names[$i]}" "${win_cmds[$i]}" "${win_splits[$i]}" "${win_split_cmds[$i]}"
        if [[ -n "${win_panes[$i]:-}" ]]; then
            printf '|%s|%s' "${win_panes[$i]}" "${win_layouts[$i]//$'\n'/;}"
            for ((k = 1; k <= win_panes[i]; k++)); do
                printf '|%s|%s' "${pane_cmds["$i:$k"]:-}" "${pane_dirs["$i:$k"]:-}"
            done
        fi
        printf '\n'
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

expected_state="code||no||3|1 h 50 2;2 v 50 3|nvim||npm run dev|||
code-2||yes|
agent|claude|no|
logs||no||2|1 v 50 2|less log|||
nvim|nvim|yes|claude
bare|claude -r|no|"
assert_equals "windows map to name|cmd|split|split cmd" "$expected_state" "$(describe_state)"
assert_equals "session, tag and dir are read" "demo||/p" "$cap_session|$cap_tag|$cap_dir"

notes=$(printf '%s\n' "${save_notes[@]}")
for want in "agent window: 'claude --resume abc' → 'claude'" \
    "logs window, top-left: 'less log' is a pager, may not replay well" \
    "nvim window, right pane: 'claude -r abc' → 'claude'"; do
    if [[ "$notes" == *"$want"* ]]; then
        pass "note: $want"
    else
        fail "missing note: $want (got: $notes)"
    fi
done
if [[ "$notes" != *"code-2"* && "$notes" != *"bare"* && "$notes" != *"code window"* ]]; then
    pass "plain layouts get no note"
else
    fail "plain layouts should get no note (got: $notes)"
fi
assert_equals "one note per finding" "3" "${#save_notes[@]}"

# ═══════════════════════════════════════════════════════════════════════════
section "Save as new, then replay"
# ═══════════════════════════════════════════════════════════════════════════

setup_test_server
tmux set-option -g default-shell /bin/sh
# mirror the real config: generated launchers select window 1, pane 1
tmux set-option -g base-index 1
tmux set-option -g pane-base-index 1

# a rich code window (one pane left, two stacked right, one pane in a
# subdirectory) and a simple srv window
mkdir -p "$TEST_DIR/proj/sub"
tmux new-session -d -s orig -n code -c "$TEST_DIR/proj" -x 200 -y 50
tmux split-window -h -t "=orig:code" -c "$TEST_DIR/proj"
tmux split-window -v -t "=orig:code.2" -c "$TEST_DIR/proj/sub"
tmux new-window -t "=orig:" -n srv -c "$TEST_DIR/proj"
tmux send-keys -t "=orig:code.2" 'sleep 300 | cat -u' Enter
printf 'x\n' >"$TEST_DIR/proj/my notes.txt"
tmux send-keys -t "=orig:srv" "tail -f '$TEST_DIR/proj/my notes.txt'" Enter
wait_for_command "=orig:code.2" || fail "pipeline did not start"
wait_for_command "=orig:srv" || fail "srv command did not start"

build_state_from_capture "$("$CAPTURE" orig)"
original_state=$(describe_state)
assert_equals "captures the original session" "code||no||3|1 h 50 2;2 v 48 3|||sleep 300 | cat -u|||sub
srv|tail -f 'my notes.txt'|no|" "$original_state"
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
# the replay runs at the test server's default size, so split percentages
# round differently there; compare the structure with percentages blanked
pct_blanked() { printf '%s\n' "$1" | sed -E 's/ ([hv]) [0-9]+ /\1 N /g'; }
assert_equals "replayed session matches the original (windows, splits, commands)" \
    "$(pct_blanked "$original_state")" "$(pct_blanked "$(describe_state)")"
# …but close to the original's proportions, not just any layout
orig_v=$(printf '%s\n' "$original_state" | sed -n 1p | sed -En 's/.*;2 v ([0-9]+) 3.*/\1/p')
replay_v=$(describe_state | sed -n 1p | sed -En 's/.*;2 v ([0-9]+) 3.*/\1/p')
if [[ -n "$orig_v" && -n "$replay_v" ]] && ((orig_v - replay_v <= 5 && replay_v - orig_v <= 5)); then
    pass "replayed split proportions are close to the original ($orig_v% → $replay_v%)"
else
    fail "replayed proportions should be within a few percent (got $replay_v, was $orig_v)"
fi

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
assert_equals "a tagged hand-written launcher is offered for update" "hand" "$(update_target || true)"

tmux set-option -t "=orig:" @launcher dev
build_state_from_capture "$("$CAPTURE" orig)"
if update_target >/dev/null; then
    fail "a built-in launcher must not be offered for update"
else
    pass "a built-in launcher is not offered for update"
fi

# ═══════════════════════════════════════════════════════════════════════════
section "Worktrees"
# ═══════════════════════════════════════════════════════════════════════════

repo="$TEST_DIR/repo"
wts="$TEST_DIR/repo-wt"
git init -q "$repo"
git -C "$repo" -c user.name=t -c user.email=t@t commit -q --allow-empty -m init
git -C "$repo" worktree add -q "$wts/rp-7-fix" -b rp-7-fix
mkdir -p "$wts/rp-7-fix/src"

tmux new-session -d -s wtsess -n code -c "$wts/rp-7-fix" -x 200 -y 50
tmux split-window -h -t "=wtsess:code" -c "$wts/rp-7-fix/src"
build_state_from_capture "$("$CAPTURE" wtsess)"
assert_equals "pane dirs are relative to the worktree" "code||no||2|1 h 50 2||||src" "$(describe_state)"
write_new_launcher "repo"
assert_equals "a new launcher is rooted at the main checkout" "_REPO_ROOT_DEFAULT=\"$repo\"" \
    "$(grep -m1 '^_REPO_ROOT_DEFAULT=' "$USER_LAUNCHERS/repo")"
assert_equals "worktrees dir is the linked worktrees' parent" "_REPO_WORKTREES_DEFAULT=\"$wts\"" \
    "$(grep -m1 '^_REPO_WORKTREES_DEFAULT=' "$USER_LAUNCHERS/repo")"
if grep -q '^# @instance: prompt' "$USER_LAUNCHERS/repo" && grep -qF '"$WORKTREES_DIR"/rp-"${ticket_num}"-*' "$USER_LAUNCHERS/repo"; then
    pass "instances prompt and open <prefix>-<n>-* worktrees"
else
    fail "a worktree launcher should prompt for instances and glob the worktree prefix"
fi

SESSION_NAME=repo-7 bash "$USER_LAUNCHERS/repo" >/dev/null 2>&1 || true
assert_equals "a numbered instance opens its worktree" "$wts/rp-7-fix/src" \
    "$(tmux display-message -p -t "=repo-7:code.2" '#{pane_current_path}' 2>/dev/null)"
SESSION_NAME=repo-rp-7-fix bash "$USER_LAUNCHERS/repo" >/dev/null 2>&1 || true
assert_equals "a named instance opens the worktree with that name" "$wts/rp-7-fix" \
    "$(tmux display-message -p -t "=repo-rp-7-fix:code.1" '#{pane_current_path}' 2>/dev/null)"
SESSION_NAME=repo bash "$USER_LAUNCHERS/repo" >/dev/null 2>&1 || true
assert_equals "the base session opens the main checkout" "$repo" \
    "$(tmux display-message -p -t "=repo:code.1" '#{pane_current_path}' 2>/dev/null)"

# a hand-written worktree launcher, found by its instance's session name
cat >"$USER_LAUNCHERS/hw" <<EOF
#!/usr/bin/env bash
# @description: Hand-written worktrees
# @instance: prompt
SESSION="\${SESSION_NAME:-hw}"
WORKTREES_DIR="\${HW_WORKTREES:-$wts}"
BASE_DIR="\${HW_ROOT:-\${BASE_DIR:-$repo}}"
PROJECT_DIR="\$BASE_DIR"
if [[ "\$SESSION" =~ -([0-9]+)\$ ]]; then
    ticket_num="\${BASH_REMATCH[1]}"
    for wt in "\$WORKTREES_DIR"/rp-"\${ticket_num}"-*; do
        [[ -d "\$wt" ]] && PROJECT_DIR="\$wt" && break
    done
fi
tmux new-session -d -s "\$SESSION" -n "zsh" -c "\$PROJECT_DIR"
EOF
chmod +x "$USER_LAUNCHERS/hw"
cp "$USER_LAUNCHERS/hw" "$TEST_DIR/hw.before"
tmux rename-session -t "=wtsess" hw-7
build_state_from_capture "$("$CAPTURE" hw-7)"
assert_equals "an untagged instance session finds its launcher by name" "hw" "$(update_target || true)"
update_launcher "hw"
if cmp -s "$TEST_DIR/hw.before" "$LAUNCHER_BACKUPS/hw"; then
    pass "a hand-written launcher is backed up before it's replaced"
else
    fail "a hand-written launcher should be copied to LAUNCHER_BACKUPS"
fi
hw="$USER_LAUNCHERS/hw"
if is_generated_launcher "$hw" && bash -n "$hw" &&
    grep -q '^# @description: Hand-written worktrees' "$hw" && grep -q '^# @instance: prompt' "$hw" &&
    grep -q "^_HW_ROOT_DEFAULT=\"$repo\"" "$hw" && grep -q "^_HW_WORKTREES_DEFAULT=\"$wts\"" "$hw" &&
    grep -qF '"$WORKTREES_DIR"/rp-"${ticket_num}"-*' "$hw"; then
    pass "the rewrite keeps description, instances, dirs and worktree prefix"
else
    fail "the rewrite should carry over the hand-written launcher's settings"
fi
if grep -qF -- '-c "$PROJECT_DIR/src"' "$hw"; then
    pass "pane dirs stay relative to the worktree"
else
    fail "pane dirs should be relative to the worktree, not absolute"
fi

help=$(bash "$USER_LAUNCHERS/repo" --help)
if [[ "$help" == *"repo-<n> opens the worktree rp-<n>-*"* && "$help" == *"REPO_WORKTREES    worktrees directory"* &&
    "$help" == *"REPO_ROOT    project directory"* ]]; then
    pass "--help describes worktree instances and the env overrides"
else
    fail "--help should describe worktree instances and the env overrides (got: $help)"
fi

# ═══════════════════════════════════════════════════════════════════════════
section "Auto-named windows"
# ═══════════════════════════════════════════════════════════════════════════

tmux new-session -d -s autos -n pinned -c "$TEST_DIR/proj" -x 200 -y 50
tmux new-window -t "=autos:" -c "$TEST_DIR/proj"
build_state_from_capture "$("$CAPTURE" autos)"
assert_equals "only the unnamed window is auto-named" " 1" "${win_autonames[*]}"
write_new_launcher "autos"
auto_lines=$(grep -c 'automatic-rename on' "$USER_LAUNCHERS/autos" || true)
last_target=$(grep -n -- '-t "$SESSION:' "$USER_LAUNCHERS/autos" | grep -v 'automatic-rename\|select-' | tail -1 | cut -d: -f1)
first_rename=$(grep -n 'automatic-rename on' "$USER_LAUNCHERS/autos" | head -1 | cut -d: -f1)
if [[ "$auto_lines" == 1 && -n "$first_rename" && "$first_rename" -gt "${last_target:-0}" ]]; then
    pass "renaming is handed back after every name-targeted line"
else
    fail "automatic-rename should be set once, after the windows are built"
fi
(
    load_existing_launcher "$USER_LAUNCHERS/autos"
    assert_equals "auto-named windows survive a load" " 1" "${win_autonames[*]}"
)
SESSION_NAME=autos2 bash "$USER_LAUNCHERS/autos" >/dev/null 2>&1 || true
assert_equals "replay renames only the auto-named window" "0 1" \
    "$(tmux list-windows -t "=autos2" -F '#{automatic-rename}' 2>/dev/null | tr '\n' ' ' | sed 's/ $//')"

cleanup_test_server

print_summary
[[ $FAIL -eq 0 ]]
