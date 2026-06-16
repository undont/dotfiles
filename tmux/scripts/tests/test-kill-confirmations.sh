#!/usr/bin/env bash
# test confirmation dialogs in kill-pane.sh, kill-window.sh, kill-session.sh
# verifies that all kill scripts use show_visual_confirm with context-aware messages

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_DIR="$SCRIPT_DIR/.."

source "$SCRIPT_DIR/_test-helpers.sh"

section "Script existence and executability"

# map logical names to actual subdirectory paths
declare -A KILL_SCRIPTS=(
    ["kill-pane.sh"]="panes/kill.sh"
    ["kill-window.sh"]="windows/kill.sh"
    ["kill-session.sh"]="sessions/kill.sh"
)

for script in kill-pane.sh kill-window.sh kill-session.sh; do
    script_path="${KILL_SCRIPTS[$script]}"
    if [[ -f "$SCRIPTS_DIR/$script_path" && -x "$SCRIPTS_DIR/$script_path" ]]; then
        pass "$script exists and is executable"

    else
        fail "$script missing or not executable"

    fi
done

section "Required library dependencies"

for script in kill-pane.sh kill-window.sh kill-session.sh; do
    script_path="${KILL_SCRIPTS[$script]}"
    if grep -q "source.*_lib/common.sh" "$SCRIPTS_DIR/$script_path"; then
        pass "$script sources common.sh"

    else
        fail "$script doesn't source common.sh"

    fi

    if grep -q "source.*_lib/ui.sh" "$SCRIPTS_DIR/$script_path"; then
        pass "$script sources ui.sh"

    else
        fail "$script doesn't source ui.sh"

    fi

    if grep -q "source.*_lib/session.sh" "$SCRIPTS_DIR/$script_path"; then
        pass "$script sources session.sh"

    else
        fail "$script doesn't source session.sh"

    fi
done

section "Visual confirmation usage"

for script in kill-pane.sh kill-window.sh kill-session.sh; do
    script_path="${KILL_SCRIPTS[$script]}"
    if grep -q "show_visual_confirm" "$SCRIPTS_DIR/$script_path"; then
        pass "$script uses show_visual_confirm"

    else
        fail "$script doesn't use show_visual_confirm"

    fi
done

section "Context-aware messages"

# kill-pane.sh should have context-aware messages for last pane
if grep -q "Last pane in" "$SCRIPTS_DIR/panes/kill.sh"; then
    pass "kill-pane.sh has context-aware message for last pane"
else
    fail "kill-pane.sh missing context-aware message"
fi

if grep -q "Switch to.*and kill" "$SCRIPTS_DIR/panes/kill.sh"; then
    pass "kill-pane.sh mentions session switching"
else
    fail "kill-pane.sh doesn't mention session switching"
fi

# kill-window.sh should have context-aware messages for last window
if grep -q "Last window" "$SCRIPTS_DIR/windows/kill.sh"; then
    pass "kill-window.sh has context-aware message for last window"
else
    fail "kill-window.sh missing context-aware message"
fi

if grep -q "Switch to.*and kill" "$SCRIPTS_DIR/windows/kill.sh"; then
    pass "kill-window.sh mentions session switching"
else
    fail "kill-window.sh doesn't mention session switching"
fi

# kill-session.sh should ask about switching to another session
if grep -q "Kill session.*and switch to" "$SCRIPTS_DIR/sessions/kill.sh"; then
    pass "kill-session.sh has context-aware message for session switching"
else
    fail "kill-session.sh missing session switching message"
fi

section "Session switching logic"

for script in kill-pane.sh kill-window.sh kill-session.sh; do
    script_path="${KILL_SCRIPTS[$script]}"
    if grep -q "find_other_session" "$SCRIPTS_DIR/$script_path"; then
        pass "$script uses find_other_session"

    else
        fail "$script doesn't use find_other_session"

    fi

    if grep -q "switch-client" "$SCRIPTS_DIR/$script_path"; then
        pass "$script switches client before kill"

    else
        fail "$script doesn't switch client"

    fi
done

section "Flag support"

# kill-pane.sh and kill-window.sh should support --force flag
for script in kill-pane.sh kill-window.sh; do
    script_path="${KILL_SCRIPTS[$script]}"
    if grep -q "\-\-force" "$SCRIPTS_DIR/$script_path"; then
        pass "$script supports --force flag"

    else
        fail "$script doesn't support --force flag"

    fi
done

# kill-window.sh and kill-session.sh should support --no-confirm flag
for script in kill-window.sh kill-session.sh; do
    script_path="${KILL_SCRIPTS[$script]}"
    if grep -q "\-\-no-confirm" "$SCRIPTS_DIR/$script_path"; then
        pass "$script supports --no-confirm flag"

    else
        fail "$script doesn't support --no-confirm flag"

    fi
done

section "Confirmation can be skipped"

# verify scripts skip confirmation when flags are set
if grep -q "if ! \$FORCE_KILL" "$SCRIPTS_DIR/panes/kill.sh"; then
    pass "kill-pane.sh skips confirmation with --force"
else
    fail "kill-pane.sh doesn't check FORCE_KILL flag"
fi

if grep -q 'if \[\[ "\$NO_CONFIRM" != "--no-confirm" \]\]' "$SCRIPTS_DIR/windows/kill.sh"; then
    pass "kill-window.sh skips confirmation with --no-confirm"
else
    fail "kill-window.sh doesn't check NO_CONFIRM flag"
fi

if grep -q 'if \[\[ "\$NO_CONFIRM" != "--no-confirm" \]\]' "$SCRIPTS_DIR/sessions/kill.sh"; then
    pass "kill-session.sh skips confirmation with --no-confirm"
else
    fail "kill-session.sh doesn't check NO_CONFIRM flag"
fi

section "Exit codes and cancellation handling"

for script in kill-pane.sh kill-window.sh kill-session.sh; do
    script_path="${KILL_SCRIPTS[$script]}"
    # check if script exits cleanly when user cancels (looks for exit 0 after show_visual_confirm check)
    if grep -A2 "show_visual_confirm" "$SCRIPTS_DIR/$script_path" | grep -q "exit 0"; then
        pass "$script exits cleanly on cancellation"

    else
        fail "$script doesn't handle cancellation properly"

    fi
done

section "Alert cleanup integration"

# kill-window.sh and kill-session.sh should clear alerts
if grep -q "clear_window_alerts" "$SCRIPTS_DIR/windows/kill.sh"; then
    pass "kill-window.sh clears window alerts"
else
    fail "kill-window.sh doesn't clear alerts"
fi

if grep -q "clear_session_alerts" "$SCRIPTS_DIR/sessions/kill.sh"; then
    pass "kill-session.sh clears session alerts"
else
    fail "kill-session.sh doesn't clear alerts"
fi

section "Undo state preservation"

# all kill scripts should save undo state
for script in kill-pane.sh kill-window.sh kill-session.sh; do
    script_path="${KILL_SCRIPTS[$script]}"
    if grep -q "UNDO_FILE\|undo_file\|save_undo_state" "$SCRIPTS_DIR/$script_path"; then
        pass "$script saves undo state"

    else
        fail "$script doesn't save undo state"

    fi
done

section "save_undo_state resilience"

# regression: save_undo_state must return 0 even when no backup exists,
# otherwise set -e kills the script before the session gets killed.
# this happens when a session is created, killed, recreated, and killed
# again before the auto-save cycle captures it
if bash -c '
    set -euo pipefail
    TEST_XDG_CACHE=$(mktemp -d)
    export XDG_CACHE_HOME="$TEST_XDG_CACHE"
    # stub tmux to simulate a session with no windows/panes (empty output)
    tmux() { return 1; }
    export -f tmux
    # source kill.sh safely, the guard prevents the main script from running
    SOURCING_FOR_TEST=1 source "'"$SCRIPTS_DIR/sessions/kill.sh"'"
    # call with a session that has no backup anywhere
    save_undo_state "nonexistent_session_$$"
    # if we reach here, set -e did not kill us
    cleanup_undo_files "session"
    rm -rf "$TEST_XDG_CACHE"
    exit 0
' 2>/dev/null; then
    pass "save_undo_state returns 0 when no backup exists"
else
    fail "save_undo_state exits non-zero when no backup exists (set -e regression)"
fi

print_summary
[[ $FAIL -gt 0 ]] && exit 1
exit 0
