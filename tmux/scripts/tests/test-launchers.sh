#!/usr/bin/env bash
# cases run in subshells so launcher state can't leak between them; the libs
# they source assign DOTFILES_ROOT the same path
# shellcheck disable=SC2030,SC2031
set -euo pipefail

# unit tests for launcher management scripts:
#   - launchers/list.sh (output format, launcher discovery, dedup)
#   - launchers/run.sh (routing on the session key, metadata)
#   - launchers/delete.sh (repo protection, path traversal guard)
#   - launchers/new.sh (name validation)
#   - _lib/launcher-gen.sh (TOML output, load/write round trip)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
LIST_LAUNCHERS="$SCRIPT_DIR/../launchers/list.sh"
RUN_LAUNCHER="$SCRIPT_DIR/../launchers/run.sh"
DELETE_LAUNCHER="$SCRIPT_DIR/../launchers/delete.sh"
NEW_LAUNCHER="$SCRIPT_DIR/../launchers/new.sh"

source "$SCRIPT_DIR/_test-helpers.sh"

# ===========================================================================
# launchers/list.sh tests
# ===========================================================================

section "launchers/list.sh: Script Exists and Is Executable"

if [[ -f "$LIST_LAUNCHERS" ]]; then
    pass "launchers/list.sh exists"
else
    fail "launchers/list.sh not found at $LIST_LAUNCHERS"
    exit 1
fi

if [[ -x "$LIST_LAUNCHERS" ]]; then
    pass "launchers/list.sh is executable"
else
    fail "launchers/list.sh is not executable"
fi

section "launchers/list.sh: Shebang"

shebang=$(head -1 "$LIST_LAUNCHERS")
if [[ "$shebang" == "#!/usr/bin/env bash" ]]; then
    pass "uses portable shebang (#!/usr/bin/env bash)"
else
    fail "should use #!/usr/bin/env bash, got: $shebang"
fi

section "launchers/list.sh: ShellCheck Validation"

if command -v shellcheck &>/dev/null; then
    if shellcheck -x -e SC1091 -e SC2059 -e SC2155 -e SC2015 -e SC2016 -e SC2034 "$LIST_LAUNCHERS" 2>/dev/null; then
        pass "launchers/list.sh passes shellcheck"
    else
        fail "launchers/list.sh has shellcheck warnings"
    fi
else
    skip "shellcheck not installed"
fi

section "launchers/list.sh: Sources the shared libraries (no find_dotfiles_root duplication)"

list_content=$(cat "$LIST_LAUNCHERS")

if [[ "$list_content" == *'source "$SCRIPT_DIR/../_lib/launcher-data.sh"'* ]]; then
    pass "sources launcher-data.sh (and through it common.sh)"
else
    fail "should source launcher-data.sh"
fi

if [[ "$list_content" == *"find_dotfiles_root"* ]]; then
    fail "should NOT contain find_dotfiles_root (use common.sh instead)"
else
    pass "no find_dotfiles_root duplication"
fi

section "launchers/list.sh: Output Format"

output=$("$LIST_LAUNCHERS" 2>&1) || true

# should have dotfiles ASCII art logo in header
if [[ "$output" == *'__| | ___ | |_'* ]]; then
    pass "output includes dotfiles logo header"
else
    fail "output should include dotfiles logo header"
fi

# should list repo launchers (dev has @description)
if [[ "$output" == *"dev"* ]]; then
    pass "output lists dev launcher"
else
    fail "output should list dev launcher (has @description tag)"
fi

# should show description from @description tag
if [[ "$output" == *"Dev session"* ]]; then
    pass "output shows dev description"
else
    fail "output should show dev @description text"
fi

# code launcher has no @description, should be hidden
if [[ "$output" != *"VS Code"* ]]; then
    pass "launchers without @description are hidden (code)"
else
    fail "launchers without @description should be hidden"
fi

# template should be excluded
if [[ "$output" != *"launcher.toml"* && "$output" != *"My project"* ]]; then
    pass "template file is excluded from listing"
else
    fail "launcher.toml.template should be excluded from listing"
fi

section "launchers/list.sh: Launcher Dedup (user overrides repo)"

# create temporary user launcher dir with a duplicate name
TEST_XDG=$(mktemp -d)
TEST_USER_DIR="$TEST_XDG/dotfiles/launchers"
mkdir -p "$TEST_USER_DIR"
cat >"$TEST_USER_DIR/dev.toml" <<'TESTEOF'
description = "User override of dev"

[[window]]
name = "zsh"
TESTEOF
# not valid TOML: listed without it rather than failing the whole list
printf 'description = \n' >"$TEST_USER_DIR/broken.toml"

dedup_output=$(XDG_CONFIG_HOME="$TEST_XDG" "$LIST_LAUNCHERS" 2>&1) || true
# strip ANSI for counting
plain_dedup=$(printf '%s' "$dedup_output" | sed 's/\x1b\[[0-9;]*m//g')
dev_count=$(printf '%s' "$plain_dedup" | grep -c 'dev' || true)

if [[ "$dev_count" -eq 1 ]]; then
    pass "dedup: dev appears exactly once when user overrides repo"
else
    fail "dedup: dev should appear once, got $dev_count times"
fi

# user version description should win
if [[ "$dedup_output" == *"User override"* ]]; then
    pass "dedup: user launcher description takes priority"
else
    fail "dedup: user launcher description should override repo"
fi

if [[ "$dedup_output" == *"Runs btop"* ]]; then
    pass "a launcher file that isn't valid TOML doesn't hide the others"
else
    fail "an invalid launcher file should be skipped, not empty the list"
fi

rm -rf "$TEST_XDG"

section "launchers/list.sh: Performance Guardrails"

if grep -q "mktemp -d" "$LIST_LAUNCHERS"; then
    fail "launchers/list.sh should avoid temp-dir churn on hot path"
else
    pass "launchers/list.sh avoids temp-dir churn"
fi

if grep -q 'launcher_field "\$USER_LAUNCHERS" description' "$LIST_LAUNCHERS" &&
    grep -q '"\${files\[@\]}"' "$DOTFILES_ROOT/tmux/scripts/_lib/launcher-data.sh"; then
    pass "launchers/list.sh reads every description in one yq run (launcher_field)"
else
    fail "launchers/list.sh should read descriptions in one yq run, not one per file"
fi

# ===========================================================================
# launchers/run.sh tests (pure function logic)
# ===========================================================================

section "launchers/run.sh: Script Exists and Is Executable"

if [[ -f "$RUN_LAUNCHER" ]]; then
    pass "launchers/run.sh exists"
else
    fail "launchers/run.sh not found"
fi

if [[ -x "$RUN_LAUNCHER" ]]; then
    pass "launchers/run.sh is executable"
else
    fail "launchers/run.sh is not executable"
fi

section "launchers/run.sh: ShellCheck Validation"

if command -v shellcheck &>/dev/null; then
    if shellcheck -x -e SC1091 -e SC2059 -e SC2155 -e SC2015 -e SC2016 -e SC2034 "$RUN_LAUNCHER" 2>/dev/null; then
        pass "launchers/run.sh passes shellcheck"
    else
        fail "launchers/run.sh has shellcheck warnings"
    fi
else
    skip "shellcheck not installed"
fi

section "launchers/run.sh: Routing and Metadata"

run_content=$(cat "$RUN_LAUNCHER")

# the session key decides fixed-session vs directory launcher
if [[ "$run_content" == *'.session // ""'* && "$run_content" == *'if [[ -n "$base_name" ]]; then'* ]]; then
    pass "routes on the TOML session key"
else
    fail "should route fixed vs directory launchers on the session key"
fi
if [[ "$run_content" == *'.description // ""'* && "$run_content" == *'.instance // "auto"'* ]]; then
    pass "reads description and instance mode from the TOML"
else
    fail "should read description and instance mode from the TOML"
fi
if [[ "$(yq -p toml -o yaml '.session // ""' "$DOTFILES_ROOT/launchers/dev.toml")" == "" ]]; then
    pass "dev.toml has no session key (directory launcher)"
else
    fail "dev.toml should have no session key"
fi
if [[ "$(yq -p toml -o yaml '.session // ""' "$DOTFILES_ROOT/launchers/launcher.toml.template")" != "" ]]; then
    pass "launcher.toml.template has a session key (fixed launcher)"
else
    fail "launcher.toml.template should have a session key"
fi

# instance lookups go through the backend: bare tmux has-session prefix-matches
# (foo-2 would find a running foo-23), and it can't see rex sessions
if [[ "$run_content" != *"tmux has-session"* && "$run_content" == *"launcher_session_exists"* ]]; then
    pass "checks sessions through the backend, exactly"
else
    fail "should check sessions with launcher_session_exists, not tmux has-session"
fi
if [[ "$run_content" == *'exec "$LAUNCH" "$name"'* ]]; then
    pass "runs launchers through launch.sh"
else
    fail "should exec launch.sh with the launcher name"
fi

# the metadata block itself, run against a description that spans lines
meta_block=$(awk '/^# \(NUL-separated/ { on = 1; next } on { print } on && /jq -j/ { exit }' "$RUN_LAUNCHER")
meta_dir=$(mktemp -d)
meta_file="$meta_dir/multi.toml"
printf '%s\n' 'description = """two' 'lines"""' 'instance = "prompt"' 'session = "acme"' '[[window]]' >"$meta_file"
meta=$(
    # shellcheck source=tmux/scripts/_lib/launcher-data.sh
    source "$DOTFILES_ROOT/tmux/scripts/_lib/launcher-data.sh"
    LAUNCHER_FILE="$meta_file"
    eval "$meta_block"
    # shellcheck disable=SC2154 # assigned by the eval'd block
    printf '%s|%s|%s' "$description" "$instance_mode" "$base_name"
)
assert_equals "a multi-line description doesn't shift instance and session" $'two\nlines|prompt|acme' "$meta"
rm -rf "$meta_dir"

section "launchers/dev: Symlink Resolution"

# a relative link, and a link to that link, from another directory: dev must
# still find launch.sh (which then asks for the missing directory argument)
link_dir=$(mktemp -d)
link_dir=$(cd -P "$link_dir" && pwd)
mkdir -p "$link_dir/a/b" "$link_dir/c"
dev_target="$(cd -P "$DOTFILES_ROOT/tmux/scripts/launchers" && pwd)/dev"
rel_target=$(python3 -c 'import os,sys; print(os.path.relpath(sys.argv[1], sys.argv[2]))' "$dev_target" "$link_dir/a/b")
ln -s "$rel_target" "$link_dir/a/b/dev"
ln -s ../a/b/dev "$link_dir/c/dev"
for link in "$link_dir/a/b/dev" "$link_dir/c/dev"; do
    out=$(cd / && "$link" 2>&1 || true)
    if [[ "$out" == *"dev needs a directory"* ]]; then
        pass "dev through ${link#"$link_dir"/} finds launch.sh"
    else
        fail "dev through ${link#"$link_dir"/} should find launch.sh (got: $out)"
    fi
done
rm -rf "$link_dir"

section "launchers/run.sh: Input Sanitisation"

# check that fzf become() commands sanitise user input
if [[ "$run_content" == *"tr -c '[:alnum:]_-' '-'"* ]]; then
    pass "sanitises suffix input in become() command (dots excluded)"
else
    fail "should sanitise suffix with tr in become() command (dots excluded)"
fi

if [[ "$run_content" == *"new-dir.sh"* ]]; then
    pass "delegates new directory creation to new-dir.sh"
else
    fail "should delegate new directory creation to new-dir.sh"
fi

section "launchers/run.sh: DOTFILES_ROOT Validation"

if [[ "$run_content" == *'DOTFILES_ROOT'*'invalid'* ]] || [[ "$run_content" == *'-z "${DOTFILES_ROOT'* ]]; then
    pass "validates DOTFILES_ROOT after sourcing common.sh"
else
    fail "should validate DOTFILES_ROOT is set and valid"
fi

section "launchers/run.sh: fzf Dependency Check"

if [[ "$run_content" == *"require_fzf"* ]]; then
    pass "checks for fzf availability"
else
    fail "should check for fzf availability"
fi

# ===========================================================================
# launchers/delete.sh tests
# ===========================================================================

section "launchers/delete.sh: Script Exists and Is Executable"

if [[ -f "$DELETE_LAUNCHER" ]]; then
    pass "launchers/delete.sh exists"
else
    fail "launchers/delete.sh not found"
fi

if [[ -x "$DELETE_LAUNCHER" ]]; then
    pass "launchers/delete.sh is executable"
else
    fail "launchers/delete.sh is not executable"
fi

section "launchers/delete.sh: ShellCheck Validation"

if command -v shellcheck &>/dev/null; then
    if shellcheck -x -e SC1091 -e SC2059 -e SC2155 -e SC2015 -e SC2016 -e SC2034 "$DELETE_LAUNCHER" 2>/dev/null; then
        pass "launchers/delete.sh passes shellcheck"
    else
        fail "launchers/delete.sh has shellcheck warnings"
    fi
else
    skip "shellcheck not installed"
fi

section "launchers/delete.sh: Path Traversal Protection"

del_content=$(cat "$DELETE_LAUNCHER")

if [[ "$del_content" == *"basename"* ]]; then
    pass "uses basename to strip path separators"
else
    fail "should use basename to prevent path traversal"
fi

# check for dot/dotdot rejection
if [[ "$del_content" == *'".."'* ]] || [[ "$del_content" == *'"."'* ]]; then
    pass "rejects . and .. as launcher names"
else
    fail "should reject . and .. as launcher names"
fi

section "launchers/delete.sh: Repo Launcher Protection"

if [[ "$del_content" == *"Cannot delete repo launcher"* ]]; then
    pass "protects repo launchers from deletion"
else
    fail "should prevent deletion of repo launchers"
fi

if [[ "$del_content" == *"show_visual_confirm"* ]]; then
    pass "shows confirmation dialog before deleting"
else
    fail "should show confirmation before deleting"
fi

# ===========================================================================
# launchers/new.sh tests (name validation)
# ===========================================================================

section "launchers/new.sh: Script Exists and Is Executable"

if [[ -f "$NEW_LAUNCHER" ]]; then
    pass "launchers/new.sh exists"
else
    fail "launchers/new.sh not found"
fi

if [[ -x "$NEW_LAUNCHER" ]]; then
    pass "launchers/new.sh is executable"
else
    fail "launchers/new.sh is not executable"
fi

section "launchers/new.sh: ShellCheck Validation"

if command -v shellcheck &>/dev/null; then
    if shellcheck -x -e SC1091 -e SC2059 -e SC2155 -e SC2015 -e SC2016 -e SC2034 "$NEW_LAUNCHER" 2>/dev/null; then
        pass "launchers/new.sh passes shellcheck"
    else
        fail "launchers/new.sh has shellcheck warnings"
    fi
else
    skip "shellcheck not installed"
fi

section "launchers/new.sh: Name Validation"

nl_content=$(cat "$NEW_LAUNCHER")

# sanitise_launcher_name lives in tmux/scripts/_lib/common.sh
COMMON_LIB="$DOTFILES_ROOT/tmux/scripts/_lib/common.sh"
common_lib_content=$(cat "$COMMON_LIB")

# launchers/new.sh should call sanitise_launcher_name (from common.sh)
if [[ "$nl_content" == *"sanitise_launcher_name"* ]]; then
    pass "calls sanitise_launcher_name from shared library"
else
    fail "should call sanitise_launcher_name from shared library"
fi

# should sanitise special characters
if [[ "$common_lib_content" == *"tr -c '[:alnum:]_.-' '-'"* ]] || [[ "$common_lib_content" == *"tr -c '[:alnum:]_-' '-'"* ]]; then
    pass "sanitises special characters in launcher names"
else
    fail "should sanitise special characters in launcher names"
fi

# should lowercase names
if [[ "$common_lib_content" == *"tr '[:upper:]' '[:lower:]'"* ]]; then
    pass "lowercases launcher names"
else
    fail "should lowercase launcher names"
fi

# should strip leading dots/dashes
if [[ "$common_lib_content" == *'strip leading dots/dashes'* ]] || [[ "$common_lib_content" == *'%%[[:alnum:]_]'* ]]; then
    pass "strips leading dots/dashes from names"
else
    fail "should strip leading dots/dashes from names"
fi

# should enforce length limit
if [[ "$common_lib_content" == *':0:64'* ]] || [[ "$common_lib_content" == *'{name:0:64}'* ]]; then
    pass "enforces 64-character name length limit"
else
    fail "should enforce 64-character name length limit"
fi

# should block shell reserved words
if [[ "$common_lib_content" == *"test|cd|ls"* ]] || [[ "$common_lib_content" == *"test | cd | ls"* ]]; then
    pass "blocks shell reserved words as launcher names"
else
    fail "should block shell reserved words (test, cd, ls, etc.)"
fi

section "launchers/new.sh: Window Count Cap"

if [[ "$nl_content" == *"-gt 20"* ]]; then
    pass "caps maximum window count at 20"
else
    fail "should cap window count at 20"
fi

section "_lib/launcher-gen.sh: Written Launcher"

LAUNCHER_GEN="$DOTFILES_ROOT/tmux/scripts/_lib/launcher-gen.sh"
GEN_TMP="$(mktemp -d)"
# shellcheck disable=SC2329  # Called indirectly via trap
_cleanup_gen_tmp() { rm -rf "$GEN_TMP"; }
trap _cleanup_gen_tmp EXIT

# wizard state for a sample launcher: a dotted name, an apostrophe in the
# project path, and single quotes in both a pane command and a split command
# shellcheck disable=SC2329  # Called in subshells below
gen_fixture() {
    name="my.app"
    description="Sample launcher"
    instance_mode="y"
    project_dir="\$HOME/src/it's here"
    worktree_aware="n"
    worktrees_dir=""
    win_names=(one two)
    win_cmds=("echo 'hi there'" "")
    win_splits=(no yes)
    win_split_cmds=("" "printf '%s' x")
}

gen_file="$GEN_TMP/my.app.toml"
(
    # shellcheck source=tmux/scripts/_lib/launcher-gen.sh
    source "$LAUNCHER_GEN"
    gen_fixture
    write_launcher "$gen_file"
)
gen_json=$(yq -p toml -o json -I0 "$gen_file" 2>/dev/null || true)

if [[ -n "$gen_json" ]] && [[ -z "$(
    source "$DOTFILES_ROOT/tmux/scripts/_lib/launcher-data.sh"
    launcher_problems "$gen_json"
)" ]]; then
    pass "a written launcher is valid TOML that passes the schema"
else
    fail "a written launcher should be valid TOML and pass the schema"
fi

for want in '.session == "my-app"' \
    ".root == \"~/src/it's here\"" \
    '(has("root_env") | not)' \
    '.instance == "prompt"' \
    ".window[0].cmd == \"echo 'hi there'\"" \
    '.window[1].pane[1].split == "h"' \
    ".window[1].pane[1].cmd == \"printf '%s' x\"" \
    '(.window[1].pane[0] | length) == 0'; do
    if jq -e "$want" <<<"$gen_json" >/dev/null 2>&1; then
        pass "written launcher: $want"
    else
        fail "written launcher should satisfy: $want"
    fi
done

section "_lib/launcher-gen.sh: Load/Write Round Trip"

# loading a written launcher gives back the state that wrote it, and writing
# that state again leaves the file as it was
round_trip=$(
    # shellcheck source=tmux/scripts/_lib/launcher-gen.sh
    source "$LAUNCHER_GEN"
    gen_fixture
    want=$(declare -p description instance_mode worktree_aware win_names win_cmds win_splits win_split_cmds)
    load_existing_launcher "$gen_file"
    got=$(declare -p description instance_mode worktree_aware win_names win_cmds win_splits win_split_cmds)
    [[ "$want" == "$got" ]] && echo "state-ok"
    # shellcheck disable=SC2088
    [[ "$project_dir" == "~/src/it's here" ]] && echo "dir-ok"
    before=$(cat "$gen_file")
    write_launcher "$gen_file"
    [[ "$(cat "$gen_file")" == "$before" ]] && echo "rewrite-ok"
    true
)

if [[ "$round_trip" == *state-ok* ]]; then
    pass "load_existing_launcher returns the state write_launcher wrote"
else
    fail "load_existing_launcher should return the written state (quotes, splits, instance mode)"
fi
if [[ "$round_trip" == *dir-ok* ]]; then
    pass "load_existing_launcher returns the root in ~ form"
else
    fail "load_existing_launcher should return the root in ~ form"
fi
if [[ "$round_trip" == *rewrite-ok* ]]; then
    pass "writing a loaded launcher back leaves the file unchanged"
else
    fail "writing a loaded launcher back should leave the file unchanged"
fi

# focus = true placed anywhere that means the same focus stays where it was
for placement in "window" "first-pane"; do
    focus_file="$GEN_TMP/focus-$placement.toml"
    {
        printf 'description = "focus"\nsession = "focus"\n\n[[window]]\nname = "a"\n'
        [[ "$placement" == window ]] && printf 'focus = true\n'
        printf '\n[[window]]\nname = "b"\n[[window.pane]]\ncmd = "x"\n'
        [[ "$placement" == first-pane ]] && printf 'focus = true\n'
        printf '[[window.pane]]\nsplit = "h"\n'
    } >"$focus_file"
    before=$(cat "$focus_file")
    after=$(
        # shellcheck source=tmux/scripts/_lib/launcher-gen.sh
        source "$LAUNCHER_GEN"
        load_existing_launcher "$focus_file"
        name="focus"
        write_launcher "$focus_file"
        cat "$focus_file"
    )
    assert_equals "focus = true on a $placement keeps its place" "$before" "$after"
done
moved=$(
    # shellcheck source=tmux/scripts/_lib/launcher-gen.sh
    source "$LAUNCHER_GEN"
    load_existing_launcher "$GEN_TMP/focus-first-pane.toml"
    name="focus"
    focus_pane=2
    write_launcher "$GEN_TMP/focus-first-pane.toml"
    yq -p toml -o json "$GEN_TMP/focus-first-pane.toml" | jq -c '[.window[1].pane[] | .focus // false]'
)
assert_equals "a different focus still moves the key" "[false,true]" "$moved"

for repo_launcher in "$DOTFILES_ROOT"/launchers/*.toml; do
    launcher_name=$(basename "$repo_launcher" .toml)
    if (
        # shellcheck source=tmux/scripts/_lib/launcher-gen.sh
        source "$LAUNCHER_GEN"
        name="$launcher_name"
        load_existing_launcher "$repo_launcher"
        [[ "$(launcher_state_json | jq -S .)" == "$(launcher_json "$repo_launcher" | jq -S .)" ]]
    ); then
        pass "launchers/$launcher_name.toml loads and writes back unchanged"
    else
        fail "launchers/$launcher_name.toml should load and write back unchanged"
    fi
done

# every schema key, and the template, survive a load and write: same data,
# same comments
# shellcheck source=tmux/scripts/_lib/launcher-data.sh
source "$DOTFILES_ROOT/tmux/scripts/_lib/launcher-data.sh"
cat >"$GEN_TMP/every-key.toml" <<'TOML'
# a launcher using every key
description = "every key"
session = "custom-session"
instance = "auto"
root = "~/src/every"

[worktrees]
dir = "~/src/every-worktrees"

[[window]]
name = "named"
auto_rename = true
dir = "web"
[[window.pane]]
cmd = "make dev"
[[window.pane]]
split = "v"
size = 30
dir = "api"
cmd = "make api"
focus = true
[[window.pane]]
split = "h"
of = 1
size = 50

[[window]]
auto_rename = true
cmd = "claude"
TOML
cat >"$GEN_TMP/window-focus.toml" <<'TOML'
# focus on a later window, the other place it can sit
description = "window focus"
session = "window-focus"

[[window]]
name = "shell"

[[window]]
name = "edit"
focus = true
[[window.pane]]
cmd = "nvim"
[[window.pane]]
split = "h"
TOML
/bin/cp "$DOTFILES_ROOT/launchers/launcher.toml.template" "$GEN_TMP/template.toml"
cat >"$GEN_TMP/split-focus.toml" <<'TOML'
# focus on the second pane of a simple split, the wizard's own window shape
description = "split focus"
session = "split-focus"

[[window]]
name = "dev"
[[window.pane]]
cmd = "nvim"
[[window.pane]]
split = "h"
cmd = "claude"
focus = true
TOML
for fixture in every-key window-focus split-focus template; do
    file="$GEN_TMP/$fixture.toml"
    want=$(launcher_json "$file" | jq -S .)
    comments=$(grep -c '#' "$file")
    (
        # shellcheck source=tmux/scripts/_lib/launcher-gen.sh
        source "$LAUNCHER_GEN"
        name="$fixture"
        load_existing_launcher "$file"
        write_launcher "$file"
    )
    assert_equals "$fixture: every key loads and writes back" "$want" "$(launcher_json "$file" | jq -S .)"
    assert_equals "$fixture: every comment is kept" "$comments" "$(grep -c '#' "$file")"
done

section "_lib/launcher-gen.sh: Comments Survive a Rewrite"

comment_file="$GEN_TMP/commented.toml"
cat >"$comment_file" <<'TESTEOF'
# my notes about this launcher
description = "Before" # the picker shows this
session = "commented"

[[window]]
# the editor window
name = "edit"
cmd = "nvim"

[[window]]
name = "gone"
TESTEOF
(
    # shellcheck source=tmux/scripts/_lib/launcher-gen.sh
    source "$LAUNCHER_GEN"
    name="commented"
    load_existing_launcher "$comment_file"
    description="After"
    win_names=(edit)
    win_cmds=(nvim)
    win_splits=(no)
    win_split_cmds=("")
    win_panes=("")
    win_layouts=("")
    write_launcher "$comment_file"
)
comment_content=$(cat "$comment_file")
for want in "# my notes about this launcher" 'description = "After"  # the picker shows this' "# the editor window"; do
    if [[ "$comment_content" == *"$want"* ]]; then
        pass "rewrite keeps: $want"
    else
        fail "rewrite should keep: $want"
    fi
done
if [[ "$comment_content" != *gone* ]]; then
    pass "a removed window is dropped from the file"
else
    fail "a removed window should be dropped from the file"
fi

section "_lib/launcher-gen.sh: Rich Windows"

# a simple window, then a rich one: three panes (one left, two stacked right),
# each with its own directory, an even split, and a command with single quotes
# shellcheck disable=SC2329  # Called in subshells below
rich_fixture() {
    name="rich"
    description="Rich launcher"
    instance_mode="n"
    project_dir="\$HOME/src/rich"
    worktree_aware="n"
    worktrees_dir=""
    win_names=(edit dev)
    win_cmds=(nvim "")
    win_splits=(no no)
    win_split_cmds=("" "")
    win_panes=("" 3)
    win_layouts=("" $'1 h 70 2\n2 v - 3')
    pane_cmds=(["1:1"]="make status" ["1:2"]="echo 'it works'" ["1:3"]="")
    pane_dirs=(["1:1"]="" ["1:2"]="backend" ["1:3"]="/tmp")
}

rich_file="$GEN_TMP/rich.toml"
(
    # shellcheck source=tmux/scripts/_lib/launcher-gen.sh
    source "$LAUNCHER_GEN"
    rich_fixture
    write_launcher "$rich_file"
)
rich_json=$(yq -p toml -o json -I0 "$rich_file" 2>/dev/null || true)

for want in '.window[1].pane[0] == {cmd: "make status"}' \
    ".window[1].pane[1] == {split: \"h\", size: 70, dir: \"backend\", cmd: \"echo 'it works'\"}" \
    '.window[1].pane[2] == {split: "v", dir: "/tmp"}'; do
    if jq -e "$want" <<<"$rich_json" >/dev/null 2>&1; then
        pass "rich window writes: $want"
    else
        fail "rich window should write: $want"
    fi
done

rich_round_trip=$(
    # shellcheck source=tmux/scripts/_lib/launcher-gen.sh
    source "$LAUNCHER_GEN"
    rich_fixture
    want=$(declare -p win_names win_cmds win_splits win_split_cmds win_panes win_layouts pane_cmds pane_dirs)
    load_existing_launcher "$rich_file"
    got=$(declare -p win_names win_cmds win_splits win_split_cmds win_panes win_layouts pane_cmds pane_dirs)
    [[ "$want" == "$got" ]] && echo "state-ok"
    true
)
if [[ "$rich_round_trip" == *state-ok* ]]; then
    pass "load_existing_launcher reads a rich window back exactly"
else
    fail "load_existing_launcher should read a rich window back exactly"
fi

section "Launchers: tmux Session Targets and @launcher Tag"

backend_content=$(cat "$DOTFILES_ROOT/tmux/scripts/_lib/launcher-tmux.sh")
# set-option -t takes a target-pane, so a bare "=$session" is parsed as a
# window name; the trailing colon makes it the exact-match session
if [[ "$backend_content" == *'tmux set-option -t "=$session:" @launcher "$name"'* ]]; then
    pass "the tmux backend tags the session with the launcher name"
else
    fail "the tmux backend should set @launcher on \"=\$session:\""
fi
if [[ "$backend_content" == *'focus_session "=$1"'* ]]; then
    pass "the tmux backend focuses sessions by exact name"
else
    fail "the tmux backend should focus \"=\$session\", not a prefix match"
fi

section "launchers/picker.sh: Search Mode Keys"

# every single-letter action key must be unbound while searching (/) and
# rebound on esc, or the letter can't be typed into the search
picker_content=$(cat "$SCRIPT_DIR/../launchers/picker.sh")
unbind_list=$(printf '%s' "$picker_content" | grep -o "enable-search[^']*+unbind([^)]*)" | head -1)
rebind_list=$(printf '%s' "$picker_content" | grep -o "disable-search[^']*+rebind([^)]*)" | head -1)
for key in $(printf '%s' "$picker_content" | grep -oE "\-\-bind ['\"][A-Za-z]:(become|execute)" | sed -E "s/--bind ['\"]//; s/:.*//"); do
    if [[ "$unbind_list" == *[\(,]"$key"[,\)]* && "$rebind_list" == *[\(,]"$key"[,\)]* ]]; then
        pass "picker key '$key' is unbound while searching"
    else
        fail "picker key '$key' should be in both the unbind and rebind lists"
    fi
done
if [[ "$picker_content" == *"'s:become(printf \"ACTION:save\")'"* && "$picker_content" == *"'S:become(printf \"ACTION:set\")'"* ]]; then
    pass "s saves the session, S opens settings"
else
    fail "s should save the session and S open settings"
fi
if [[ "$picker_content" == *'"$USER_LAUNCHERS/$edit_name.toml"'* && "$picker_content" != *"@generated"* ]]; then
    pass "the picker edits any user launcher, and only user launchers"
else
    fail "the picker should edit any user launcher (no @generated gate) and refuse repo ones"
fi

section "launchers/new.sh: exec < /dev/tty Documentation"

if [[ "$nl_content" == *"Security note"* ]] || [[ "$nl_content" == *"controlling terminal"* ]]; then
    pass "documents exec < /dev/tty security implications"
else
    fail "should document exec < /dev/tty security implications"
fi

# ===========================================================================
# shared library: launcher path constants
# ===========================================================================

section "Shared Library: Launcher Path Constants"

common_content=$(cat "$DOTFILES_ROOT/tmux/scripts/_lib/common.sh")

if [[ "$common_content" == *"USER_LAUNCHERS="* ]]; then
    pass "common.sh defines USER_LAUNCHERS constant"
else
    fail "common.sh should define USER_LAUNCHERS constant"
fi

if [[ "$common_content" == *"DOTFILES_LAUNCHERS="* ]]; then
    pass "common.sh defines DOTFILES_LAUNCHERS constant"
else
    fail "common.sh should define DOTFILES_LAUNCHERS constant"
fi

if [[ "$common_content" == *"require_fzf()"* ]]; then
    pass "common.sh defines require_fzf helper"
else
    fail "common.sh should define require_fzf helper"
fi

section "Shared Library: list_project_dirs"

# fd prints directories with a trailing slash; picking one in the wizard used
# to store ".../proj/" and change the launcher on an otherwise no-op edit
pd_root="$(mktemp -d)"
pd_root="$(cd "$pd_root" && pwd -P)"
mkdir -p "$pd_root/alpha" "$pd_root/beta"

pd_output=$(
    # shellcheck source=tmux/scripts/_lib/common.sh
    source "$DOTFILES_ROOT/tmux/scripts/_lib/common.sh"
    # stand-in for fd, emitting its trailing-slash format
    # shellcheck disable=SC2329  # Called by list_project_dirs via command -v
    fd() { printf '%s/\n' "${!#}/alpha" "${!#}/beta"; }
    PROJECT_DIRS="$pd_root" list_project_dirs
)
if [[ "$pd_output" == "$pd_root/alpha"$'\n'"$pd_root/beta" ]]; then
    pass "list_project_dirs strips fd's trailing slash"
else
    fail "list_project_dirs should strip trailing slashes (got: $pd_output)"
fi
rm -rf "$pd_root"

# ===========================================================================
# launchers/list.sh: tab-delimited format (name weighting for fzf)
# ===========================================================================

section "launchers/list.sh: Tab-Delimited Output Format"

list_output=$("$LIST_LAUNCHERS" 2>&1) || true

# strip the logo header lines, then check data lines
data_lines=$(printf '%s\n' "$list_output" | tail -n +8)

if [[ -n "$data_lines" ]]; then
    # every data line should contain a tab separator
    bad_lines=0
    while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        if [[ "$line" != *$'\t'* ]]; then
            bad_lines=$((bad_lines + 1))
        fi
    done <<<"$data_lines"

    if [[ $bad_lines -eq 0 ]]; then
        pass "all data lines contain tab delimiter"
    else
        fail "$bad_lines data line(s) missing tab delimiter"
    fi

    # field 1 (before tab) should be the launcher name, field 2 should also contain it
    first_line=$(printf '%s\n' "$data_lines" | head -1)
    field1=$(printf '%s' "$first_line" | cut -d$'\t' -f1)
    field2=$(printf '%s' "$first_line" | cut -d$'\t' -f2-)

    if [[ -n "$field1" ]] && [[ "$field2" == *"$field1"* ]]; then
        pass "hidden field 1 name appears in display field 2"
    else
        fail "field 1 ('$field1') should appear in field 2 for name weighting"
    fi
else
    fail "no data lines found in list output"
fi

# header lines should also have tab prefix (for --with-nth=2 compatibility)
header_lines=$(printf '%s\n' "$list_output" | head -7)
header_has_tabs=true
while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    if [[ "$line" != $'\t'* ]]; then
        header_has_tabs=false
        break
    fi
done <<<"$header_lines"

if [[ "$header_has_tabs" == true ]]; then
    pass "header lines have tab prefix for --with-nth=2 compatibility"
else
    fail "header lines should have tab prefix for --with-nth=2"
fi

section "launchers/picker.sh: Name Weighting Configuration"

picker_content=$(cat "$SCRIPT_DIR/../launchers/picker.sh")

if [[ "$picker_content" == *"--with-nth=2"* ]]; then
    pass "picker uses --with-nth=2 to hide name weight field"
else
    fail "picker should use --with-nth=2 to hide name weight field"
fi

if [[ "$picker_content" == *"--tiebreak=begin"* ]]; then
    pass "picker uses --tiebreak=begin to prefer name matches"
else
    fail "picker should use --tiebreak=begin to prefer name matches"
fi

# ===========================================================================
# launchers/duplicate.sh tests
# ===========================================================================

DUPLICATE_LAUNCHER="$SCRIPT_DIR/../launchers/duplicate.sh"

section "launchers/duplicate.sh: Script Exists and Is Executable"

if [[ -f "$DUPLICATE_LAUNCHER" ]]; then
    pass "launchers/duplicate.sh exists"
else
    fail "launchers/duplicate.sh not found"
fi

if [[ -x "$DUPLICATE_LAUNCHER" ]]; then
    pass "launchers/duplicate.sh is executable"
else
    fail "launchers/duplicate.sh is not executable"
fi

section "launchers/duplicate.sh: ShellCheck Validation"

if command -v shellcheck &>/dev/null; then
    if shellcheck -x -e SC1091 -e SC2059 -e SC2155 -e SC2015 -e SC2016 -e SC2034 "$DUPLICATE_LAUNCHER" 2>/dev/null; then
        pass "launchers/duplicate.sh passes shellcheck"
    else
        fail "launchers/duplicate.sh has shellcheck warnings"
    fi
else
    skip "shellcheck not installed"
fi

section "launchers/duplicate.sh: Path Traversal Protection"

dup_content=$(cat "$DUPLICATE_LAUNCHER")

if [[ "$dup_content" == *"basename"* ]]; then
    pass "uses basename to strip path separators"
else
    fail "should use basename to prevent path traversal"
fi

if [[ "$dup_content" == *'".."'* ]] || [[ "$dup_content" == *'"."'* ]]; then
    pass "rejects . and .. as launcher names"
else
    fail "should reject . and .. as launcher names"
fi

section "launchers/duplicate.sh: Copy Naming Logic"

if [[ "$dup_content" == *"-copy"* ]]; then
    pass "uses -copy suffix for duplicates"
else
    fail "should use -copy suffix for duplicates"
fi

# should handle successive copies (-copy-2, -copy-3, ...)
if [[ "$dup_content" == *"-copy-\${n}"* ]] || [[ "$dup_content" == *'copy-${n}'* ]]; then
    pass "auto-increments copy suffix (-copy-2, -copy-3, ...)"
else
    fail "should auto-increment copy suffix"
fi

# should strip existing -copy suffix before generating new one
if [[ "$dup_content" == *"-copy"*"sed"* ]] || [[ "$dup_content" == *"s/-copy"* ]]; then
    pass "strips existing -copy suffix before renumbering"
else
    fail "should strip existing -copy suffix to avoid name-copy-copy"
fi

section "launchers/duplicate.sh: Description Update"

if [[ "$dup_content" == *"Copy of"* ]]; then
    pass "updates the description to indicate copy"
else
    fail "should update the description to 'Copy of <name>'"
fi

section "launchers/duplicate.sh: Functional Test"

# create a temporary launcher to duplicate
TEST_XDG=$(mktemp -d)
TEST_USER_DIR="$TEST_XDG/dotfiles/launchers"
mkdir -p "$TEST_USER_DIR"
cat >"$TEST_USER_DIR/test-dup.toml" <<'TESTEOF'
# kept on the copy
description = "Test launcher"
session = "test-dup"

[[window]]
name = "zsh"
TESTEOF

# duplicate it
copy_name=$(XDG_CONFIG_HOME="$TEST_XDG" "$DUPLICATE_LAUNCHER" "test-dup" 2>/dev/null) || true

if [[ "$copy_name" == "test-dup-copy" ]]; then
    pass "first copy gets -copy suffix"
else
    fail "first copy should be 'test-dup-copy', got '$copy_name'"
fi

if [[ -f "$TEST_USER_DIR/test-dup-copy.toml" ]]; then
    pass "copy file was created"
else
    fail "copy file should exist at $TEST_USER_DIR/test-dup-copy.toml"
fi

if grep -qx 'description = "Copy of test-dup"' "$TEST_USER_DIR/test-dup-copy.toml" 2>/dev/null &&
    grep -qx '# kept on the copy' "$TEST_USER_DIR/test-dup-copy.toml"; then
    pass "copy has the new description and keeps its comments"
else
    fail "copy should say 'Copy of test-dup' and keep the source's comments"
fi

# duplicate again, should get -copy-2
copy_name2=$(XDG_CONFIG_HOME="$TEST_XDG" "$DUPLICATE_LAUNCHER" "test-dup" 2>/dev/null) || true

if [[ "$copy_name2" == "test-dup-copy-2" ]]; then
    pass "second copy gets -copy-2 suffix"
else
    fail "second copy should be 'test-dup-copy-2', got '$copy_name2'"
fi

# duplicate the copy itself, should still base on original name
copy_name3=$(XDG_CONFIG_HOME="$TEST_XDG" "$DUPLICATE_LAUNCHER" "test-dup-copy" 2>/dev/null) || true

if [[ "$copy_name3" == "test-dup-copy-3" ]]; then
    pass "duplicating a copy bases numbering on original name"
else
    fail "duplicating a copy should produce 'test-dup-copy-3', got '$copy_name3'"
fi

# empty name should exit cleanly
empty_result=$(
    XDG_CONFIG_HOME="$TEST_XDG" "$DUPLICATE_LAUNCHER" "" 2>/dev/null
    echo "exit:$?"
) || true
if [[ "$empty_result" == *"exit:0"* ]]; then
    pass "empty name exits cleanly"
else
    fail "empty name should exit 0"
fi

# a repo launcher duplicates into the user dir
copy_btop=$(XDG_CONFIG_HOME="$TEST_XDG" "$DUPLICATE_LAUNCHER" "btop" 2>/dev/null) || true
if [[ "$copy_btop" == "btop-copy" && -f "$TEST_USER_DIR/btop-copy.toml" ]]; then
    pass "a repo launcher can be duplicated"
else
    fail "duplicating btop should write btop-copy.toml, got '$copy_btop'"
fi

rm -rf "$TEST_XDG"

# ===========================================================================
# summary
# ===========================================================================

print_summary
[[ $FAIL -gt 0 ]] && exit 1
exit 0
