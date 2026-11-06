#!/usr/bin/env bash
# test suite for launchers/save.sh
# maps captured sessions onto launchers, then replays the saved launcher on the
# isolated test server and checks the session it builds

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=tmux/scripts/tests/_test-helpers.sh
source "$SCRIPT_DIR/../../tmux/scripts/tests/_test-helpers.sh"

TEST_DIR="$(mktemp -d)"
TEST_DIR="$(cd "$TEST_DIR" && pwd -P)"
mkdir -p "$TEST_DIR/proj" "$TEST_DIR/config"
# USER_LAUNCHERS (common.sh) is derived from XDG_CONFIG_HOME at source time
export XDG_CONFIG_HOME="$TEST_DIR/config"
export XDG_CACHE_HOME="$TEST_DIR/cache"

CAPTURE="$SCRIPT_DIR/../bin/capture.sh"
# shellcheck source=launchers/bin/save.sh
source "$SCRIPT_DIR/../bin/save.sh"
# shellcheck source=launchers/lib/tmux.sh
source "$SCRIPT_DIR/../lib/tmux.sh"

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

# build a saved launcher on the test server. there's no client to switch to,
# so the session is built and left detached
# usage: replay NAME [SESSION_NAME]
replay() {
    (
        export SESSION_NAME="${2:-}"
        # shellcheck disable=SC2329  # replaces the backend's client switch
        tmux_focus_session() { :; }
        tmux_launch "$(launcher_resolve "$USER_LAUNCHERS/$1.toml")"
    ) >/dev/null 2>&1 || true
}

# a jq test against a launcher file
# usage: toml_has FILE FILTER [JQ_ARGS...]
toml_has() {
    local file="$1" filter="$2"
    shift 2
    yq -p toml -o json -I0 "$file" 2>/dev/null | jq -e "$@" "$filter" >/dev/null 2>&1
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

# a broken user launcher doesn't stop save finding the session's launcher
match_dir=$(mktemp -d)
printf '%s\n' 'description = "x"' 'session = "acme"' '[[window]]' >"$match_dir/acme.toml"
printf '%s\n' 'description = "x"' 'session = "acme-web"' '[[window]]' >"$match_dir/acme-web.toml"
printf 'not = [toml\n' >"$match_dir/broken.toml"
assert_equals "an instance session matches its launcher past a broken file" "acme" \
    "$(USER_LAUNCHERS="$match_dir" cap_tag="" cap_session="acme-12" session_launcher)"
assert_equals "the longest base session wins" "acme-web" \
    "$(USER_LAUNCHERS="$match_dir" cap_tag="" cap_session="acme-web-2" session_launcher)"
rm -rf "$match_dir"

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
assert_equals "no active row leaves the first window and pane" "0 1" "$focus_window $focus_pane"

build_state_from_capture "$rows"$'active\t5\t2\n'
assert_equals "the active pane becomes the focus, by window index and creation rank" "4 2" \
    "$focus_window $focus_pane"
build_state_from_capture "$rows"$'active\t1\t3\n'
assert_equals "a pane created by a later split keeps its creation rank" "0 3" "$focus_window $focus_pane"


# rex prints its split tree as split rows; pane rectangles are then 0 0 0 0
rex_rows=$'session\tdemo\nlauncher\t\ndir\t/p\nactive\t1\t3\nwindow\t1\tdev\t3\t0\n'
rex_rows+=$'pane\t1\t1\t0\t0\t0\t0\t/p\tnvim\t\npane\t1\t2\t0\t0\t0\t0\t/p\tmake dev\t\n'
rex_rows+=$'pane\t1\t3\t0\t0\t0\t0\t/p\t\t\n'
rex_rows+=$'split\t1\t1\th\t30\t2\nsplit\t1\t2\tv\t40\t3\n'
build_state_from_capture "$rex_rows"
assert_equals "split rows are the window's steps" $'1 h 30 2\n2 v 40 3' "${win_layouts[0]}"
assert_equals "every pane is kept" "3" "${win_panes[0]}"
assert_equals "pane commands follow the steps' numbering" "make dev" "${pane_cmds["0:2"]:-}"
assert_equals "the active pane is the focus" "0 3" "$focus_window $focus_pane"

# ═══════════════════════════════════════════════════════════════════════════
section "Save as new, then replay"
# ═══════════════════════════════════════════════════════════════════════════

setup_test_server
tmux set-option -g default-shell /bin/sh
# mirror the real config
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
saved="$USER_LAUNCHERS/saved.toml"

if [[ -f "$saved" && -z "$(launcher_problems "$(launcher_json "$saved")")" ]]; then
    pass "writes a launcher that passes the schema"
else
    fail "should write a launcher that passes the schema"
fi
if toml_has "$saved" '.description == "Saved from the '"'orig'"' session"'; then
    pass "description names the source session"
else
    fail "description should name the source session"
fi
if toml_has "$saved" '.root == $r and (has("root_env") | not)' --arg r "$TEST_DIR/proj"; then
    pass "root is the session's dir, with no env override"
else
    fail "root should be the session's dir, with no root_env"
fi

if toml_has "$saved" '.window[1].focus == true and ([.. | objects | select(has("focus"))] | length) == 1'; then
    pass "the session's active window (srv, first pane) is the one focus"
else
    fail "the saved launcher should focus the srv window and nothing else"
fi

replay saved replay
assert_equals "the replayed session opens on the focused window" "srv" \
    "$(tmux display-message -p -t "=replay:" '#{window_name}')"
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
    write_launcher "$USER_LAUNCHERS/proj.toml"
)
# a hand-written one, with comments
cat >"$USER_LAUNCHERS/hand.toml" <<'EOF'
# notes on this launcher
description = "hand-written" # shown in the picker
session = "hand"

[[window]]
name = "old"
EOF

tmux set-option -t "=orig:" @launcher proj
build_state_from_capture "$("$CAPTURE" orig)"
assert_equals "a tagged session can update its launcher" "proj" "$(update_target || true)"

cp "$USER_LAUNCHERS/proj.toml" "$TEST_DIR/proj.before"
update_launcher "proj"
if cmp -s "$TEST_DIR/proj.before" "$LAUNCHER_BACKUPS/proj.toml"; then
    pass "a launcher is backed up before it's replaced"
else
    fail "a launcher should be copied to LAUNCHER_BACKUPS"
fi
updated="$USER_LAUNCHERS/proj.toml"
if toml_has "$updated" '.description == "Original description"'; then
    pass "update keeps the description"
else
    fail "update should keep the description"
fi
# shellcheck disable=SC2016 # jq source
if toml_has "$updated" '.instance == "prompt" and .worktrees.dir == "~/src/proj-worktrees" and .root == "~/src/proj"'; then
    pass "update keeps instance mode, worktrees and root"
else
    fail "update should keep instance mode, worktrees and root"
fi
if toml_has "$updated" '[.window[].name] == ["code", "srv"]'; then
    pass "update replaces the windows"
else
    fail "update should replace the windows with the session's"
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
    write_launcher "$USER_LAUNCHERS/plain.toml"
)
if (
    unset worktrees_dir
    update_launcher "plain"
) 2>/dev/null && toml_has "$USER_LAUNCHERS/plain.toml" 'any(.window[]; .name == "srv")'; then
    pass "updates a launcher without worktree settings"
else
    fail "should update a launcher without worktree settings"
fi

# a failed capture (session gone) leaves no windows: neither path may write
cp "$USER_LAUNCHERS/plain.toml" "$TEST_DIR/plain.before"
build_state_from_capture ""
if ! update_launcher "plain" && ! write_new_launcher "empty" &&
    cmp -s "$TEST_DIR/plain.before" "$USER_LAUNCHERS/plain.toml" && [[ ! -e "$USER_LAUNCHERS/empty.toml" ]]; then
    pass "an empty capture writes nothing"
else
    fail "an empty capture must not write or overwrite a launcher"
fi

tmux set-option -t "=orig:" @launcher hand
build_state_from_capture "$("$CAPTURE" orig)"
assert_equals "a tagged hand-written launcher is offered for update" "hand" "$(update_target || true)"
update_launcher "hand"
hand="$(cat "$USER_LAUNCHERS/hand.toml")"
if [[ "$hand" == *"# notes on this launcher"* && "$hand" == *'description = "hand-written"  # shown in the picker'* ]] &&
    toml_has "$USER_LAUNCHERS/hand.toml" '[.window[].name] == ["code", "srv"]'; then
    pass "updating a hand-written launcher keeps its comments"
else
    fail "updating a hand-written launcher should keep its comments (got: $hand)"
fi

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
# shellcheck disable=SC2016 # jq source
if toml_has "$USER_LAUNCHERS/repo.toml" '.root == $r and .worktrees.dir == $w' --arg r "$repo" --arg w "$wts"; then
    pass "a new launcher is rooted at the main checkout, worktrees at their parent"
else
    fail "a new launcher should root at the main checkout and point worktrees at their parent"
fi
if toml_has "$USER_LAUNCHERS/repo.toml" '.instance == "prompt" and .worktrees.prefix == "rp" and (.worktrees | has("env") | not)'; then
    pass "instances prompt and open <prefix>-<n>-* worktrees"
else
    fail "a worktree launcher should prompt for instances with the worktree prefix"
fi

replay repo repo-7
assert_equals "a numbered instance opens its worktree" "$wts/rp-7-fix/src" \
    "$(tmux display-message -p -t "=repo-7:code.2" '#{pane_current_path}' 2>/dev/null)"
replay repo repo-rp-7-fix
assert_equals "a named instance opens the worktree with that name" "$wts/rp-7-fix" \
    "$(tmux display-message -p -t "=repo-rp-7-fix:code.1" '#{pane_current_path}' 2>/dev/null)"
replay repo
assert_equals "the base session opens the main checkout" "$repo" \
    "$(tmux display-message -p -t "=repo:code.1" '#{pane_current_path}' 2>/dev/null)"

# a hand-written worktree launcher, found by its instance's session name
cat >"$USER_LAUNCHERS/hw.toml" <<EOF
description = "Hand-written worktrees"
session = "hw"
instance = "prompt"
root = "$repo"

[worktrees]
dir = "$wts"
prefix = "rp"

[[window]]
name = "zsh"
EOF
cp "$USER_LAUNCHERS/hw.toml" "$TEST_DIR/hw.before"
tmux rename-session -t "=wtsess" hw-7
build_state_from_capture "$("$CAPTURE" hw-7)"
assert_equals "an untagged instance session finds its launcher by name" "hw" "$(update_target || true)"
update_launcher "hw"
if cmp -s "$TEST_DIR/hw.before" "$LAUNCHER_BACKUPS/hw.toml"; then
    pass "a hand-written launcher is backed up before it's replaced"
else
    fail "a hand-written launcher should be copied to LAUNCHER_BACKUPS"
fi
# shellcheck disable=SC2016 # jq source
if toml_has "$USER_LAUNCHERS/hw.toml" '.description == "Hand-written worktrees" and .instance == "prompt"
    and .root == $r and .worktrees == {dir: $w, prefix: "rp"}' \
    --arg r "$repo" --arg w "$wts"; then
    pass "the rewrite keeps description, instances, dirs and worktree prefix"
else
    fail "the rewrite should carry over the hand-written launcher's settings"
fi
if toml_has "$USER_LAUNCHERS/hw.toml" '.window[0].pane[1].dir == "src"'; then
    pass "pane dirs stay relative to the worktree"
else
    fail "pane dirs should be relative to the worktree, not absolute"
fi

# ═══════════════════════════════════════════════════════════════════════════
section "Auto-named windows"
# ═══════════════════════════════════════════════════════════════════════════

tmux new-session -d -s autos -n pinned -c "$TEST_DIR/proj" -x 200 -y 50
tmux new-window -t "=autos:" -c "$TEST_DIR/proj"
build_state_from_capture "$("$CAPTURE" autos)"
assert_equals "only the unnamed window is auto-named" " 1" "${win_autonames[*]}"
write_new_launcher "autos"
if toml_has "$USER_LAUNCHERS/autos.toml" '(.window[0] | has("auto_rename") | not) and .window[1].auto_rename == true'; then
    pass "only the auto-named window is written with auto_rename"
else
    fail "only the second window should carry auto_rename = true"
fi
(
    load_existing_launcher "$USER_LAUNCHERS/autos.toml"
    assert_equals "auto-named windows survive a load" " 1" "${win_autonames[*]}"
)
replay autos autos2
assert_equals "replay renames only the auto-named window" "0 1" \
    "$(tmux list-windows -t "=autos2" -F '#{automatic-rename}' 2>/dev/null | tr '\n' ' ' | sed 's/ $//')"

# ═══════════════════════════════════════════════════════════════════════════
section "Changes an update would make"
# ═══════════════════════════════════════════════════════════════════════════

# the file was edited after the session started: auto_rename and a gone window
cat >"$USER_LAUNCHERS/drift.toml" <<'EOF'
description = "drift"
session = "drift"

[[window]]
name = "pinned"
auto_rename = true

[[window]]
name = "gone"
EOF
tmux new-session -d -s drift -n pinned -c "$TEST_DIR/proj" -x 200 -y 50
tmux new-window -t "=drift:" -n added -c "$TEST_DIR/proj"
build_state_from_capture "$("$CAPTURE" drift)"
changes=$(update_changes drift)
assert_equals "lists each changed value and each added or removed window" \
    $'pinned  auto_rename: true → —\n− window gone\n+ window added' "$changes"
assert_equals "listing the changes writes nothing" "true" \
    "$(yq -p toml -o json "$USER_LAUNCHERS/drift.toml" | jq '.window[0].auto_rename')"
if update_message drift | grep -qF 'pinned  auto_rename: true → —'; then
    pass "the update confirmation shows the changes"
else
    fail "the update confirmation should list the changes"
fi

cat >"$USER_LAUNCHERS/same.toml" <<'EOF'
description = "same"
session = "same"

[[window]]
name = "only"
EOF
tmux new-session -d -s same -n only -c "$TEST_DIR/proj" -x 200 -y 50
build_state_from_capture "$("$CAPTURE" same)"
if update_message same | grep -qF 'Nothing in the file changes.'; then
    pass "an update that changes nothing says so"
else
    fail "an unchanged launcher should say nothing changes"
fi

# ═══════════════════════════════════════════════════════════════════════════
section "{SESSION} in saved commands"
# ═══════════════════════════════════════════════════════════════════════════

session_toml='description = "tickets"
session = "tick"

[[window]]
name = "jiru"
cmd = "echo {SESSION}"'
printf '%s\n' "$session_toml" >"$USER_LAUNCHERS/tick.toml"
tmux new-session -d -s tick-12 -n jiru -c "$TEST_DIR/proj" -x 200 -y 50
tmux send-keys -t "=tick-12:jiru" 'sleep 300 TICK-12' Enter
sleep 0.5
build_state_from_capture "$("$CAPTURE" tick-12)"
pane_cmds["0:1"]="echo TICK-12"
win_cmds[0]="echo TICK-12"
assert_equals "a command that expands to the captured one isn't a change" "" "$(update_changes tick)"
update_launcher tick
assert_equals "an update keeps {SESSION} where it expands to the captured command" "echo {SESSION}" \
    "$(yq -p toml -o json "$USER_LAUNCHERS/tick.toml" | jq -r '.window[0].cmd')"
win_cmds[0]="echo other"
pane_cmds["0:1"]="echo other"
update_launcher tick
assert_equals "a different captured command replaces it" "echo other" \
    "$(yq -p toml -o json "$USER_LAUNCHERS/tick.toml" | jq -r '.window[0].cmd')"

cleanup_test_server

print_summary
[[ $FAIL -eq 0 ]]
