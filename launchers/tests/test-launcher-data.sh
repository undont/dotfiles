#!/usr/bin/env bash
# test suite for lib/data.sh and the tmux and rex launcher backends:
# schema problems, resolving a launcher for a run, writing one back, the rex
# session.create payload, and a tmux build on the isolated test server

# assertions report and carry on, so no errexit
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=tmux/scripts/tests/_test-helpers.sh
source "$SCRIPT_DIR/../../tmux/scripts/tests/_test-helpers.sh"
# shellcheck source=launchers/lib/data.sh
source "$SCRIPT_DIR/../lib/data.sh"
# shellcheck source=launchers/lib/tmux.sh
source "$SCRIPT_DIR/../lib/tmux.sh"
# shellcheck source=launchers/lib/rex.sh
source "$SCRIPT_DIR/../lib/rex.sh"

WORK=$(mktemp -d)
# shellcheck disable=SC2329  # Called indirectly via trap
_cleanup_launcher_data_tests() {
    cleanup_test_server
    rm -rf "$WORK"
}
trap _cleanup_launcher_data_tests EXIT INT TERM

unset SESSION_NAME ACME_ROOT ACME_WORKTREES
ROOT="$WORK/acme"
mkdir -p "$ROOT/web"

# write TOML to $WORK/<name>.toml and print the path; a name like wt/acme
# keeps the launcher name acme apart from another acme
launcher() {
    mkdir -p "$(dirname "$WORK/$1")"
    printf '%s\n' "$2" >"$WORK/$1.toml"
    printf '%s' "$WORK/$1.toml"
}

problems() {
    launcher_problems "$(yq -p toml -o json -I0 <<<"$1")"
}

# a jq query against a resolved launcher
q() {
    jq -r "$2" <<<"$1"
}

section "launcher_problems"

assert_equals "a minimal launcher has no problems" "" \
    "$(problems $'description = "x"\n[[window]]\nname = "a"')"
assert_equals "missing description" "description: missing" \
    "$(problems $'[[window]]\nname = "a"')"
assert_equals "missing windows" "window: missing" \
    "$(problems 'description = "x"')"
assert_equals "session must be a string" "session: not a string" \
    "$(problems $'description = "x"\nsession = 3\n[[window]]')"
assert_equals "instance must be prompt or auto" "instance: not prompt or auto" \
    "$(problems $'description = "x"\ninstance = "ask"\n[[window]]')"
assert_equals "worktrees needs a dir and a session" $'worktrees.dir: missing\nworktrees: needs session' \
    "$(problems $'description = "x"\n[worktrees]\nprefix = "A"\n[[window]]')"
assert_equals "cmd and panes together" "window[1]: cmd and pane" \
    "$(problems $'description = "x"\n[[window]]\ncmd = "a"\n[[window.pane]]')"
assert_equals "the first pane takes no split" "window[1].pane[1]: the first pane has no split" \
    "$(problems $'description = "x"\n[[window]]\n[[window.pane]]\nsplit = "h"')"
assert_equals "split must be h or v" "window[1].pane[2].split: not h or v" \
    "$(problems $'description = "x"\n[[window]]\n[[window.pane]]\n[[window.pane]]\nsplit = "x"')"
assert_equals "of must name an earlier pane" "window[1].pane[2].of: not an earlier pane" \
    "$(problems $'description = "x"\n[[window]]\n[[window.pane]]\n[[window.pane]]\nsplit = "h"\nof = 2')"
assert_equals "size must be 1-99" "window[1].pane[2].size: not 1-99" \
    "$(problems $'description = "x"\n[[window]]\n[[window.pane]]\n[[window.pane]]\nsplit = "h"\nsize = 100')"

assert_equals "a window that isn't a table" "window[1]: not a table" \
    "$(launcher_problems '{"description":"x","window":["x"]}')"
assert_equals "a pane that isn't a table" "window[1].pane[2]: not a table" \
    "$(launcher_problems '{"description":"x","window":[{"pane":[{},"x"]}]}')"
assert_equals "a launcher that isn't a table" "not a table" "$(launcher_problems '[]')"
assert_equals "window and pane keys are type-checked" \
    $'window[1].name: not a string\nwindow[1].auto_rename: not a boolean\nwindow[1].dir: not a string\nwindow[1].pane[1].cmd: not a string\nwindow[1].pane[1].focus: not a boolean' \
    "$(launcher_problems '{"description":"x","window":[{"name":3,"auto_rename":"y","dir":5,"pane":[{"cmd":1,"focus":"y"}]}]}')"
assert_equals "a second focused window is an error" "window[2].focus: window[1] already has focus" \
    "$(problems $'description = "x"\n[[window]]\nfocus = true\n[[window]]\nfocus = true')"
assert_equals "a focused pane after a focused window is an error" "window[2].pane[2].focus: window[1] already has focus" \
    "$(problems $'description = "x"\n[[window]]\nfocus = true\n[[window]]\n[[window.pane]]\n[[window.pane]]\nsplit = "h"\nfocus = true')"
assert_equals "a second focused pane is an error" "window[1].pane[2].focus: window[1].pane[1] already has focus" \
    "$(problems $'description = "x"\n[[window]]\n[[window.pane]]\nfocus = true\n[[window.pane]]\nsplit = "h"\nfocus = true')"
assert_equals "focus = false is not a focus" "" \
    "$(problems $'description = "x"\n[[window]]\nfocus = false\n[[window]]\nfocus = true')"
assert_equals "the removed env overrides are errors" \
    $'root_env: no longer supported, set the path directly\nworktrees.env: no longer supported, set the path directly' \
    "$(problems $'description = "x"\nsession = "x"\nroot_env = "ACME_ROOT"\n[worktrees]\ndir = "w"\nenv = "ACME_WT"\n[[window]]')"
f=$(launcher typed $'description = "x"\n[[window]]\ndir = 5')
if out=$(launcher_resolve "$f" "$ROOT" 2>&1); then
    fail "resolve should refuse a non-string dir"
else
    [[ "$out" == *"window[1].dir: not a string"* ]] && pass "a wrong type is a problem line, not a jq error" ||
        fail "a wrong type should be reported as a problem (got: $out)"
fi

for f in "$DOTFILES_ROOT"/launchers/*.toml "$DOTFILES_ROOT/launchers/launcher.toml.template"; do
    assert_equals "repo launcher ${f##*/} has no problems" "" "$(launcher_problems "$(launcher_json "$f")")"
done

f=$(launcher broken $'session = "x"\n[[window]]')
if out=$(launcher_resolve "$f" 2>&1); then
    fail "resolve should refuse a launcher with problems"
else
    [[ "$out" == *"$f: description: missing"* ]] && pass "resolve names the file and key" ||
        fail "resolve error should name the file and key (got: $out)"
fi

section "launcher_resolve"

f=$(launcher acme "description = \"acme\"
session = \"acme\"
root = \"$ROOT\"

[[window]]
name = \"shell\"

[[window]]
name = \"edit\"
dir = \"web\"
cmd = \"nvim\"

[[window]]
dir = \"/tmp\"
[[window.pane]]
cmd = \"make dev\"
[[window.pane]]
split = \"h\"
dir = \"~\"
[[window.pane]]
split = \"v\"
of = 1
size = 30
dir = \"web\"
focus = true")
r=$(launcher_resolve "$f")
assert_equals "name comes from the file" "acme" "$(q "$r" .name)"
assert_equals "session defaults to the session key" "acme" "$(q "$r" .session)"
assert_equals "root resolves" "$ROOT" "$(q "$r" .root)"
assert_equals "an unnamed window has a null name" "null" "$(q "$r" '.windows[2].name')"
assert_equals "cmd shorthand becomes one pane" "nvim" "$(q "$r" '.windows[1].panes[0].cmd')"
assert_equals "a relative window dir sits under root" "$ROOT/web" "$(q "$r" '.windows[1].panes[0].dir')"
assert_equals "a pane without dir takes the window dir" "/tmp" "$(q "$r" '.windows[2].panes[0].dir')"
assert_equals "~ expands to HOME" "$HOME" "$(q "$r" '.windows[2].panes[1].dir')"
assert_equals "a relative pane dir sits under root" "$ROOT/web" "$(q "$r" '.windows[2].panes[2].dir')"
assert_equals "a window with no dir uses root" "$ROOT" "$(q "$r" '.windows[0].panes[0].dir')"
assert_equals "the first pane has no split" "null null null" \
    "$(q "$r" '.windows[2].panes[0] | "\(.split) \(.of) \(.size)"')"
assert_equals "of defaults to the previous pane, size stays null" "h 1 null" \
    "$(q "$r" '.windows[2].panes[1] | "\(.split) \(.of) \(.size)"')"
assert_equals "explicit of and size are kept" "v 1 30" \
    "$(q "$r" '.windows[2].panes[2] | "\(.split) \(.of) \(.size)"')"
assert_equals "a focused pane opens its window" "false false true" \
    "$(q "$r" '[.windows[].focus] | map(tostring) | join(" ")')"
assert_equals "a focused pane is that window's active pane" "false false true" \
    "$(q "$r" '[.windows[2].panes[].focus] | map(tostring) | join(" ")')"
assert_equals "other windows open on their first pane" "true" "$(q "$r" '.windows[0].panes[0].focus')"

f=$(launcher winfocus $'description = "x"\nsession = "winfocus"\n[[window]]\n[[window]]\nfocus = true\n[[window.pane]]\n[[window.pane]]\nsplit = "h"')
r=$(launcher_resolve "$f")
assert_equals "a focused window is the active window" "false true" \
    "$(q "$r" '[.windows[].focus] | map(tostring) | join(" ")')"
assert_equals "a focused window opens at its first pane" "true false" \
    "$(q "$r" '[.windows[1].panes[].focus] | map(tostring) | join(" ")')"

f=$(launcher plain $'description = "x"\nsession = "plain"\n[[window]]\n[[window]]')
r=$(launcher_resolve "$f")
assert_equals "root defaults to HOME" "$HOME" "$(q "$r" .root)"
assert_equals "the first window is focused by default" "true false" \
    "$(q "$r" '[.windows[].focus] | map(tostring) | join(" ")')"

f=$(launcher envroot "description = \"x\"
session = \"envroot\"
root = \"/nonexistent\"
[[window]]")
assert_equals "an env var named like an old override changes nothing" "" \
    "$(ACME_ROOT="$ROOT" launcher_resolve "$f" 2>/dev/null | jq -r .root)"
if out=$(launcher_resolve "$f" 2>&1); then
    fail "a missing root should fail"
else
    [[ "$out" == *"Project directory not found: /nonexistent"* ]] && pass "a missing root is an error" ||
        fail "missing root error (got: $out)"
fi
f=$(launcher instroot "description = \"x\"
session = \"envroot\"
root = \"$ROOT\"
[[window]]")
assert_equals "SESSION_NAME picks the instance" "envroot-2" \
    "$(SESSION_NAME=envroot-2 launcher_resolve "$f" | jq -r .session)"

WT="$WORK/acme-worktrees"
mkdir -p "$WT/ACME-12-fix-login" "$WT/feature"
f=$(launcher wt/acme "description = \"x\"
session = \"acme\"
root = \"$ROOT\"
instance = \"prompt\"
[worktrees]
dir = \"$WT\"
[[window]]")
wt_root() {
    SESSION_NAME="$1" launcher_resolve "$f" | jq -r .root
}
assert_equals "a numeric suffix opens <prefix>-<n>-*, prefix defaulting to the name in capitals" \
    "$WT/ACME-12-fix-login" "$(wt_root acme-12)"
assert_equals "another suffix opens the worktree named after it" "$WT/feature" "$(wt_root acme-feature)"
assert_equals "no matching worktree keeps root" "$ROOT" "$(wt_root acme-99)"
assert_equals "the base session keeps root" "$ROOT" "$(wt_root acme)"

f=$(launcher wt2/acme "description = \"x\"
session = \"acme\"
root = \"$ROOT\"
[worktrees]
dir = \"$WT\"
prefix = \"fix\"
[[window]]")
mkdir -p "$WT/fix-7-typo"
assert_equals "an explicit prefix is used" "$WT/fix-7-typo" \
    "$(SESSION_NAME=acme-7 launcher_resolve "$f" | jq -r .root)"

f=$(launcher placeholder "description = \"x\"
session = \"acme\"
root = \"$ROOT\"
[[window]]
cmd = \"j {SESSION} {SESSION}\"")
assert_equals "{SESSION} is the instance name in capitals, everywhere in the command" "j ACME-12 ACME-12" \
    "$(SESSION_NAME=acme-12 launcher_resolve "$f" | jq -r '.windows[0].panes[0].cmd')"
assert_equals "the base session fills in its own name" "j ACME ACME" \
    "$(launcher_resolve "$f" | jq -r '.windows[0].panes[0].cmd')"

f=$(launcher dirlaunch $'description = "x"\n[[window]]')
mkdir -p "$WORK/My Project.v2"
r=$(launcher_resolve "$f" "$WORK/My Project.v2")
assert_equals "a directory launcher roots at its argument" "$WORK/My Project.v2" "$(q "$r" .root)"
assert_equals "its session is the sanitised directory name" "My-Project-v2" "$(q "$r" .session)"
assert_failure "a directory launcher needs its argument" launcher_resolve "$f"

section "launcher_write"

out="$WORK/written.toml"
rm -f "$out"
launcher_write "$out" '{"description":"x","session":"w","window":[{"name":"a"},{"name":"b","pane":[{"cmd":"p1"},{"split":"h"}]}]}'
assert_equals "a new file round-trips" "x w a b" \
    "$(yq -p toml -o json "$out" | jq -r '"\(.description) \(.session) \(.window[0].name) \(.window[1].name)"')"
assert_equals "a blank line precedes each window" "2" \
    "$(grep -B1 -x '\[\[window\]\]' "$out" | grep -c '^$' | tr -d ' ')"

cat >"$out" <<'TOML'
# keep this header
description = "old" # inline note
session = "w"

[[window]]
# about the shell window
name = "shell"
cmd = "a" # runs a

[[window]]
name = "gone"
TOML
launcher_write "$out" '{"description":"new","session":"w","window":[{"name":"shell","cmd":"b"}]}'
assert_success "the header comment survives" grep -qx '# keep this header' "$out"
assert_success "an inline comment survives a changed value" grep -q '^description = "new" *# inline note$' "$out"
assert_success "a window comment survives" grep -qx '# about the shell window' "$out"
assert_success "a changed cmd keeps its comment" grep -q '^cmd = "b" *# runs a$' "$out"
assert_failure "a removed window is deleted" grep -q 'gone' "$out"
assert_equals "one window remains" "1" "$(yq -p toml -o json "$out" | jq '.window | length')"

# empty tables: a shell pane or window with nothing set is still an entry
write_and_read() {
    printf '%s\n' "$1" >"$out"
    launcher_write "$out" "$2"
    yq -p toml -o json -I0 "$out"
}
base=$'description = "x"\nsession = "w"\n\n[[window]]\nname = "a"'
assert_equals "an empty first pane is written as a pane" '[{},{"split":"h"}]' \
    "$(write_and_read "$base" '{"description":"x","session":"w","window":[{"name":"a","pane":[{},{"split":"h"}]}]}' | jq -c '.window[0].pane')"
assert_equals "a trailing empty window is kept" '[{"name":"a"},{}]' \
    "$(write_and_read "$base" '{"description":"x","session":"w","window":[{"name":"a"},{}]}' | jq -c '.window')"
assert_equals "an empty window in the middle is kept" '[{"name":"a"},{},{"name":"c"}]' \
    "$(write_and_read "$base" '{"description":"x","session":"w","window":[{"name":"a"},{},{"name":"c"}]}' | jq -c '.window')"
assert_success "a written file with empty entries resolves" launcher_resolve "$out"
assert_equals "shrinking drops windows and panes" '[{"name":"a","pane":[{"cmd":"x"},{"split":"v"}]}]' \
    "$(write_and_read $'description = "x"\nsession = "w"\n[[window]]\nname = "a"\n[[window.pane]]\ncmd = "x"\n[[window.pane]]\nsplit = "h"\n[[window.pane]]\nsplit = "h"\n[[window]]\nname = "b"' \
        '{"description":"x","session":"w","window":[{"name":"a","pane":[{"cmd":"x"},{"split":"v"}]}]}' | jq -c '.window')"

# comments yq drops on its own (after a key, above a window header) come back
cat >"$out" <<'TOML'
description = "x"
# a note after a key

# above the first window
[[window]]
name = "a"

# above the second window
[[window]]
name = "b"
TOML
launcher_write "$out" '{"description":"y","window":[{"name":"a"},{"name":"b2"},{}]}'
for c in '# a note after a key' '# above the first window' '# above the second window'; do
    assert_equals "comment kept once: $c" "1" "$(grep -cxF "$c" "$out" | tr -d ' ')"
done
assert_equals "the second window comment still sits above its header" "# above the second window" \
    "$(grep -B2 -x 'name = "b2"' "$out" | head -1)"
assert_equals "the windows are written" '["a","b2",null]' "$(yq -p toml -o json -I0 "$out" | jq -c '[.window[].name]')"

section "launcher_field"

field_dir="$WORK/fields"
mkdir -p "$field_dir"
printf '%s\n' 'description = """two' 'lines"""' '[[window]]' >"$field_dir/multi.toml"
printf '%s\n' 'description = "one"' '[[window]]' >"$field_dir/one.toml"
printf 'not = [toml\n' >"$field_dir/broken.toml"
assert_equals "one row per parseable file, values on one line" $'multi\ttwo lines\none\tone' \
    "$(launcher_field "$field_dir" description | sort)"

section "rex payload"

f=$(launcher rexy "description = \"x\"
session = \"rexy\"
root = \"$ROOT\"
[[window]]
name = \"dev\"
[[window.pane]]
cmd = \"make dev\"
[[window.pane]]
split = \"h\"
[[window.pane]]
split = \"v\"
size = 30
focus = true
[[window]]
name = \"auto\"
auto_rename = true
[[window]]
cmd = \"nvim\"")
r=$(launcher_resolve "$f")
p=$(rex_payload "$r")
assert_equals "the session label is the session name" "rexy" "$(q "$p" .label)"
assert_equals "an h split is horizontal, an even split is 0.5" "horizontal 0.5" \
    "$(q "$p" '.initial_windows[0].layout.split | "\(.direction) \(.ratio)"')"
assert_equals "splitting pane 2 nests under the after side, size 30 is ratio 0.7" "vertical 0.7" \
    "$(q "$p" '.initial_windows[0].layout.split.after.split | "\(.direction) \(.ratio)"')"
assert_equals "a named window's name is its tab label" "dev" "$(q "$p" '.initial_windows[0].window_label')"
assert_equals "blocks carry no label" "null" "$(q "$p" '.initial_windows[0].layout.split.before.block.label')"
assert_equals "a command is sent with a return" "make dev\r" \
    "$(q "$p" '.initial_windows[0].layout.split.before.block.options.initial_input | gsub("\r"; "\\r")')"
assert_equals "a block without a command has no initial_input" "null" \
    "$(q "$p" '.initial_windows[0].layout.split.after.split.before.block.options.initial_input')"
assert_equals "blocks start in their dir" "$ROOT" "$(q "$p" '.initial_windows[0].layout.split.before.block.options.cwd')"
assert_equals "an auto-rename window has no label" "null" "$(q "$p" '.initial_windows[1].window_label')"
assert_equals "an unnamed window has no label" "null" "$(q "$p" '.initial_windows[2].window_label')"
assert_equals "focus order puts the active window last, by block index" $'1 0\n2 0\n0 2' "$(_rex_focus_order "$r")"

f=$(launcher rexpane $'description = "x"\nsession = "rexpane"\n[[window]]\n[[window]]\n[[window.pane]]\n[[window.pane]]\nsplit = "h"\nfocus = true')
assert_equals "a focused pane in a later window is focused last" $'0 0\n1 1' "$(_rex_focus_order "$(launcher_resolve "$f")")"

section "tmux backend"

setup_test_server
tmux_focus_session() { :; }

f=$(launcher tmuxy "description = \"x\"
session = \"tmuxy\"
root = \"$ROOT\"
[[window]]
name = \"dev\"
[[window.pane]]
[[window.pane]]
split = \"h\"
dir = \"web\"
[[window.pane]]
split = \"v\"
size = 30
focus = true
[[window]]
name = \"edit\"
auto_rename = true
[[window]]
cmd = \"printf ok\"")
tmux_launch "$(launcher_resolve "$f")"
sleep 0.3
windows=$(tmux list-windows -t =tmuxy -F '#{window_name}|#{window_active}|#{automatic-rename}')
assert_equals "the focused pane's window is active" "dev|1|0" "$(sed -n 1p <<<"$windows")"
assert_equals "a named window handed to automatic-rename" "0|1" "$(sed -n 2p <<<"$windows" | cut -d'|' -f2-)"
assert_equals "unnamed window keeps automatic-rename" "1" "$(sed -n 3p <<<"$windows" | cut -d'|' -f3)"
pane_rows=$(tmux list-panes -t =tmuxy:0 -F '#{pane_left},#{pane_top} #{pane_width}x#{pane_height} #{pane_active} #{pane_start_path}')
assert_equals "three panes in the first window" "3" "$(wc -l <<<"$pane_rows" | tr -d ' ')"
assert_equals "pane 2 sits right of pane 1 in its dir" "0 $ROOT/web" "$(sed -n 2p <<<"$pane_rows" | awk '{print $3, $4}')"
pane2_top=$(sed -n 2p <<<"$pane_rows" | cut -d, -f2 | cut -d' ' -f1)
pane3_top=$(sed -n 3p <<<"$pane_rows" | cut -d, -f2 | cut -d' ' -f1)
[[ "$pane3_top" -gt "$pane2_top" ]] && pass "pane 3 is stacked below pane 2" || fail "pane 3 should be below pane 2"
assert_equals "the focus pane is active" "1" "$(sed -n 3p <<<"$pane_rows" | awk '{print $3}')"
assert_equals "the session carries the @launcher tag" "tmuxy" "$(tmux show-options -qv -t =tmuxy: @launcher)"
assert_success "a second launch reuses the session" tmux_launch "$(launcher_resolve "$f")"
assert_equals "still three windows" "3" "$(tmux list-windows -t =tmuxy | wc -l | tr -d ' ')"

cleanup_test_server

print_summary
[[ $FAIL -eq 0 ]]
