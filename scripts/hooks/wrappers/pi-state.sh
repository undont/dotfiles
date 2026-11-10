#!/usr/bin/env bash
# pi state script: record per-pane agent state for the tmux switcher
# the agent-alerts extension passes the state in env vars (PI_AGENT_STATE,
# PI_STATE_EVENT, PI_SESSION_ID, PI_DIRECTORY); stdin is not read

[[ -n "${PI_AGENT_STATE:-}" ]] || exit 0

SCRIPT_DIR="${BASH_SOURCE%/*}/.."
AGENT_STATE="$PI_AGENT_STATE" \
    AGENT_EVENT="${PI_STATE_EVENT:-}" \
    AGENT_SESSION_ID="${PI_SESSION_ID:-}" \
    AGENT_CWD="${PI_DIRECTORY:-}" \
    exec "$SCRIPT_DIR/agent-state.sh" pi
