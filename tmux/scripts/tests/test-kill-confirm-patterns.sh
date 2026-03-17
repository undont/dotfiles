#!/usr/bin/env bash
# Test kill and confirm patterns for windows, panes, and sessions
set -euo pipefail

# Determine repository root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
SCRIPTS_DIR="$REPO_ROOT/tmux/scripts"
LIB_DIR="$SCRIPTS_DIR/_lib"

source "$SCRIPT_DIR/_test-helpers.sh"

section "Standardized confirmation functions"
if grep -q "^show_visual_confirm()" "$LIB_DIR/ui.sh"; then
    pass "show_visual_confirm defined in ui.sh"
else
    fail "show_visual_confirm not found in ui.sh"
fi

if grep -q "^tmux_confirm_last_item()" "$LIB_DIR/ui.sh"; then
    pass "tmux_confirm_last_item defined in ui.sh"
else
    fail "tmux_confirm_last_item not found in ui.sh"
fi

section "Agent alert functions"
if grep -q "^clear_window_alerts()" "$LIB_DIR/alerts.sh"; then
    pass "clear_window_alerts defined"
else
    fail "clear_window_alerts not found"
fi

if grep -q "^clear_session_alerts()" "$LIB_DIR/alerts.sh"; then
    pass "clear_session_alerts defined"
else
    fail "clear_session_alerts not found"
fi

if grep -q "^get_agent_display()" "$LIB_DIR/alerts.sh"; then
    pass "get_agent_display defined"
else
    fail "get_agent_display not found"
fi

section "Kill script files"
for script in windows/kill.sh panes/kill.sh sessions/kill.sh; do
    if [[ -f "$SCRIPTS_DIR/$script" ]] && [[ -x "$SCRIPTS_DIR/$script" ]]; then
        pass "$script exists and is executable"
    else
        fail "$script missing or not executable"
    fi
done

section "Using standardized visual confirmation"
for script in windows/kill.sh panes/kill.sh sessions/kill.sh; do
    if grep -q "show_visual_confirm\|tmux_confirm_last_item" "$SCRIPTS_DIR/$script"; then
        pass "$script uses standardized confirmation"
    else
        fail "$script doesn't use standardized confirmation"
    fi
done

section "No deprecated confirmation patterns"
for script in windows/kill.sh panes/kill.sh; do
    if ! grep -q "show_centered_confirm" "$SCRIPTS_DIR/$script"; then
        pass "$script doesn't use show_centered_confirm"
    else
        fail "$script still uses show_centered_confirm"
    fi
done

section "Alert cleanup must be synchronous (not backgrounded)"
# Regression: backgrounded alert cleanup gets SIGHUP-killed when
# the display-popup exits, leaving stale alerts in the file.
for script in windows/kill.sh panes/kill.sh sessions/kill.sh; do
    if grep -qE 'clear_(session|window)_alerts.*&\s*$' "$SCRIPTS_DIR/$script"; then
        fail "$script backgrounds alert cleanup (will be killed by popup teardown)"
    else
        pass "$script runs alert cleanup synchronously"
    fi
done

section "Instance pickers must not use fzf become() in pipelines"
# Regression: fzf become() is unreliable when fzf is piped to another
# process (cut | xargs). Use execute-silent()+abort instead.
TMUX_TEMPLATE="$REPO_ROOT/tmux/tmux.conf.template"
if [[ -f "$TMUX_TEMPLATE" ]]; then
    # Find lines with both 'become(' and a pipe to another process on instance pickers
    if grep -A2 'instances/.*\.sh |' "$TMUX_TEMPLATE" | grep -q 'become('; then
        fail "Instance picker uses become() in pipeline (use execute-silent+abort)"
    else
        pass "Instance pickers avoid become() in pipeline context"
    fi
else
    skip "tmux.conf.template not found"
fi

section "Agent-agnostic terminology"
for file in sessions/kill.sh rename-session.sh rename-window.sh update-timestamp.sh; do
    if grep -i "claude.*alert" "$SCRIPTS_DIR/$file" | grep -qv "ALERTS_FILE\|^#"; then
        fail "$file has claude-specific alert references"
    else
        pass "$file uses agent-agnostic terminology"
    fi
done

print_summary
[[ $FAIL -gt 0 ]] && exit 1
exit 0
