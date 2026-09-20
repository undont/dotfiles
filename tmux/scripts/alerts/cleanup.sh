#!/usr/bin/env bash
# clean up stale alerts (sessions/windows that no longer exist)
# called by session-closed, session-renamed and the two window-rename hooks
# "alerts" limits the run to the alerts file: the rename hooks fire on every
# automatic rename, often enough that the per-pane agent-state scan isn't worth it
# always exits 0; best-effort cleanup should never cause hook errors

SCRIPT_DIR="${BASH_SOURCE%/*}"
source "$SCRIPT_DIR/../_lib/alerts.sh"

cleanup_stale_alerts || true
[[ "${1:-}" == "alerts" ]] && exit 0

cleanup_stale_agent_state || true
exit 0
