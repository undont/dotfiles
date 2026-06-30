#!/usr/bin/env zsh
# command exit alert hooks for zsh
# source this file from dotfiles.zsh (or ~/.zshrc) to enable auto-alerts.
#
# automatically sends a tmux alert when a command finishes after ≥ threshold
# seconds. interactive commands (pagers, editors) are excluded by default.
#
# override before sourcing:
#   _CMD_ALERT_MIN_SECONDS=30
#   _CMD_ALERT_EXCLUDE=(less man git)
#   source ~/dotfiles/scripts/hooks/cmd-alert-hook.zsh
#
# append to exclude list after sourcing:
#   _CMD_ALERT_EXCLUDE+=(mytool "docker compose")

_CMD_ALERT_MIN_SECONDS="${_CMD_ALERT_MIN_SECONDS:-1}"

# running-process registry dir (kept in sync with RUNNING_DIR in
# tmux/scripts/_lib/alerts.sh). one file per pane, written while a tracked
# command is in flight so proclist can show what's running right now
_CMD_RUNNING_DIR="${_CMD_RUNNING_DIR:-${XDG_CONFIG_HOME:-$HOME/.config}/tmux-alerts/running}"
# finished-process history (kept in sync with FINISHED_FILE in
# tmux/scripts/_lib/alerts.sh). recorded on every tracked completion so the
# proclist "done" rows survive even commands you watched finish in place
_CMD_FINISHED_FILE="${_CMD_FINISHED_FILE:-${XDG_CONFIG_HOME:-$HOME/.config}/tmux-alerts/finished}"
# $EPOCHSECONDS gives a wall-clock start the proclist reader can age
zmodload zsh/datetime 2>/dev/null || true

_cmd_alert_start=-1       # -1 = no command in flight (0 is a valid SECONDS value)
_cmd_alert_exit=0
_cmd_alert_label=""
_cmd_alert_cmd=""         # full command as typed, for proclist rerun (R)
_cmd_alert_pane=""

# commands that should never trigger alerts (interactive pagers, editors, etc.)
# single-word entries match the first word of the command (git → all git subcommands).
# multi-word entries match as a command prefix ("docker compose" → docker compose up).
# override before sourcing:  _CMD_ALERT_EXCLUDE=(gdn less man git)
# append after sourcing:     _CMD_ALERT_EXCLUDE+=(mytool)
if (( ! ${+_CMD_ALERT_EXCLUDE} )); then
    _CMD_ALERT_EXCLUDE=(
        git gdn gh
        claude opencode oc
        btop htop top
        docker lazydocker lazygit ssh
        less more man
        vim nvim v vi nano bat diffnav
        psql sqlite3 tmux
        fg bg
    )
fi

# capture the path to cmd-alert.sh at source time: ${(%):-%x} gives the path
# of the currently-sourced file in zsh (unlike $0 which is the shell name)
_CMD_ALERT_SCRIPT="${_CMD_ALERT_SCRIPT:-${${(%):-%x}:A:h}/cmd-alert.sh}"

_cmd_alert_preexec() {
    _cmd_alert_exit=0

    # build a short label from what the user typed ($1); the label uses it so
    # it reads as entered. :t is zsh's basename, no subprocess fork
    local cmd="$1"
    local -a words
    words=("${(z)cmd}")
    local first
    first="${${words[1]:-cmd}:t}"

    # launcher convention: aliases defined as clear-then-run (`cl && X`,
    # `clear && X`) are interactive sessions, not background tasks. read the
    # definition from zsh's alias map so any launcher following the convention
    # is excluded automatically, with no per-launcher list to keep in sync
    local _adef="${aliases[$first]:-}"
    if [[ -n "$_adef" && "$_adef" == *"&&"* ]]; then
        local -a _dw
        _dw=("${(z)_adef}")
        case "${_dw[1]}" in
            cl|clear|c)
                _cmd_alert_start=-1
                _cmd_alert_label=""
                return
                ;;
        esac
    fi

    # $2 is the alias-expanded command; matching its first word too catches
    # plain aliases like gfp -> git fetch --prune (covered by the `git` entry)
    local exp="${2:-$cmd}"
    local -a ewords
    ewords=("${(z)exp}")
    local efirst
    efirst="${${ewords[1]:-cmd}:t}"

    # skip excluded commands. single-word entries match the typed or expanded
    # first word; multi-word entries match either as a command prefix
    # (e.g. "docker compose" excludes "docker compose up")
    local _exclude
    for _exclude in "${_CMD_ALERT_EXCLUDE[@]}"; do
        if [[ "$_exclude" == *" "* ]]; then
            if [[ "$cmd" == "$_exclude" || "$cmd" == "$_exclude "* \
               || "$exp" == "$_exclude" || "$exp" == "$_exclude "* ]]; then
                _cmd_alert_start=-1
                _cmd_alert_label=""
                return
            fi
        elif [[ "$first" == "$_exclude" || "$efirst" == "$_exclude" ]]; then
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

    # sanitise label: strip colons (delimiter in alerts file), escape '#' (tmux
    # format injection), and cap length to prevent oversized status bar entries
    _cmd_alert_label="${_cmd_alert_label//:/ }"
    _cmd_alert_label="${_cmd_alert_label//\#/##}"
    _cmd_alert_label="${_cmd_alert_label:0:80}"

    # keep the full command as typed for proclist rerun (R). $1 is pre-expansion,
    # so $VAR references stay references (re-expanded by the shell on rerun, not
    # stored as values). collapse tabs/newlines so one finished row stays one line
    _cmd_alert_cmd="${cmd//$'\n'/ }"
    _cmd_alert_cmd="${_cmd_alert_cmd//$'\t'/ }"

    # capture the origin pane so the alert lands on the correct window
    # even if the user switches windows before the command finishes
    if [[ -n "${TMUX:-}" ]]; then
        _cmd_alert_pane=$(tmux display-message -p '#{pane_id}' 2>/dev/null || true)
    else
        _cmd_alert_pane=""
    fi

    # register the in-flight command (one file per pane, named by pane number).
    # fields: pane_id, start epoch, shell pid, label. removed by precmd on finish
    if [[ -n "$_cmd_alert_pane" ]]; then
        [[ -d "$_CMD_RUNNING_DIR" ]] || mkdir -p "$_CMD_RUNNING_DIR" 2>/dev/null
        printf '%s\t%s\t%s\t%s\n' \
            "$_cmd_alert_pane" "${EPOCHSECONDS:-0}" "$$" "$_cmd_alert_label" \
            > "$_CMD_RUNNING_DIR/${_cmd_alert_pane#%}" 2>/dev/null
    fi
}

# must run first in precmd so $? is captured before other precmd functions clobber it
_cmd_alert_precmd() {
    local exit_code=$?

    # no command in flight
    if (( _cmd_alert_start < 0 )) || [[ -z "$_cmd_alert_label" ]]; then
        return
    fi

    _cmd_alert_exit=$exit_code
    local elapsed=$(( SECONDS - _cmd_alert_start ))
    _cmd_alert_start=-1

    # command finished: drop its in-flight registry entry (origin pane). runs
    # for every tracked command, independent of the alert threshold below
    if [[ -n "$_cmd_alert_pane" ]]; then
        rm -f "$_CMD_RUNNING_DIR/${_cmd_alert_pane#%}" 2>/dev/null
    fi

    # only alert if we're in tmux and command ran long enough to be worth noticing
    if [[ -z "${TMUX:-}" ]] || (( elapsed < _CMD_ALERT_MIN_SECONDS )); then
        _cmd_alert_label=""
        _cmd_alert_cmd=""
        _cmd_alert_pane=""
        return
    fi

    # record the completion in the finished-process history (proclist "done"
    # rows). done regardless of the window-switch guard below, so a command you
    # watched finish in place still leaves a ✓/✗ entry. target the origin pane
    # explicitly: this precmd runs after the command, and by the time an alert
    # fires you have usually switched away, so a bare `display-message -p` would
    # resolve to the origin session's *active* window and file the row under the
    # wrong window (the same gotcha the view guard below documents). one round-trip
    local _meta=""
    if [[ -n "$_cmd_alert_pane" ]]; then
        _meta=$(tmux display-message -t "$_cmd_alert_pane" -p $'#S\t#{window_id}\t#W' 2>/dev/null) || _meta=""
    fi
    if [[ -n "$_meta" ]]; then
        local _sess _wid _wname
        IFS=$'\t' read -r _sess _wid _wname <<< "$_meta"
        [[ -d "${_CMD_FINISHED_FILE:h}" ]] || mkdir -p "${_CMD_FINISHED_FILE:h}" 2>/dev/null
        printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
            "${EPOCHSECONDS:-0}" "$_cmd_alert_exit" "$_sess" "$_wid" "$_wname" "$_cmd_alert_label" "$_cmd_alert_cmd" \
            >> "$_CMD_FINISHED_FILE" 2>/dev/null
    fi

    # view guard: only alert if no attached client is currently viewing the
    # origin pane. comparing against `display-message -p '#{pane_id}'` was wrong:
    # run from a background pane it resolves to the *origin session's* active
    # pane, so switching to another session still looked like "still here" and
    # suppressed the alert. matching the origin pane against every client's
    # active pane catches both window- and session-switch cases
    if [[ -n "$_cmd_alert_pane" ]]; then
        local _cp _watching=0
        while IFS= read -r _cp; do
            [[ "$_cp" == "$_cmd_alert_pane" ]] && { _watching=1; break; }
        done < <(tmux list-clients -F '#{pane_id}' 2>/dev/null)
        if (( _watching )); then
            _cmd_alert_label=""
            _cmd_alert_cmd=""
            _cmd_alert_pane=""
            return
        fi
    fi

    # fire the alert hook, passing the origin pane so the alert lands on the
    # correct window (not the one we've switched back to)
    if [[ -f "$_CMD_ALERT_SCRIPT" ]]; then
        "$_CMD_ALERT_SCRIPT" "$_cmd_alert_exit" "$_cmd_alert_label" "$_cmd_alert_pane"
    fi

    _cmd_alert_label=""
    _cmd_alert_cmd=""
    _cmd_alert_pane=""
}

# register hooks: precmd must be prepended so $? is read before other precmd
# functions run
autoload -Uz add-zsh-hook
add-zsh-hook preexec _cmd_alert_preexec
precmd_functions=(_cmd_alert_precmd "${precmd_functions[@]}")
