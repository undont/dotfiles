#!/usr/bin/env zsh
# Command exit alert hooks for zsh
# Source this file from dotfiles.zsh (or ~/.zshrc) to enable auto-alerts.
#
# Automatically sends a tmux alert when a command finishes after ≥ threshold
# seconds. Interactive commands (pagers, editors) are excluded by default.
#
# Override before sourcing:
#   _CMD_ALERT_MIN_SECONDS=30
#   _CMD_ALERT_EXCLUDE=(less man git)
#   source ~/dotfiles/scripts/hooks/cmd-alert-hook.zsh
#
# Append to exclude list after sourcing:
#   _CMD_ALERT_EXCLUDE+=(mytool "docker compose")

_CMD_ALERT_MIN_SECONDS="${_CMD_ALERT_MIN_SECONDS:-1}"
_cmd_alert_start=-1       # -1 = no command in flight (0 is a valid SECONDS value)
_cmd_alert_exit=0
_cmd_alert_label=""
_cmd_alert_pane=""

# Commands that should never trigger alerts (interactive pagers, editors, etc.)
# Single-word entries match the first word of the command (git → all git subcommands).
# Multi-word entries match as a command prefix ("docker compose" → docker compose up).
# Override before sourcing:  _CMD_ALERT_EXCLUDE=(gdn less man git)
# Append after sourcing:     _CMD_ALERT_EXCLUDE+=(mytool)
if (( ! ${+_CMD_ALERT_EXCLUDE} )); then
    _CMD_ALERT_EXCLUDE=(
        git gdn gh
        claude opencode oc
        btop htop top
        docker lazydocker lazygit ssh
        less more man
        vim nvim v vi nano bat diffnav
        psql sqlite3 tmux
    )
fi

# Capture the path to cmd-alert.sh at source time — ${(%):-%x} gives the path
# of the currently-sourced file in zsh (unlike $0 which is the shell name)
_CMD_ALERT_SCRIPT="${_CMD_ALERT_SCRIPT:-${${(%):-%x}:A:h}/cmd-alert.sh}"

_cmd_alert_preexec() {
    _cmd_alert_exit=0

    # Build a short label: basename of first word + up to 2 more words
    local cmd="$1"
    local -a words
    words=("${(z)cmd}")
    local first
    first="$(basename "${words[1]:-cmd}")"

    # Skip excluded commands (interactive pagers, editors, etc.)
    # Single-word entries match the first word; multi-word entries match as a
    # command prefix (e.g. "docker compose" excludes "docker compose up").
    local _exclude
    for _exclude in "${_CMD_ALERT_EXCLUDE[@]}"; do
        if [[ "$_exclude" == *" "* ]]; then
            if [[ "$cmd" == "$_exclude" || "$cmd" == "$_exclude "* ]]; then
                _cmd_alert_start=-1
                _cmd_alert_label=""
                return
            fi
        elif [[ "$first" == "$_exclude" ]]; then
            _cmd_alert_start=-1
            _cmd_alert_label=""
            return
        fi
    done

    _cmd_alert_start=$SECONDS
    local nwords=${#words[@]}
    if (( nwords <= 3 )); then
        _cmd_alert_label="${first}${words[2]:+ ${words[2]}}${words[3]:+ ${words[3]}}"
    else
        _cmd_alert_label="${first} ${words[2]}…"
    fi

    # Capture the origin pane so the alert lands on the correct window
    # even if the user switches windows before the command finishes
    if [[ -n "${TMUX:-}" ]]; then
        _cmd_alert_pane=$(tmux display-message -p '#{pane_id}' 2>/dev/null || true)
    else
        _cmd_alert_pane=""
    fi
}

# Must run first in precmd so $? is captured before other precmd functions clobber it
_cmd_alert_precmd() {
    local exit_code=$?

    # No command in flight
    if (( _cmd_alert_start < 0 )) || [[ -z "$_cmd_alert_label" ]]; then
        return
    fi

    _cmd_alert_exit=$exit_code
    local elapsed=$(( SECONDS - _cmd_alert_start ))
    _cmd_alert_start=-1

    # Only alert if we're in tmux and command ran long enough to be worth noticing
    if [[ -z "${TMUX:-}" ]] || (( elapsed < _CMD_ALERT_MIN_SECONDS )); then
        _cmd_alert_label=""
        _cmd_alert_pane=""
        return
    fi

    # Fire the alert hook, passing the origin pane so the alert lands on the
    # correct window (not the one we've switched back to)
    if [[ -f "$_CMD_ALERT_SCRIPT" ]]; then
        "$_CMD_ALERT_SCRIPT" "$_cmd_alert_exit" "$_cmd_alert_label" "$_cmd_alert_pane"
    fi

    _cmd_alert_label=""
    _cmd_alert_pane=""
}

# Register hooks — precmd must be prepended so $? is read before other precmd
# functions run
autoload -Uz add-zsh-hook
add-zsh-hook preexec _cmd_alert_preexec
precmd_functions=(_cmd_alert_precmd "${precmd_functions[@]}")
