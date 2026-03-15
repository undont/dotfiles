#!/usr/bin/env bash
# Test that list scripts use file-based alert lookups (not per-window tmux calls)
# Guards against the performance regression from commit 53671a7 where
# sessions/list.sh was changed to call tmux show-options per window.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
SCRIPTS_DIR="$REPO_ROOT/tmux/scripts"
LIB_DIR="$SCRIPTS_DIR/_lib"

source "$SCRIPT_DIR/_test-helpers.sh"

section "List scripts use file-based alerts (no per-window tmux calls)"

# sessions/list.sh and windows/list.sh must NOT call tmux show-options
# (that pattern causes O(sessions × windows) tmux round-trips)
for script in sessions/list.sh windows/list.sh; do
    if grep -q "tmux show-options" "$SCRIPTS_DIR/$script"; then
        fail "$script calls tmux show-options (per-window regression)"
    else
        pass "$script avoids tmux show-options"
    fi
done

# Both list scripts should use the shared build_alert_icons function
for script in sessions/list.sh windows/list.sh; do
    if grep -q "build_alert_icons" "$SCRIPTS_DIR/$script"; then
        pass "$script uses build_alert_icons (file-based)"
    else
        fail "$script doesn't use build_alert_icons"
    fi
done

# Both list scripts should pre-read the alerts file
for script in sessions/list.sh windows/list.sh; do
    if grep -q 'ALERTS_FILE' "$SCRIPTS_DIR/$script"; then
        pass "$script reads ALERTS_FILE"
    else
        fail "$script doesn't reference ALERTS_FILE"
    fi
done

section "build_alert_icons defined in alerts library"
if grep -q "^build_alert_icons()" "$LIB_DIR/alerts.sh"; then
    pass "build_alert_icons defined in alerts.sh"
else
    fail "build_alert_icons not found in alerts.sh"
fi

section "No redundant clear_window_alerts in update-timestamp.sh"
if grep -q "clear_window_alerts" "$SCRIPTS_DIR/alerts/update-timestamp.sh"; then
    fail "update-timestamp.sh calls clear_window_alerts (redundant with hook)"
else
    pass "update-timestamp.sh doesn't call clear_window_alerts"
fi

section "Tmux hooks call clear.sh on session and window switch"
TMUX_CONF="$REPO_ROOT/tmux/tmux.conf.template"
for hook in after-select-window client-session-changed; do
    if grep "$hook" "$TMUX_CONF" | grep -q "clear.sh"; then
        pass "$hook hook calls clear.sh"
    else
        fail "$hook hook missing clear.sh (alerts won't clear on switch)"
    fi
done

section "clear.sh doesn't spawn update-timestamp.sh"
if grep -q "update-timestamp" "$SCRIPTS_DIR/alerts/clear.sh"; then
    fail "clear.sh spawns update-timestamp.sh (should be called independently by hooks)"
else
    pass "clear.sh doesn't spawn update-timestamp.sh"
fi

print_summary
[[ $FAIL -gt 0 ]] && exit 1
exit 0
