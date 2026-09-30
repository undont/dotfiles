#!/usr/bin/env zsh
# command exit alert hooks for zsh, sourced from dotfiles.zsh
#
# sends a tmux alert when a command runs for at least $_CMD_ALERT_MIN_SECONDS
# and its pane is not being viewed. interactive commands (pagers, editors) are
# excluded
#
# override before sourcing:
#   _CMD_ALERT_MIN_SECONDS=30
#   _CMD_ALERT_EXCLUDE=(less man git)
# append after sourcing:
#   _CMD_ALERT_EXCLUDE+=(mytool "docker compose")

_CMD_ALERT_MIN_SECONDS="${_CMD_ALERT_MIN_SECONDS:-1}"

# running-process registry (RUNNING_DIR in tmux/scripts/_lib/alerts.sh): one
# file per pane while a tracked command is in flight, read by proclist
_CMD_RUNNING_DIR="${_CMD_RUNNING_DIR:-${XDG_CONFIG_HOME:-$HOME/.config}/tmux-alerts/running}"
# finished-process history (FINISHED_FILE in tmux/scripts/_lib/alerts.sh): a
# row per tracked completion inside tmux that reaches the threshold and was
# not killed from proclist
_CMD_FINISHED_FILE="${_CMD_FINISHED_FILE:-${XDG_CONFIG_HOME:-$HOME/.config}/tmux-alerts/finished}"
# kill-suppress markers (SUPPRESS_DIR in tmux/scripts/_lib/alerts.sh): one file
# per pane, touched by proclist-action.sh before it interrupts a tracked
# command; precmd then skips the alert and the finished row
_CMD_SUPPRESS_DIR="${_CMD_SUPPRESS_DIR:-${XDG_CONFIG_HOME:-$HOME/.config}/tmux-alerts/suppress}"
# $EPOCHSECONDS: wall-clock start time for the proclist reader
zmodload zsh/datetime 2>/dev/null || true

_cmd_alert_start=-1 # -1 = no command in flight (0 is a valid SECONDS value)
_cmd_alert_exit=0
_cmd_alert_label=""
_cmd_alert_cmd="" # full command as typed, for proclist rerun (R)
_cmd_alert_pane=""

# commands that never trigger alerts. a single-word entry matches the first
# word of the command (git covers every git subcommand); a multi-word entry
# matches as a command prefix ("docker compose")
if ((!${+_CMD_ALERT_EXCLUDE})); then
    _CMD_ALERT_EXCLUDE=(
        git gdn gh
        claude opencode oc codex
        btop htop top
        docker lazydocker lazygit ssh
        less more man
        vim nvim v vi nano bat diffnav
        psql sqlite3 tmux
        jiru
        fg bg
    )
fi

# path to cmd-alert.sh: ${(%):-%x} is the currently-sourced file in zsh ($0
# is the shell name)
_CMD_ALERT_SCRIPT="${_CMD_ALERT_SCRIPT:-${${(%):-%x}:A:h}/cmd-alert.sh}"

_cmd_alert_preexec() {
    _cmd_alert_exit=0

    # short label from what was typed ($1). :t is the basename
    local cmd="$1"
    local -a words
    words=("${(z)cmd}")
    local first
    first="${${words[1]:-cmd}:t}"

    # $3 is what executes: alias-expanded through the whole nested chain
    # (config -> v -> cl && nvim). $2 truncates at the end of a nested alias
    # that contains a `;` (e.g. `cl`), dropping everything chained after it.
    # $2/$1 are the fallback for direct calls in tests, which pass no $3
    local exp="${3:-${2:-$cmd}}"
    local -a ewords
    ewords=("${(z)exp}")

    # the last command in the `;`/`&&`/`||` chain decides whether this is an
    # interactive launcher: a clear-then-run alias (`cl && nvim`) puts its
    # payload last. last_op_at is the word after the last chain operator, or
    # the first word when there is none
    local -i last_op_at=1
    local -i i=1
    local w
    for w in "${ewords[@]}"; do
        case "$w" in
            ';' | '&&' | '||') last_op_at=$((i + 1)) ;;
        esac
        i=$((i + 1))
    done
    local efirst
    efirst="${${ewords[$last_op_at]:-cmd}:t}"

    # single-word entries match the typed word or the last-segment word of the
    # expanded chain; multi-word entries match either as a command prefix
    local _exclude
    for _exclude in "${_CMD_ALERT_EXCLUDE[@]}"; do
        if [[ "$_exclude" == *" "* ]]; then
            if [[ "$cmd" == "$_exclude" || "$cmd" == "$_exclude "* ||
                "$exp" == "$_exclude" || "$exp" == "$_exclude "* ]]; then
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
    if ((nwords <= 3)); then
        _cmd_alert_label="${first}${words[2]:+ ${words[2]}}${words[3]:+ ${words[3]}}"
    else
        _cmd_alert_label="${first} ${words[2]}…"
    fi

    # strip colons (delimiter in the alerts file), escape '#' (tmux format
    # injection) and cap the length
    _cmd_alert_label="${_cmd_alert_label//:/ }"
    _cmd_alert_label="${_cmd_alert_label//\#/##}"
    _cmd_alert_label="${_cmd_alert_label:0:80}"

    # keep the full command as typed for proclist rerun (R). $1 is pre-expansion,
    # so $VAR references stay references (re-expanded by the shell on rerun, not
    # stored as values). collapse tabs/newlines so one finished row stays one line
    _cmd_alert_cmd="${cmd//$'\n'/ }"
    _cmd_alert_cmd="${_cmd_alert_cmd//$'\t'/ }"

    # origin pane, so the alert lands on the window the command ran in
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
            >"$_CMD_RUNNING_DIR/${_cmd_alert_pane#%}" 2>/dev/null
    fi
}

# must run first in precmd so $? is captured before other precmd functions clobber it
_cmd_alert_precmd() {
    local exit_code=$?

    # no command in flight
    if ((_cmd_alert_start < 0)) || [[ -z "$_cmd_alert_label" ]]; then
        return
    fi

    _cmd_alert_exit=$exit_code
    local elapsed=$((SECONDS - _cmd_alert_start))
    _cmd_alert_start=-1

    # drop the in-flight registry entry, for every tracked command regardless
    # of the alert threshold
    if [[ -n "$_cmd_alert_pane" ]]; then
        rm -f "$_CMD_RUNNING_DIR/${_cmd_alert_pane#%}" 2>/dev/null
    fi

    # proclist's x binding marks an intentional kill before it interrupts the
    # pane: skip the finished row and the alert. a typed Ctrl-C has no marker
    if [[ -n "$_cmd_alert_pane" ]]; then
        local _suppress_marker="$_CMD_SUPPRESS_DIR/${_cmd_alert_pane#%}"
        if [[ -e "$_suppress_marker" ]]; then
            rm -f "$_suppress_marker" 2>/dev/null
            _cmd_alert_label=""
            _cmd_alert_cmd=""
            _cmd_alert_pane=""
            return
        fi
    fi

    # only alert inside tmux and past the threshold
    if [[ -z "${TMUX:-}" ]] || ((elapsed < _CMD_ALERT_MIN_SECONDS)); then
        _cmd_alert_label=""
        _cmd_alert_cmd=""
        _cmd_alert_pane=""
        return
    fi

    # finished-process history (proclist "done" rows), written regardless of the
    # view guard below. the origin pane is targeted explicitly: a bare
    # `display-message -p` resolves to the origin session's active window
    local _meta=""
    if [[ -n "$_cmd_alert_pane" ]]; then
        _meta=$(tmux display-message -t "$_cmd_alert_pane" -p $'#S\t#{window_id}\t#W' 2>/dev/null) || _meta=""
    fi
    if [[ -n "$_meta" ]]; then
        local _sess _wid _wname
        IFS=$'\t' read -r _sess _wid _wname <<<"$_meta"
        [[ -d "${_CMD_FINISHED_FILE:h}" ]] || mkdir -p "${_CMD_FINISHED_FILE:h}" 2>/dev/null
        printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
            "${EPOCHSECONDS:-0}" "$_cmd_alert_exit" "$_sess" "$_wid" "$_wname" "$_cmd_alert_label" "$_cmd_alert_cmd" \
            >>"$_CMD_FINISHED_FILE" 2>/dev/null
    fi

    # view guard: alert only when no attached client is viewing the origin pane.
    # matching it against every client's active pane covers both window and
    # session switches
    if [[ -n "$_cmd_alert_pane" ]]; then
        local _cp _watching=0
        while IFS= read -r _cp; do
            [[ "$_cp" == "$_cmd_alert_pane" ]] && {
                _watching=1
                break
            }
        done < <(tmux list-clients -F '#{pane_id}' 2>/dev/null)
        if ((_watching)); then
            _cmd_alert_label=""
            _cmd_alert_cmd=""
            _cmd_alert_pane=""
            return
        fi
    fi

    # pass the origin pane so the alert lands on its window
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
