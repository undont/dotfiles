#!/usr/bin/env bash
# test suite for editing launchers with rich windows in the wizard (new.sh)
# drives the real wizard in a pane on the isolated test server, waiting for each
# prompt before answering it
# shellcheck disable=SC2030,SC2031  # fixtures and comparisons run in subshells
# on purpose, so their launcher state never leaks into the next check

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/_test-helpers.sh"
source "$SCRIPT_DIR/../_lib/common.sh"
# shellcheck source=tmux/scripts/_lib/launcher-gen.sh
source "$SCRIPT_DIR/../_lib/launcher-gen.sh"

NEW_SH="$SCRIPT_DIR/../launchers/new.sh"
TEST_DIR="$(mktemp -d)"
TEST_DIR="$(cd "$TEST_DIR" && pwd -P)"
CONFIG="$TEST_DIR/config"
LAUNCHERS="$CONFIG/dotfiles/launchers"
mkdir -p "$LAUNCHERS" "$TEST_DIR/proj"

# shellcheck disable=SC2329  # Called indirectly via trap
_cleanup_wizard_tests() {
    cleanup_test_server
    rm -rf "$TEST_DIR"
}
trap _cleanup_wizard_tests EXIT INT TERM

# a launcher with a simple window and a rich one: one pane on the left, two
# stacked on the right, in their own directories
write_rich_launcher() {
    (
        name="rich"
        description="Rich launcher"
        instance_mode="n"
        project_dir="$TEST_DIR/proj"
        worktree_aware="n"
        worktrees_dir=""
        win_names=(edit dev)
        win_cmds=(nvim "")
        win_splits=(no no)
        win_split_cmds=("" "")
        win_panes=("" 3)
        win_layouts=("" $'1 h 70 2\n2 v 48 3')
        pane_cmds=(["1:1"]="make status" ["1:2"]="echo 'it works'" ["1:3"]="")
        pane_dirs=(["1:1"]="" ["1:2"]="backend" ["1:3"]="/tmp")
        generate_launcher >"$LAUNCHERS/rich"
        chmod +x "$LAUNCHERS/rich"
    )
}

screen() { tmux capture-pane -p -t "=wiz:"; }

# wait until the wizard's screen shows some text
wait_for() {
    local text="$1" i
    for ((i = 0; i < 100; i++)); do
        screen | grep -qF -- "$text" && return 0
        sleep 0.1
    done
    fail "timed out waiting for: $text (screen: $(screen | grep -v '^ *$' | tail -3 | tr '\n' '|'))"
    return 1
}

# answer a prompt: wait for it, then send keys
answer() {
    local prompt="$1"
    shift
    wait_for "$prompt"
    tmux send-keys -t "=wiz:" "$@"
}

start_wizard() {
    tmux kill-session -t "=wiz" 2>/dev/null || true
    tmux new-session -d -s wiz -x 120 -y 40 \
        "env XDG_CONFIG_HOME='$CONFIG' XDG_CACHE_HOME='$TEST_DIR/cache' PROJECT_DIRS='$TEST_DIR' bash '$NEW_SH' --edit rich; sleep 30"
}

# the steps before the windows: description, directory, instances
answer_basics() {
    answer "Description" Enter
    answer "Directory:" Enter
    answer "Prompt for instance name?" Enter
}

echo ""
echo "${CYAN}═══════════════════════════════════════════${NC}"
echo "${CYAN}  Launcher Wizard Tests${NC}"
echo "${CYAN}═══════════════════════════════════════════${NC}"
echo ""

# ═══════════════════════════════════════════════════════════════════════════
section "Pane position labels"
# ═══════════════════════════════════════════════════════════════════════════

win_layouts=("" $'1 h 70 2\n2 v 48 3')
assert_equals "pane 1 is top-left" "top-left" "$(pane_position_label 1 1)"
assert_equals "a horizontal split puts the new pane to the right" "right of 1" "$(pane_position_label 1 2)"
assert_equals "a vertical split puts the new pane below" "below 2" "$(pane_position_label 1 3)"
assert_equals "an unknown pane gets a plain label" "pane 9" "$(pane_position_label 1 9)"

# ═══════════════════════════════════════════════════════════════════════════
section "Editing a rich window"
# ═══════════════════════════════════════════════════════════════════════════

setup_test_server
write_rich_launcher
cp "$LAUNCHERS/rich" "$TEST_DIR/rich.before"

start_wizard
answer_basics
answer "Number of windows" Enter
# window 1 is simple: name, command, split
answer "Window 1" Enter
answer "Command" Enter
answer "Split pane?" Enter
# window 2 is rich: name, then a command per pane
answer "Window 2" Enter
answer "Pane 1 (top-left)" Enter
wait_for "Pane 2 (right of 1, in backend)"
shown=$(screen)
answer "Pane 2 (right of 1, in backend)" C-u
tmux send-keys -t "=wiz:" -l "echo changed"
tmux send-keys -t "=wiz:" Enter
answer "Pane 3 (below 2, in /tmp)" Enter
wait_for "Launcher updated"

if [[ "$shown" == *"layout: custom (3 panes), kept as is"* ]]; then
    pass "the wizard says the layout is kept"
else
    fail "the wizard should say the layout is kept (screen: $shown)"
fi
if [[ "$shown" != *"Split pane?"* && "$shown" != *"Split command"* ]]; then
    pass "a rich window gets no split questions"
else
    fail "a rich window should not ask about splitting"
fi

edited=$(
    name=rich
    load_existing_launcher "$LAUNCHERS/rich"
    declare -p win_names win_cmds win_panes win_layouts pane_cmds pane_dirs
)
expected=$(
    name=rich
    load_existing_launcher "$TEST_DIR/rich.before"
    pane_cmds["1:2"]="echo changed"
    declare -p win_names win_cmds win_panes win_layouts pane_cmds pane_dirs
)
if [[ "$edited" == "$expected" ]]; then
    pass "only pane 2's command changed; layout, folders and other windows are kept"
else
    fail "only pane 2's command should change (got: $edited)"
fi
if bash -n "$LAUNCHERS/rich" && is_generated_launcher "$LAUNCHERS/rich"; then
    pass "the edited launcher is valid and still marked @generated"
else
    fail "the edited launcher should be valid and marked @generated"
fi
if cmp -s "$TEST_DIR/rich.before" "$TEST_DIR/cache/tmux/launcher-backups/rich"; then
    pass "the original is backed up before the edit is written"
else
    fail "editing should copy the original to the launcher backups"
fi

# ═══════════════════════════════════════════════════════════════════════════
section "Changing the window count"
# ═══════════════════════════════════════════════════════════════════════════

# a new count starts the windows over, rich data included; nothing may be left
# behind that would make the new window look rich
write_rich_launcher
start_wizard
answer_basics
answer "Number of windows" C-u
tmux send-keys -t "=wiz:" -l "1"
tmux send-keys -t "=wiz:" Enter
answer "Window 1" Enter
answer "Command" -l "vim"
tmux send-keys -t "=wiz:" Enter
answer "Split pane?" Enter
wait_for "Launcher updated"

if ! grep -q '^p1=' "$LAUNCHERS/rich" && grep -q "send-keys -t \"\$SESSION:dev\" 'vim' Enter" "$LAUNCHERS/rich"; then
    pass "a new window count replaces the rich window with a simple one"
else
    fail "a new window count should drop the rich window (file: $(grep -E '^tmux|^p[0-9]' "$LAUNCHERS/rich" | tr '\n' ';'))"
fi
assert_equals "one window remains" "1" "$(grep -c '^tmux new-' "$LAUNCHERS/rich")"

# ═══════════════════════════════════════════════════════════════════════════
section "Hand-written launchers are refused"
# ═══════════════════════════════════════════════════════════════════════════

# the wizard only understands its own output: it can't show an unnamed window or
# extra panes, and saving would drop them
printf '#!/usr/bin/env bash\n# @description: hand-written\ntmux new-session -d -s hand\n' >"$LAUNCHERS/hand"
chmod +x "$LAUNCHERS/hand"
cp "$LAUNCHERS/hand" "$TEST_DIR/hand.before"
tmux kill-session -t "=wiz" 2>/dev/null || true
tmux new-session -d -s wiz -x 120 -y 40 \
    "env XDG_CONFIG_HOME='$CONFIG' XDG_CACHE_HOME='$TEST_DIR/cache' PROJECT_DIRS='$TEST_DIR' bash '$NEW_SH' --edit hand; echo EXIT=\$? >'$TEST_DIR/exit'; sleep 30"

wait_for "written by hand"
shown=$(screen)
if [[ "$shown" == *"The wizard can only edit launchers it created"* ]]; then
    pass "the wizard refuses to edit a hand-written launcher"
else
    fail "the wizard should refuse hand-written launchers (screen: $shown)"
fi
answer "spc/enter close" " "
# new.sh exits, then the pane writes the exit code
for _i in $(seq 1 30); do [[ -s "$TEST_DIR/exit" ]] && break; sleep 0.1; done
if grep -qx 'EXIT=1' "$TEST_DIR/exit" && cmp -s "$TEST_DIR/hand.before" "$LAUNCHERS/hand"; then
    pass "it exits without touching the launcher"
else
    fail "refusal should exit 1 and leave the launcher unchanged"
fi

cleanup_test_server

print_summary
[[ $FAIL -eq 0 ]]
