#!/usr/bin/env bash
# shellcheck disable=SC2088 # ~ paths are literal TOML values
# shellcheck disable=SC2030,SC2031 # each build sets its socket in a subshell
set -euo pipefail

# tests scripts/migrations/0.2.158-launchers-to-toml.sh against bash launchers
# in each shape it meets, then builds each converted launcher with the tmux
# backend and compares it with the bash original. delete together with the
# migration

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "$SCRIPT_DIR/_test-helpers.sh"

MIGRATION="$DOTFILES_ROOT/scripts/migrations/0.2.158-launchers-to-toml.sh"

run_migration() {
    XDG_CONFIG_HOME="$TEST_HOME/.config" XDG_DATA_HOME="$TEST_HOME/.local/share" bash "$MIGRATION"
}

setup_sandbox
LAUNCHERS="$TEST_HOME/.config/dotfiles/launchers"
BACKUPS="$TEST_HOME/.local/share/dotfiles/launcher-backups/bash"

section "No launchers directory"

if output=$(run_migration); then
    pass "exits 0 without a launchers directory"
else
    fail "should exit 0 without a launchers directory"
fi
assert_equals "says why it skipped" "    No user launchers directory, nothing to convert" "$output"

mkdir -p "$LAUNCHERS"

# wizard output: staged defaults, worktrees, a pane-id split window, a window
# handed back to automatic-rename. its root doesn't exist on this machine
cat >"$LAUNCHERS/acme" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

# @description: Development setup for acme
# @instance: prompt
# @generated

SESSION="${SESSION_NAME:-acme}"
_ACME_WORKTREES_DEFAULT="$HOME/code/acme-worktrees"
_ACME_ROOT_DEFAULT="$HOME/code/acme"
WORKTREES_DIR="${ACME_WORKTREES:-$_ACME_WORKTREES_DEFAULT}"
BASE_DIR="${ACME_ROOT:-$_ACME_ROOT_DEFAULT}"
WORKTREES_DIR="${WORKTREES_DIR/#\~/$HOME}"
BASE_DIR="${BASE_DIR/#\~/$HOME}"
PROJECT_DIR="$BASE_DIR"
if [[ "$SESSION" =~ -([0-9]+)$ ]]; then
    ticket_num="${BASH_REMATCH[1]}"
    for wt in "$WORKTREES_DIR"/ac-"${ticket_num}"-*; do
        if [[ -d "$wt" ]]; then
            PROJECT_DIR="$wt"
            break
        fi
    done
fi
if [[ ! -d "$PROJECT_DIR" ]]; then
    echo "Error: Project directory not found: $PROJECT_DIR" >&2
    exit 1
fi
if tmux has-session -t "=$SESSION" 2>/dev/null; then
    tmux switch-client -t "=$SESSION"
    exit 0
fi
_cols=$(tmux display-message -p '#{client_width}' 2>/dev/null || true)
_rows=$(tmux display-message -p '#{client_height}' 2>/dev/null || true)
[[ -n "$_cols" ]] || _cols=80
[[ -n "$_rows" ]] || _rows=24
tmux new-session -d -s "$SESSION" -n "zsh" -c "$PROJECT_DIR" -x "$_cols" -y "$_rows"
tmux set-option -t "=$SESSION:" @launcher acme
p1=$(tmux display-message -p -t "$SESSION:zsh" '#{pane_id}')
p2=$(tmux split-window -d -t "$p1" -h -l 50% -c "$PROJECT_DIR" -P -F '#{pane_id}')
p3=$(tmux split-window -d -t "$p2" -v -l 49% -c "$PROJECT_DIR/web" -P -F '#{pane_id}')
tmux send-keys -t "$p2" 'make dev' Enter
tmux send-keys -t "$p3" 'make status' Enter
tmux new-window -t "$SESSION:" -n "nvim" -c "$PROJECT_DIR"
tmux send-keys -t "$SESSION:nvim" 'nvim' Enter
tmux new-window -t "$SESSION:" -n "agent" -c "$PROJECT_DIR"
tmux send-keys -t "$SESSION:agent" 'claude' Enter
tmux set-option -w -t "$SESSION:agent" automatic-rename on
tmux select-window -t "$SESSION:1"
tmux select-pane -t "$SESSION:1.1"
tmux switch-client -t "=$SESSION"
EOF

# hand-written: nested default, pane-index targets, an unnamed window by id
cat >"$LAUNCHERS/acme-web" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
# @description: Daily acme web work
SESSION="${SESSION_NAME:-acme-web}"
BASE_DIR="${ACME_WEB_ROOT:-${BASE_DIR:-$HOME/code/acme-web}}"
PROJECT_DIR="$BASE_DIR"
if tmux has-session -t "=$SESSION" 2>/dev/null; then
    tmux switch-client -t "=$SESSION"
    exit 0
fi
tmux new-session -d -s "$SESSION" -n "dev" -c "$PROJECT_DIR"
tmux split-window -h -t "$SESSION:dev.1" -c "$PROJECT_DIR"
tmux split-window -v -t "$SESSION:dev.2" -c "$PROJECT_DIR"
tmux send-keys -t "$SESSION:dev.1" 'make status' Enter
tmux send-keys -t "$SESSION:dev.2" 'make web-up' Enter
tmux new-window -t "$SESSION:" -n "nvim" -c "$PROJECT_DIR"
tmux send-keys -t "$SESSION:nvim" 'v' Enter
code_win=$(tmux new-window -t "$SESSION:" -P -F '#{window_id}' -c "$PROJECT_DIR")
tmux send-keys -t "$code_win" 'claude' Enter
tmux select-pane -t "$SESSION:dev.1"
tmux select-window -t "$code_win"
tmux switch-client -t "=$SESSION"
EOF

# a split without -d (the new pane stays active) and a quoted path in a command
cat >"$LAUNCHERS/tools" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
# @description: Saved from the 'tools' session
SESSION="${SESSION_NAME:-tools}"
_TOOLS_ROOT_DEFAULT="$HOME/code/tools/"
PROJECT_DIR="${TOOLS_ROOT:-$_TOOLS_ROOT_DEFAULT}"
if tmux has-session -t "=$SESSION" 2>/dev/null; then exit 0; fi
tmux new-session -d -s "$SESSION" -n "zsh" -c "$PROJECT_DIR"
tmux new-window -t "$SESSION:" -n "nvim" -c "$PROJECT_DIR"
tmux split-window -t "$SESSION:nvim" -h -c "$PROJECT_DIR"
tmux send-keys -t "$SESSION:nvim.1" 'nvim' Enter
tmux send-keys -t "$SESSION:nvim.2" 'claude -r' Enter
tmux new-window -t "$SESSION:" -n "todo" -c "$PROJECT_DIR"
tmux send-keys -t "$SESSION:todo" 'nvim '\''notes/my tasks.md'\''' Enter
tmux select-window -t "$SESSION:nvim"
tmux switch-client -t "=$SESSION"
EOF

# one window rooted at HOME
cat >"$LAUNCHERS/cron" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
# @description: Launch lazycron from ~
SESSION="${SESSION_NAME:-cron}"
PROJECT_DIR="${CRON_ROOT:-$HOME}"
if tmux has-session -t "=$SESSION" 2>/dev/null; then exit 0; fi
tmux new-session -d -s "$SESSION" -n "cron" -c "$PROJECT_DIR"
tmux send-keys -t "$SESSION:cron" 'lazycron' Enter
tmux select-window -t "$SESSION:1"
tmux switch-client -t "=$SESSION"
EOF

# a launcher using a tmux command the recorder doesn't know
cat >"$LAUNCHERS/odd" <<'EOF'
#!/usr/bin/env bash
# @description: Resizes a pane
SESSION="${SESSION_NAME:-odd}"
tmux new-session -d -s "$SESSION" -n "a" -c "$HOME"
tmux resize-pane -t "$SESSION:a" -Z
tmux switch-client -t "=$SESSION"
EOF

# send-keys with two key arguments: the recorder can't tell how they combine
cat >"$LAUNCHERS/keys" <<'EOF'
#!/usr/bin/env bash
# @description: Types two keys
SESSION="${SESSION_NAME:-keys}"
tmux new-session -d -s "$SESSION" -n "a" -c "$HOME"
tmux send-keys -t "$SESSION:a" 'make' ' test' Enter
tmux switch-client -t "=$SESSION"
EOF

# a pane in the worktrees dir: during the run that's a scratch dir, so it
# can't be written down as a path
cat >"$LAUNCHERS/wtpane" <<'EOF'
#!/usr/bin/env bash
# @description: Opens the worktrees dir
SESSION="${SESSION_NAME:-wtpane}"
WORKTREES_DIR="${WTPANE_WORKTREES:-$HOME/code/wt}"
PROJECT_DIR="${WTPANE_ROOT:-$HOME/code/wtpane}"
tmux new-session -d -s "$SESSION" -n "a" -c "$PROJECT_DIR"
tmux new-window -t "$SESSION:" -n "b" -c "$WORKTREES_DIR"
tmux switch-client -t "=$SESSION"
EOF

# its root env var is set when the migration runs: the value becomes root
cat >"$LAUNCHERS/baked" <<'EOF'
#!/usr/bin/env bash
# @description: Rooted by an env var on this machine
SESSION="${SESSION_NAME:-baked}"
PROJECT_DIR="${BAKED_ROOT:-$HOME/code/baked}"
tmux new-session -d -s "$SESSION" -n "a" -c "$PROJECT_DIR"
tmux switch-client -t "=$SESSION"
EOF

# a command built from the session name: a ticket key per instance
cat >"$LAUNCHERS/tickets" <<'EOF'
#!/usr/bin/env bash
# @description: Opens the instance's ticket
# @instance: prompt
SESSION="${SESSION_NAME:-tickets}"
tmux new-session -d -s "$SESSION" -n "jira" -c "$HOME"
tmux send-keys -t "$SESSION:jira" "j ${SESSION^^}" Enter
tmux switch-client -t "=$SESSION"
EOF

# a window named after the session: nothing in TOML can say that
cat >"$LAUNCHERS/perwin" <<'EOF'
#!/usr/bin/env bash
# @description: Names its window after the session
SESSION="${SESSION_NAME:-perwin}"
tmux new-session -d -s "$SESSION" -n "$SESSION" -c "$HOME"
tmux switch-client -t "=$SESSION"
EOF

# runs something besides tmux, which recording it must not do
cat >"$LAUNCHERS/sidefx" <<EOF
#!/usr/bin/env bash
# @description: Makes a directory first
SESSION="\${SESSION_NAME:-sidefx}"
mkdir -p "$TEST_HOME/made-by-sidefx"
tmux new-session -d -s "\$SESSION" -n "a" -c "\$HOME"
tmux switch-client -t "=\$SESSION"
EOF

# not a launcher: no @description
printf '#!/usr/bin/env bash\necho hello\n' >"$LAUNCHERS/helper"
# already converted: a bash file next to its .toml stays as it is
printf '#!/usr/bin/env bash\n# @description: done\ntmux new-session -d -s done\n' >"$LAUNCHERS/done"
printf 'description = "done"\nsession = "done"\n\n[[window]]\n' >"$LAUNCHERS/done.toml"

chmod 755 "$LAUNCHERS"/*
for f in "$LAUNCHERS"/*; do cp "$f" "$TEST_HOME/${f##*/}.before"; done

section "First run"

output=$(BAKED_ROOT="$TEST_HOME/elsewhere" run_migration)

for name in acme acme-web tools cron tickets baked; do
    if [[ -f "$LAUNCHERS/$name.toml" && ! -e "$LAUNCHERS/$name" ]]; then
        pass "$name converts and its bash leaves the launchers dir"
    else
        fail "$name should convert to $name.toml"
    fi
    if cmp -s "$TEST_HOME/$name.before" "$BACKUPS/$name"; then
        pass "$name's bash is backed up unchanged"
    else
        fail "$name's bash should be in $BACKUPS"
    fi
done

toml() {
    yq -p toml -o json "$LAUNCHERS/$1.toml" | jq -r "$2"
}
assert_equals "acme keeps description, session and instance" "Development setup for acme|acme|prompt" \
    "$(toml acme '"\(.description)|\(.session)|\(.instance)"')"
assert_equals "acme keeps its root though it's missing, and no env key" "~/code/acme|null" \
    "$(toml acme '"\(.root)|\(.root_env)"')"
assert_equals "acme keeps its worktrees, with no env key" "~/code/acme-worktrees|null|ac" \
    "$(toml acme '.worktrees | "\(.dir)|\(.env)|\(.prefix)"')"
assert_equals "a root env var set during the migration becomes root" "~/elsewhere|null" \
    "$(toml baked '"\(.root)|\(.root_env)"')"
assert_equals "acme's split window has three panes" "3" "$(toml acme '.window[0].pane | length')"
assert_equals "an explicit 50% is kept, a pane dir under root is relative" "h|50|null|v|49|web" \
    "$(toml acme '.window[0].pane[1:] | map("\(.split)|\(.size)|\(.dir)") | join("|")')"
assert_equals "an auto-renamed window keeps its name" "agent|true" \
    "$(toml acme '.window[2] | "\(.name)|\(.auto_rename)"')"
assert_equals "a nested default gives the inner path" "~/code/acme-web|null" \
    "$(toml acme-web '"\(.root)|\(.root_env)"')"
assert_equals "a split without size stays an even split" "h|null|v|null" \
    "$(toml acme-web '.window[0].pane[1:] | map("\(.split)|\(.size)") | join("|")')"
assert_equals "an unnamed window has no name and takes focus" "null|true|claude" \
    "$(toml acme-web '.window[2] | "\(.name)|\(.focus)|\(.cmd)"')"
assert_equals "a split without -d in the active window focuses the new pane" "true" "$(toml tools '.window[1].pane[1].focus')"
assert_equals "the focused pane is the only focus" "1" \
    "$(toml tools '[.. | objects | select(.focus == true)] | length')"
assert_equals "a launcher left on its first window and pane has no focus" "0" \
    "$(toml cron '[.. | objects | select(has("focus"))] | length')"
assert_equals "a quoted command survives" "nvim 'notes/my tasks.md'" "$(toml tools '.window[2].cmd')"
assert_equals "a trailing slash on root is dropped" "~/code/tools" "$(toml tools .root)"
assert_equals "a HOME root is left as the default" "null|null" "$(toml cron '"\(.root)|\(.root_env)"')"
assert_equals "a command naming the session in capitals gets {SESSION}" "j {SESSION}" "$(toml tickets '.window[0].cmd')"

for name in odd keys wtpane perwin sidefx helper "done"; do
    if cmp -s "$TEST_HOME/$name.before" "$LAUNCHERS/$name"; then
        pass "$name is left untouched"
    else
        fail "$name should be left untouched"
    fi
done
[[ ! -e "$LAUNCHERS/odd.toml" ]] && pass "odd gets no .toml" || fail "odd should get no .toml"
if cmp -s "$TEST_HOME/done.toml.before" "$LAUNCHERS/done.toml"; then
    pass "an existing .toml is left untouched"
else
    fail "an existing .toml should be left untouched"
fi

if [[ "$output" == *"Converted 6 launcher(s) to TOML: acme acme-web baked cron tickets tools"* ]]; then
    pass "reports what it converted"
else
    fail "should report 6 converted launchers (got: $output)"
fi
if [[ "$output" == *"perwin (the windows depend on the session name)"* ]]; then
    pass "a layout that depends on the session name is left as bash"
else
    fail "perwin should be left as bash (got: $output)"
fi
if [[ "$output" == *"sidefx (runs mkdir, which the migration won't run)"* ]]; then
    pass "a launcher that runs other programs is left as bash"
else
    fail "sidefx should be left as bash (got: $output)"
fi
[[ ! -e "$TEST_HOME/made-by-sidefx" ]] && pass "recording runs nothing but tmux" ||
    fail "the migration ran sidefx's mkdir"
if [[ "$output" == *"Left as bash, the picker no longer lists it: odd (tmux resize-pane)"* ]]; then
    pass "lists the launcher it couldn't convert, with the reason"
else
    fail "should list odd with its reason (got: $output)"
fi
if [[ "$output" == *"keys (send-keys with 2 key arguments)"* ]]; then
    pass "send-keys with several key arguments is left as bash"
else
    fail "keys should be left as bash (got: $output)"
fi
if [[ "$output" == *"wtpane (a pane starts outside the project root)"* ]]; then
    pass "a pane in a scratch dir is left as bash, not written with a temp path"
else
    fail "wtpane should be left as bash (got: $output)"
fi

section "Second run (idempotent)"

snapshot=$(cat "$LAUNCHERS"/* "$BACKUPS"/*)
output=$(run_migration)
if [[ "$(cat "$LAUNCHERS"/* "$BACKUPS"/*)" == "$snapshot" ]]; then
    pass "second run changes nothing"
else
    fail "second run should change nothing"
fi
if [[ "$output" == *"Left as bash, the picker no longer lists it: odd"* && "$output" != *Converted* ]]; then
    pass "second run converts nothing and still lists odd"
else
    fail "second run should only list odd (got: $output)"
fi

section "Converted launchers build the same session"

if ! command -v tmux &>/dev/null; then
    skip "tmux not installed"
else
    # shellcheck source=tmux/scripts/_lib/launcher-data.sh
    source "$DOTFILES_ROOT/tmux/scripts/_lib/launcher-data.sh"
    # shellcheck source=tmux/scripts/_lib/launcher-tmux.sh
    source "$DOTFILES_ROOT/tmux/scripts/_lib/launcher-tmux.sh"
    tmux_focus_session() { :; }

    # windows and panes of every session but the bootstrap one; an
    # automatic-rename window's name depends on what runs in it, and only the
    # active window's active pane carries over
    snap() {
        command tmux -L "$1" list-windows -a \
            -F '#{session_name} #{window_index} #{?automatic-rename,AUTO,#{window_name}} #{window_active}' | grep -v '^keep '
        command tmux -L "$1" list-panes -a \
            -F '#{session_name} #{window_index}.#{pane_index} #{pane_left},#{pane_top} #{pane_width}x#{pane_height} #{?window_active,#{pane_active},-} #{pane_start_path}' |
            grep -v '^keep '
    }
    server() {
        command tmux -L "$1" -f /dev/null new-session -d -s keep -x 200 -y 50
        command tmux -L "$1" set -g base-index 1
        command tmux -L "$1" set -g pane-base-index 1
    }

    for pair in acme:ACME_ROOT acme-web:ACME_WEB_ROOT tools:TOOLS_ROOT cron:CRON_ROOT; do
        name="${pair%%:*}" env_var="${pair#*:}"
        root=$(mktemp -d)
        mkdir -p "$root/web"
        a="mig-bash-$$" b="mig-toml-$$"
        server "$a"
        server "$b"
        (
            export "$env_var=$root" TMUX_TEST_SOCKET="$a" TMUX=outside
            bash "$BACKUPS/$name" >/dev/null 2>&1 || true
        )
        # the TOML rooted where the bash run's env var pointed
        mkdir -p "$TEST_DIR/rooted"
        yq -p toml -o toml ".root = \"$root\"" "$LAUNCHERS/$name.toml" >"$TEST_DIR/rooted/$name.toml"
        (
            export TMUX_TEST_SOCKET="$b"
            unset TMUX
            tmux_launch "$(launcher_resolve "$TEST_DIR/rooted/$name.toml")"
        )
        sleep 0.2
        if diff <(snap "$a" | sed "s|$root|ROOT|g") <(snap "$b" | sed "s|$root|ROOT|g") >"$TEST_DIR/$name.diff"; then
            pass "$name builds the same windows and panes"
        else
            fail "$name differs from its bash original: $(tr '\n' ' ' <"$TEST_DIR/$name.diff")"
        fi
        command tmux -L "$a" kill-server 2>/dev/null || true
        command tmux -L "$b" kill-server 2>/dev/null || true
        rm -rf "$root"
    done
fi

cleanup_sandbox

print_summary

if [[ $FAIL -gt 0 ]]; then
    exit 1
fi
