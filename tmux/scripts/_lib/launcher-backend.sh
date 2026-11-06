#!/usr/bin/env bash
# session operations on whichever multiplexer the launcher runs under:
# LAUNCHER_BACKEND (tmux | rex), else tmux inside tmux, else rex inside rex
# source this file: source "${BASH_SOURCE%/*}/../_lib/launcher-backend.sh"

[[ -n "${_TMUX_LAUNCHER_BACKEND_SH_LOADED:-}" ]] && return 0
_TMUX_LAUNCHER_BACKEND_SH_LOADED=1

# shellcheck source=tmux/scripts/_lib/launcher-tmux.sh
source "${BASH_SOURCE%/*}/launcher-tmux.sh"
# shellcheck source=tmux/scripts/_lib/launcher-rex.sh
source "${BASH_SOURCE%/*}/launcher-rex.sh"

launcher_backend() {
    if [[ -n "${LAUNCHER_BACKEND:-}" ]]; then
        printf '%s\n' "$LAUNCHER_BACKEND"
    elif [[ -n "${TMUX:-}" ]]; then
        printf 'tmux\n'
    elif [[ -n "${PICK_CLIENT:-}${REX_SESSION:-}" ]]; then
        printf 'rex\n'
    else
        printf 'tmux\n'
    fi
}

launcher_sessions() {
    "$(launcher_backend)_sessions"
}

launcher_session_exists() {
    "$(launcher_backend)_session_exists" "$1"
}

launcher_focus_session() {
    "$(launcher_backend)_focus_session" "$1"
}

# usage: launcher_launch RESOLVED_JSON
launcher_launch() {
    "$(launcher_backend)_launch" "$1"
}
