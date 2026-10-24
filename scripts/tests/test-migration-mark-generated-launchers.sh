#!/usr/bin/env bash
set -euo pipefail

# tests scripts/migrations/0.2.153-mark-generated-launchers.sh against
# launchers in each shape it meets. delete together with the migration

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "$SCRIPT_DIR/_test-helpers.sh"

MIGRATION="$DOTFILES_ROOT/scripts/migrations/0.2.153-mark-generated-launchers.sh"

# a launcher as the wizard wrote it before 0.2.153. $1 = name, $2 = "inline"
# for the old `${VAR:-default}` root form, $3 = "instance" for @instance: prompt
write_wizard_launcher() {
    local name="$1" root_form="${2:-staged}" instance="${3:-}"
    local upper
    upper=$(printf '%s' "$name" | tr '[:lower:]' '[:upper:]' | tr '.-' '_')
    {
        printf '#!/usr/bin/env bash\nset -euo pipefail\n\n'
        printf '# @description: %s project session\n' "$name"
        [[ "$instance" == "instance" ]] && printf '# @instance: prompt\n'
        printf '\n# Help flag handling\n'
        printf 'if [[ "${1:-}" == "--help" ]]; then\n    cat << '\''EOF'\''\n'
        printf '%s - Project tmux session launcher\nEOF\n    exit 0\nfi\n\n' "$name"
        printf 'SESSION="${SESSION_NAME:-%s}"\n' "$name"
        if [[ "$root_form" == "inline" ]]; then
            printf 'PROJECT_DIR="${%s_ROOT:-$HOME/src/%s}"\n' "$upper" "$name"
        else
            printf '_%s_ROOT_DEFAULT="$HOME/src/%s"\n' "$upper" "$name"
            printf 'PROJECT_DIR="${%s_ROOT:-$_%s_ROOT_DEFAULT}"\n' "$upper" "$upper"
        fi
        printf '\n# Window 1: dev\n'
        printf 'tmux new-session -d -s "$SESSION" -n "dev" -c "$PROJECT_DIR"\n'
        printf '\n# Window 2: edit\n'
        printf 'tmux new-window -t "$SESSION:" -n "edit" -c "$PROJECT_DIR"\n'
        printf '\n# Select first window\ntmux select-window -t "$SESSION:1"\n'
    } >"$LAUNCHERS/$name"
    chmod 755 "$LAUNCHERS/$name"
}

run_migration() {
    XDG_CONFIG_HOME="$TEST_HOME/.config" bash "$MIGRATION"
}

setup_sandbox
LAUNCHERS="$TEST_HOME/.config/dotfiles/launchers"

section "No launchers directory"

if output=$(run_migration); then
    pass "exits 0 without a launchers directory"
else
    fail "should exit 0 without a launchers directory"
fi
assert_equals "says why it skipped" "    No user launchers directory — skipping @generated backfill" "$output"

mkdir -p "$LAUNCHERS"
write_wizard_launcher staged
write_wizard_launcher old-inline inline
write_wizard_launcher with-instance staged instance
# a wizard launcher later edited by hand: the footer was rewritten
write_wizard_launcher edited
sed -i.bak '/^# Select first window$/d' "$LAUNCHERS/edited" && rm -f "$LAUNCHERS/edited.bak"
# a hand-written launcher (like the repo's own)
printf '#!/usr/bin/env bash\n# @description: Runs btop\ntmux new-session -d -s btop\n' >"$LAUNCHERS/hand"
# a launcher marked by a newer wizard: already has both lines
write_wizard_launcher current
sed -i.bak -e 's/^# @description: .*/&\n# @generated/' \
    -e 's/^tmux new-session .*/&\ntmux set-option -t "=$SESSION:" @launcher current/' "$LAUNCHERS/current" &&
    rm -f "$LAUNCHERS/current.bak"
cp "$LAUNCHERS/current" "$TEST_HOME/current.before"
cp "$LAUNCHERS/edited" "$TEST_HOME/edited.before"
cp "$LAUNCHERS/hand" "$TEST_HOME/hand.before"

section "First run"

output=$(run_migration)

for name in staged old-inline with-instance; do
    if grep -qxF '# @generated' "$LAUNCHERS/$name"; then
        pass "$name gets the @generated marker"
    else
        fail "$name should get the @generated marker"
    fi
    tag_line=$(grep -n '@launcher' "$LAUNCHERS/$name" || true)
    session_line=$(grep -n '^tmux new-session' "$LAUNCHERS/$name" | cut -d: -f1)
    if [[ "$tag_line" == "$((session_line + 1)):tmux set-option -t \"=\$SESSION:\" @launcher $name" ]]; then
        pass "$name gets its @launcher tag right after new-session"
    else
        fail "$name should get @launcher $name after new-session (got: $tag_line)"
    fi
    if bash -n "$LAUNCHERS/$name"; then
        pass "$name is still valid bash"
    else
        fail "$name has a syntax error after the migration"
    fi
done

assert_equals "marker follows @description" "# @generated" \
    "$(grep -A1 '^# @description:' "$LAUNCHERS/staged" | tail -1)"
assert_equals "marker follows @instance when present" "# @generated" \
    "$(grep -A1 '^# @instance:' "$LAUNCHERS/with-instance" | tail -1)"
assert_equals "@instance stays right after @description" "# @instance: prompt" \
    "$(grep -A1 '^# @description:' "$LAUNCHERS/with-instance" | tail -1)"

perm=$(stat -c '%a' "$LAUNCHERS/staged" 2>/dev/null || stat -f '%Lp' "$LAUNCHERS/staged")
assert_equals "file mode is kept" "755" "$perm"

if cmp -s "$TEST_HOME/edited.before" "$LAUNCHERS/edited"; then
    pass "hand-edited wizard launcher is left untouched"
else
    fail "hand-edited wizard launcher should be left untouched"
fi
if cmp -s "$TEST_HOME/hand.before" "$LAUNCHERS/hand"; then
    pass "hand-written launcher is left untouched"
else
    fail "hand-written launcher should be left untouched"
fi
if cmp -s "$TEST_HOME/current.before" "$LAUNCHERS/current"; then
    pass "already-marked launcher is left untouched"
else
    fail "already-marked launcher should be left untouched"
fi

if [[ "$output" == *"Marked 3 launcher(s)"* ]]; then
    pass "reports how many launchers it marked"
else
    fail "should report 3 marked launchers (got: $output)"
fi
if [[ "$output" == *"Left 2 launcher(s) as hand-written: edited hand"$'\n'* ]]; then
    pass "lists the launchers it left alone"
else
    fail "should list edited and hand as left alone (got: $output)"
fi

section "Second run (idempotent)"

snapshot=$(cat "$LAUNCHERS"/*)
output=$(run_migration)
if [[ "$(cat "$LAUNCHERS"/*)" == "$snapshot" ]]; then
    pass "second run changes nothing"
else
    fail "second run should change nothing"
fi
if [[ "$output" == *"nothing to backfill"* ]]; then
    pass "second run reports nothing to do"
else
    fail "second run should report nothing to do (got: $output)"
fi

cleanup_sandbox

print_summary

if [[ $FAIL -gt 0 ]]; then
    exit 1
fi
