#!/usr/bin/env bash
# Test confirmation dialogs in kill-pane.sh, kill-window.sh, kill-session.sh
# Verifies that all kill scripts use show_visual_confirm with context-aware messages

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_DIR="$SCRIPT_DIR/.."

source "$SCRIPT_DIR/_test-helpers.sh"

section "Script existence and executability"

# Map logical names to actual subdirectory paths
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
    ((PASSED++))
else
    fail "kill-pane.sh missing context-aware message"
    ((FAILED++))
fi

if grep -q "Switch to.*and kill" "$SCRIPTS_DIR/panes/kill.sh"; then
    pass "kill-pane.sh mentions session switching"
    ((PASSED++))
else
    fail "kill-pane.sh doesn't mention session switching"
    ((FAILED++))
fi

# kill-window.sh should have context-aware messages for last window
if grep -q "Last window" "$SCRIPTS_DIR/windows/kill.sh"; then
    pass "kill-window.sh has context-aware message for last window"
    ((PASSED++))
else
    fail "kill-window.sh missing context-aware message"
    ((FAILED++))
fi

if grep -q "Switch to.*and kill" "$SCRIPTS_DIR/windows/kill.sh"; then
    pass "kill-window.sh mentions session switching"
    ((PASSED++))
else
    fail "kill-window.sh doesn't mention session switching"
    ((FAILED++))
fi

# kill-session.sh should ask about switching to another session
if grep -q "Kill session.*and switch to" "$SCRIPTS_DIR/sessions/kill.sh"; then
    pass "kill-session.sh has context-aware message for session switching"
    ((PASSED++))
else
    fail "kill-session.sh missing session switching message"
    ((FAILED++))
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

# Verify scripts skip confirmation when flags are set
if grep -q "if ! \$FORCE_KILL" "$SCRIPTS_DIR/panes/kill.sh"; then
    pass "kill-pane.sh skips confirmation with --force"
    ((PASSED++))
else
    fail "kill-pane.sh doesn't check FORCE_KILL flag"
    ((FAILED++))
fi

if grep -q 'if \[\[ "\$NO_CONFIRM" != "--no-confirm" \]\]' "$SCRIPTS_DIR/windows/kill.sh"; then
    pass "kill-window.sh skips confirmation with --no-confirm"
    ((PASSED++))
else
    fail "kill-window.sh doesn't check NO_CONFIRM flag"
    ((FAILED++))
fi

if grep -q 'if \[\[ "\$NO_CONFIRM" != "--no-confirm" \]\]' "$SCRIPTS_DIR/sessions/kill.sh"; then
    pass "kill-session.sh skips confirmation with --no-confirm"
    ((PASSED++))
else
    fail "kill-session.sh doesn't check NO_CONFIRM flag"
    ((FAILED++))
fi

section "Exit codes and cancellation handling"

for script in kill-pane.sh kill-window.sh kill-session.sh; do
    script_path="${KILL_SCRIPTS[$script]}"
    # Check if script exits cleanly when user cancels (looks for exit 0 after show_visual_confirm check)
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
    ((PASSED++))
else
    fail "kill-window.sh doesn't clear alerts"
    ((FAILED++))
fi

if grep -q "clear_session_alerts" "$SCRIPTS_DIR/sessions/kill.sh"; then
    pass "kill-session.sh clears session alerts"
    ((PASSED++))
else
    fail "kill-session.sh doesn't clear alerts"
    ((FAILED++))
fi

section "Undo state preservation"

# All kill scripts should save undo state
for script in kill-pane.sh kill-window.sh kill-session.sh; do
    script_path="${KILL_SCRIPTS[$script]}"
    if grep -q "UNDO_FILE\|undo state" "$SCRIPTS_DIR/$script_path"; then
        pass "$script saves undo state"

    else
        fail "$script doesn't save undo state"

    fi
done

print_summary
[[ $FAIL -gt 0 ]] && exit 1
exit 0
