#!/usr/bin/env bash
# agent alert utilities for tmux scripts
# source this file after common.sh

[[ -n "${_TMUX_ALERTS_SH_LOADED:-}" ]] && return 0
_TMUX_ALERTS_SH_LOADED=1

# tests override ALERTS_FILE
if [[ -z "${ALERTS_FILE:-}" ]]; then
    readonly ALERTS_FILE="${XDG_CONFIG_HOME:-$HOME/.config}/tmux-alerts/alerts"
fi

# running-process registry: one file per pane (named by pane number) holding an
# in-flight tracked command. written by the zsh preexec hook, removed by precmd.
# kept in sync with _CMD_RUNNING_DIR in scripts/hooks/cmd-alert-hook.zsh
if [[ -z "${RUNNING_DIR:-}" ]]; then
    readonly RUNNING_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/tmux-alerts/running"
fi

# finished-process history: appended when a tracked command completes, whichever
# window is in view (the alerts file records only out-of-view results for the
# status bar). feeds the proclist "done" rows.
# kept in sync with _CMD_FINISHED_FILE in scripts/hooks/cmd-alert-hook.zsh
# fields: finish_epoch<tab>exit_code<tab>session<tab>window_id<tab>window<tab>label<tab>cmd
# (cmd is the full command as typed, for proclist rerun; a row may lack it)
if [[ -z "${FINISHED_FILE:-}" ]]; then
    readonly FINISHED_FILE="${XDG_CONFIG_HOME:-$HOME/.config}/tmux-alerts/finished"
fi

# kill-suppress markers: one file per pane, touched by proclist-action.sh
# right before it sends the interrupting Ctrl-C. the shell's precmd hook
# checks for this marker on completion and, if present, skips both the
# finished-history row and the status-right alert, since the kill was
# intentional rather than a run-to-completion result. kept in sync with
# _CMD_SUPPRESS_DIR in scripts/hooks/cmd-alert-hook.zsh
if [[ -z "${SUPPRESS_DIR:-}" ]]; then
    readonly SUPPRESS_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/tmux-alerts/suppress"
fi

# agent-state registry: one file per pane (named by pane id, e.g. %12) holding
# the last hook-reported state for the agent running in it. written by
# scripts/hooks/agent-state.sh, removed on SessionEnd and by stale-file GC.
# fields: agent<tab>state<tab>epoch<tab>event<tab>session_id<tab>cwd
# (cwd last so an embedded tab can't shift earlier fields)
if [[ -z "${AGENT_STATE_DIR:-}" ]]; then
    readonly AGENT_STATE_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/tmux-alerts/agent-state"
fi

# alert file format: session:window:agent:window_id
# window_id is the dismiss and GC key: automatic-rename rewrites the window
# name from the agent's pane title while the alert is live, so a name-keyed
# row is unmatchable by the time the clear runs. the name stays in the row for
# display and is refreshed whenever the alert is re-set. three-field rows (no
# id) match on name alone

# percent-encode a window name for the colon-delimited alerts file: tmux allows
# colons in window names. '%' is encoded before ':' so the transform is reversible
# usage: encoded=$(alerts_encode_window "$window_name")
alerts_encode_window() {
    local s="$1"
    s="${s//%/%25}"
    s="${s//:/%3A}"
    printf '%s' "$s"
}

# inverse of alerts_encode_window. decode ':' before '%' to mirror the encode
# order so a literal "%3A" in the original name survives the round-trip
# usage: name=$(alerts_decode_window "$encoded")
alerts_decode_window() {
    local s="$1"
    s="${s//%3A/:}"
    s="${s//%25/%}"
    printf '%s' "$s"
}

# ansi-colour a string: _ansi "#rrggbb" "text"
_ansi() {
    local c="$1" text="$2"
    printf '\033[38;2;%d;%d;%dm%s\033[0m' \
        "0x${c:1:2}" "0x${c:3:2}" "0x${c:5:2}" "$text"
}

# humanise elapsed seconds: 45s, 12m, 1h03m
_fmt_elapsed() {
    local s="$1"
    if ((s < 60)); then
        printf '%ds' "$s"
    elif ((s < 3600)); then
        printf '%dm' "$((s / 60))"
    else
        printf '%dh%02dm' "$((s / 3600))" "$(((s % 3600) / 60))"
    fi
}

# get agent icon (compatible with bash 3.2, no associative arrays)
# usage: get_agent_icon "agent_name"
get_agent_icon() {
    local agent="$1"
    case "$agent" in
        claude) echo "⚡" ;;
        codex) echo "⌘" ;;
        opencode) echo "" ;;
        copilot) echo "" ;;
        *) echo "󱜙" ;;
    esac
}

# get agent colour (compatible with bash 3.2, no associative arrays)
# usage: get_agent_colour "agent_name"
get_agent_colour() {
    local agent="$1"
    case "$agent" in
        claude) echo "#f1fa8c" ;;   # yellow
        codex) echo "#50fa7b" ;;    # dracula green (matches codex logo)
        opencode) echo "#bd93f9" ;; # dracula purple
        copilot) echo "#58a6ff" ;;  # GitHub blue
        *) echo "#6272a4" ;;        # dracula blue
    esac
}

# get agent display icon and colour (inlined to avoid subshell forks)
# usage: get_agent_display "agent_name"
# returns: "icon|colour"
get_agent_display() {
    case "$1" in
        claude) echo "⚡|#f1fa8c" ;;
        codex) echo "⌘|#50fa7b" ;;
        opencode) echo "|#bd93f9" ;;
        copilot) echo "|#58a6ff" ;;
        *) echo "󱜙|#6272a4" ;;
    esac
}

# get agent state display icon and colour (inlined to avoid subshell forks)
# states come from the agent-state registry; "stuck" is derived at render time
# usage: get_agent_state_display "state"
# returns: "icon|colour"
get_agent_state_display() {
    case "$1" in
        working) echo "●|#d8a657" ;;     # amber: in progress
        needs-input) echo "◐|#f1fa8c" ;; # yellow: waiting on permission/question
        idle) echo "○|#8a8f98" ;;        # muted grey: finished, awaiting prompt
        error) echo "✗|#c07878" ;;       # muted red: turn died on an API error
        stuck) echo "⚠|#d77757" ;;       # terracotta: working but no recent activity
        *) echo "·|#6272a4" ;;           # unknown: no state recorded
    esac
}

# a shell reports a signal death as exit code 128+N (SIGINT 130, SIGTERM 143,
# SIGKILL 137, SIGHUP 129). those are interruptions, not run-to-completion
# failures, so they get a neutral state rather than the red ✗
_exit_code_is_signal() {
    [[ "$1" =~ ^[0-9]+$ ]] && (($1 > 128))
}

# exit code icon (separate from agent icons)
# usage: get_exit_code_icon "exit_code"
get_exit_code_icon() {
    local code="$1"
    _exit_code_is_signal "$code" && {
        echo "⊘"
        return
    }
    case "$code" in
        0) echo "✓" ;;
        *) echo "✗" ;;
    esac
}

# exit code colour
# usage: get_exit_code_colour "exit_code"
get_exit_code_colour() {
    local code="$1"
    _exit_code_is_signal "$code" && {
        echo "#8a8f98"
        return
    } # muted grey
    case "$code" in
        0) echo "#7aab88" ;; # muted green
        *) echo "#c07878" ;; # muted red
    esac
}

# running-process display (combined icon|colour, avoids subshell forks)
# distinct from the ✓/✗ exit icons: an in-flight command has no exit code yet
# usage: get_running_display
get_running_display() {
    echo "●|#d8a657" # amber: in progress
}

# exit code display (combined icon|colour, avoids subshell forks)
# usage: get_exit_code_display "exit_code"
get_exit_code_display() {
    local code="$1"
    _exit_code_is_signal "$code" && {
        echo "⊘|#8a8f98"
        return
    } # interrupted
    case "$code" in
        0) echo "✓|#7aab88" ;;
        *) echo "✗|#c07878" ;;
    esac
}

# build alert icon string from tmux window options output
# usage: icons=$(get_window_alert_icons "$opts")
# returns: ANSI-coloured icon string (empty if no alerts)
get_window_alert_icons() {
    local opts="$1"
    local icons=""

    # exit alert
    if printf '%s\n' "$opts" | grep -q '^@exit_alert '; then
        local exit_code exit_label display icon colour
        exit_code=$(printf '%s\n' "$opts" | grep '^@exit_alert_code ' | cut -d' ' -f2)
        exit_label=$(printf '%s\n' "$opts" | grep '^@exit_alert_label ' | cut -d' ' -f2-)
        exit_label="${exit_label#\"}"
        exit_label="${exit_label%\"}"
        # escape '#' to prevent tmux format injection
        exit_label="${exit_label//\#/##}"
        display=$(get_exit_code_display "$exit_code")
        icon="${display%%|*}"
        colour="${display##*|}"
        icons="${icons}\033[38;2;$(printf '%d;%d;%d' "0x${colour:1:2}" "0x${colour:3:2}" "0x${colour:5:2}")m${icon} ${exit_label}\033[0m "
    fi

    # agent alerts
    local agent
    for agent in claude codex opencode copilot; do
        if printf '%s\n' "$opts" | grep -q "^@${agent}_alert "; then
            display=$(get_agent_display "$agent")
            icon="${display%%|*}"
            colour="${display##*|}"
            # apply colour only for non-emoji icons (emojis are self-coloured)
            case "$agent" in
                copilot)
                    icons="${icons}\033[38;2;$(printf '%d;%d;%d' "0x${colour:1:2}" "0x${colour:3:2}" "0x${colour:5:2}")m${icon}\033[0m "
                    ;;
                *)
                    icons="${icons}${icon} "
                    ;;
            esac
        fi
    done

    printf '%s' "$icons"
}

# build alert icons from pre-read alerts file content
# avoids per-window tmux calls by reading the flat file once
# usage: icons=$(build_alert_icons "$alerts_content" "^session_name:" [dedupe])
#   $1 - full alerts file content (pre-read)
#   $2 - grep pattern to filter entries (e.g. "^mysession:" or "^mysession:mywindow:")
#   $3 - optional: pass "dedupe" to deduplicate agent icons across entries
# returns: ANSI-coloured icon string (empty if no alerts match)
build_alert_icons() {
    local alerts_content="$1"
    local pattern="$2"
    local dedupe="${3:-}"

    [[ -z "$alerts_content" ]] && return

    local icons="" seen_agents="" display icon colour line prefix

    case "$pattern" in
        ^*:*)
            prefix="${pattern#^}"
            prefix="${prefix%:}"
            ;;
        *) prefix="" ;;
    esac

    while IFS= read -r line; do
        [[ -n "$line" ]] || continue
        [[ -n "$prefix" && "$line" != "$prefix:"* ]] && continue

        IFS=: read -r _sess _win field3 rest <<<"$line"
        if [[ "$field3" == "exit" ]]; then
            # exit alert: rest is "window_id:code:label" (id is the match key)
            local _cl="${rest#*:}"
            local code="${_cl%%:*}"
            local label="${_cl#*:}"
            # escape '#' to prevent tmux format injection
            label="${label//\#/##}"
            display=$(get_exit_code_display "$code")
            icon="${display%%|*}"
            colour="${display##*|}"
            icons="${icons}\033[38;2;$(printf '%d;%d;%d' "0x${colour:1:2}" "0x${colour:3:2}" "0x${colour:5:2}")m${icon} ${label}\033[0m "
        else
            # agent alert: field3 is agent name
            local agent="$field3"
            if [[ "$dedupe" == "dedupe" ]]; then
                case "$seen_agents" in *"|${agent}|"*) continue ;; esac
                seen_agents="${seen_agents}|${agent}|"
            fi
            display=$(get_agent_display "$agent")
            icon="${display%%|*}"
            colour="${display##*|}"
            case "$agent" in
                copilot)
                    icons="${icons}\033[38;2;$(printf '%d;%d;%d' "0x${colour:1:2}" "0x${colour:3:2}" "0x${colour:5:2}")m${icon}\033[0m "
                    ;;
                *)
                    icons="${icons}${icon} "
                    ;;
            esac
        fi
    done <<<"$alerts_content"

    printf '%s' "$icons"
}

# test pre-read alerts content for an agent row on a given window. matches on
# window_id where the row has one and on session:window otherwise, so a name
# that drifted under automatic-rename between the alert and the lookup still
# resolves. the window name is passed raw and encoded here
# usage: alerts_has_agent "$content" "agent" "session" "window" ["window_id"]
alerts_has_agent() {
    local content="$1" agent="$2" session="$3" window="$4" window_id="${5:-}"

    [[ -n "$content" ]] || return 1

    awk -F: -v a="$agent" -v s="$session" -v w="$(alerts_encode_window "$window")" \
        -v i="$window_id" '
        $3 != a { next }
        (i != "" && $4 == i) { found = 1; exit }
        ($4 == "" && $1 == s && $2 == w) { found = 1; exit }
        END { exit !found }
    ' <<<"$content"
}

# set an exit code alert for the current window
# usage: set_exit_alert "exit_code" "label" [ring_bell]
# sets @exit_alert* window options and adds a 6-field entry to the alerts file
# (session:window:exit:window_id:code:label); the id is the dismiss/GC key
set_exit_alert() {
    local code="$1"
    local label="$2"
    local ring_bell="${3:-true}"

    local alerts_dir
    alerts_dir="$(dirname "$ALERTS_FILE")"
    if [[ ! -d "$alerts_dir" ]]; then
        mkdir -p "$alerts_dir"
        chmod 700 "$alerts_dir"
    fi

    local colour
    colour="$(get_exit_code_colour "$code")"

    # determine the window target, prefer TMUX_PANE (a pane ID like %12) since
    # it's set to the origin pane by cmd-alert.sh and works even when we've
    # switched windows. tmux accepts pane IDs directly as -wt targets
    local target=""
    if [[ -n "${TMUX_PANE:-}" ]]; then
        target="$TMUX_PANE"
    fi

    if [[ -n "$target" ]]; then
        tmux set-option -wt "$target" "@exit_alert" 1 2>/dev/null
        tmux set-option -wt "$target" "@exit_alert_colour" "$colour" 2>/dev/null
        tmux set-option -wt "$target" "@exit_alert_code" "$code" 2>/dev/null
        tmux set-option -wt "$target" "@exit_alert_label" "$label" 2>/dev/null
    fi

    # resolve session, window id and window name for the alerts file. the id is
    # the authoritative match key (stable for the server's life, never reused);
    # the name is volatile under automatic-rename and kept only for legacy
    # prefix maintenance. one round-trip, window name last so an embedded tab
    # can't shift the earlier fields
    local sess="" win="" wid="" _meta=""
    if [[ -n "${TMUX_PANE:-}" ]]; then
        _meta=$(tmux display-message -t "$TMUX_PANE" -p $'#S\t#{window_id}\t#W' 2>/dev/null || true)
    fi
    if [[ -z "$_meta" && -n "${TMUX:-}" ]]; then
        _meta=$(tmux display-message -p $'#S\t#{window_id}\t#W' 2>/dev/null || true)
    fi
    [[ -n "$_meta" ]] && IFS=$'\t' read -r sess wid win <<<"$_meta"

    # add window to alerts file (6-field format:
    # session:window:exit:window_id:code:label). window_id is the dismiss/GC key
    # session: alnum, dot, underscore, hyphen
    # window: any non-control chars (allows spaces and colons); colons are
    # percent-encoded so they don't collide with the field separator
    if [[ -n "$wid" ]] && [[ "$sess" =~ ^[a-zA-Z0-9._-]+$ ]] && [[ "$win" =~ ^[^[:cntrl:]]+$ ]]; then
        local enc_win
        enc_win=$(alerts_encode_window "$win")
        local entry="${sess}:${enc_win}:exit:${wid}:${code}:${label}"
        grep -qxF "$entry" "$ALERTS_FILE" 2>/dev/null || echo "$entry" >>"$ALERTS_FILE"
    fi

    # ring the bell at the attached client terminal(s), not the origin pane: a pane
    # bell trips monitor-bell and leaves a window_bell_flag that the proclist dismiss
    # can't clear. the @exit_alert option already marks the window
    if [[ "$ring_bell" == "true" ]]; then
        local _ctty
        while IFS= read -r _ctty; do
            [[ -n "$_ctty" && -w "$_ctty" ]] && printf '\a' >"$_ctty" 2>/dev/null
        done < <(tmux list-clients -F '#{client_tty}' 2>/dev/null)
    fi
}

# set an alert for the current window
# usage: set_window_alert "agent_name" [ring_bell]
# sets tmux window option and adds to alerts file
set_window_alert() {
    local agent="${1:-claude}"
    local ring_bell="${2:-true}"

    case "$agent" in
        claude | codex | opencode | copilot) ;;
        *) return 1 ;;
    esac

    local alerts_dir
    alerts_dir="$(dirname "$ALERTS_FILE")"
    if [[ ! -d "$alerts_dir" ]]; then
        mkdir -p "$alerts_dir"
        chmod 700 "$alerts_dir"
    fi

    # one round-trip for session, window id and window name, tab-joined with the
    # name last so a colon or an embedded tab in it can't shift the other fields
    local sess="" win="" wid="" _meta=""
    if [[ -n "${TMUX_PANE:-}" ]]; then
        _meta=$(tmux display-message -t "$TMUX_PANE" -p $'#S\t#{window_id}\t#W' 2>/dev/null || true)
    fi
    if [[ -z "$_meta" && -n "${TMUX:-}" ]]; then
        _meta=$(tmux display-message -p $'#S\t#{window_id}\t#W' 2>/dev/null || true)
    fi
    [[ -n "$_meta" ]] && IFS=$'\t' read -r sess wid win <<<"$_meta"

    # set the @agent_alert window option. prefer the origin pane id, it's
    # unambiguous even when the window name contains a colon or spaces
    if [[ -n "${TMUX_PANE:-}" ]]; then
        tmux set-option -wt "$TMUX_PANE" "@${agent}_alert" 1 2>/dev/null
    elif [[ -n "$sess" ]]; then
        tmux set-option -wt "${sess}:${win}" "@${agent}_alert" 1 2>/dev/null
    fi

    # add or refresh this window's row. the window id is the row identity, so a
    # re-set after automatic-rename rewrites the drifted name in place instead
    # of appending a second row for the same window
    # session: alnum, dot, underscore, hyphen
    # window: any non-control chars (allows spaces and colons); colons are
    # percent-encoded so they don't collide with the field separator
    if [[ "$sess" =~ ^[a-zA-Z0-9._-]+$ ]] && [[ "$win" =~ ^[^[:cntrl:]]+$ ]]; then
        local enc_win entry
        enc_win=$(alerts_encode_window "$win")
        entry="${sess}:${enc_win}:${agent}${wid:+:$wid}"
        if [[ -n "$wid" ]] && _acquire_alerts_lock; then
            local tmp_file
            tmp_file=$(mktemp "${ALERTS_FILE}.tmp.XXXXXX")
            awk -F: -v a="$agent" -v w="$wid" '!($3 == a && $4 == w)' \
                "$ALERTS_FILE" 2>/dev/null >>"$tmp_file"
            echo "$entry" >>"$tmp_file"
            mv "$tmp_file" "$ALERTS_FILE" 2>/dev/null || rm -f "$tmp_file" 2>/dev/null
            _release_alerts_lock
        else
            grep -qxF "$entry" "$ALERTS_FILE" 2>/dev/null || echo "$entry" >>"$ALERTS_FILE"
        fi
    fi

    if [[ "$ring_bell" == "true" ]]; then
        {
            if [[ -w /dev/tty ]]; then
                printf '\a' >/dev/tty
            fi
        } 2>/dev/null || true
    fi
}

# file locking: mkdir is the atomic lock primitive. acquisition retries with a
# short backoff, and a lock whose holder PID is dead is removed and retried
#
# grep exit codes: 0 (lines matched) and 1 (no matches, file cleared) are both
# valid; 2+ is an error

# returns 1 when the lock can't be acquired
_acquire_alerts_lock() {
    local lock_dir="${ALERTS_FILE}.lock"
    local pid_file="${lock_dir}/pid"

    for _ in {1..10}; do
        if mkdir "$lock_dir" 2>/dev/null; then
            echo $$ >"$pid_file" 2>/dev/null
            return 0
        fi

        if [[ -f "$pid_file" ]]; then
            local holder_pid
            holder_pid=$(cat "$pid_file" 2>/dev/null) || true
            if [[ -n "$holder_pid" ]] && ! kill -0 "$holder_pid" 2>/dev/null; then
                rmdir "$lock_dir" 2>/dev/null || rm -rf "$lock_dir" 2>/dev/null || true
                continue
            fi
        fi

        sleep 0.1
    done

    return 1
}

_release_alerts_lock() {
    local lock_dir="${ALERTS_FILE}.lock"
    rm -f "${lock_dir}/pid" 2>/dev/null
    rmdir "$lock_dir" 2>/dev/null || true
}

# drop finished-history rows for a window so "done" rows clear once viewed.
# keyed on window_id (field 4), which tmux never reuses within a server lifetime.
# no-op without an id
# usage: clear_window_finished "window_id"
clear_window_finished() {
    local window_id="$1"
    [[ -n "$window_id" && -f "$FINISHED_FILE" ]] || return 0

    # fast path: skip the rewrite when this window has no finished rows. a stray
    # field-4-shaped match in a label only costs a no-op rewrite, never a miss
    grep -qF "$window_id" "$FINISHED_FILE" 2>/dev/null || return 0

    local tmpf
    tmpf=$(mktemp "${FINISHED_FILE}.XXXXXX") || return 0
    if awk -F'\t' -v w="$window_id" '$4 != w' "$FINISHED_FILE" >"$tmpf" 2>/dev/null; then
        mv "$tmpf" "$FINISHED_FILE" 2>/dev/null || rm -f "$tmpf"
    else
        rm -f "$tmpf"
    fi
}

# drop finished-history rows for a whole session (field 3), including rows for
# windows that already closed. a row written before a session rename keeps the
# old name and ages out via the picker
# usage: clear_session_finished "session"
clear_session_finished() {
    local session="$1"
    [[ -n "$session" && -f "$FINISHED_FILE" ]] || return 0

    # fast path: skip the rewrite when this session has no finished rows. a stray
    # field-3-shaped match in a label only costs a no-op rewrite, never a miss
    grep -qF "$session" "$FINISHED_FILE" 2>/dev/null || return 0

    local tmpf
    tmpf=$(mktemp "${FINISHED_FILE}.XXXXXX") || return 0
    if awk -F'\t' -v s="$session" '$3 != s' "$FINISHED_FILE" >"$tmpf" 2>/dev/null; then
        mv "$tmpf" "$FINISHED_FILE" 2>/dev/null || rm -f "$tmpf"
    else
        rm -f "$tmpf"
    fi
}

# drop a window's exit alert: the @exit_alert* options plus its exit line in the
# alerts file. agent alerts on the same window stay. keyed on window_id (alerts
# file field 4), which is stable under automatic-rename
# usage: clear_window_exit_alert "window_id"
clear_window_exit_alert() {
    local window_id="$1"
    [[ -n "$window_id" ]] || return 0

    local opt
    for opt in @exit_alert @exit_alert_code @exit_alert_label @exit_alert_colour; do
        tmux set-option -wt "$window_id" -u "$opt" 2>/dev/null || true
    done

    # remove the matching exit line from the alerts file (used by show.sh).
    # fields are colon-clean (session restricted, name percent-encoded, id/code
    # colon-free), so -F: splits exit lines into exactly session:window:exit:id:…
    [[ -f "$ALERTS_FILE" ]] || return 0
    _acquire_alerts_lock || return 0
    local tmp_file
    tmp_file=$(mktemp "${ALERTS_FILE}.tmp.XXXXXX")
    if awk -F: -v w="$window_id" '!($3 == "exit" && $4 == w)' "$ALERTS_FILE" >"$tmp_file" 2>/dev/null; then
        mv "$tmp_file" "$ALERTS_FILE" 2>/dev/null || rm -f "$tmp_file" 2>/dev/null
    else
        rm -f "$tmp_file" 2>/dev/null
    fi
    _release_alerts_lock
}

# clear all alerts for a specific window
# usage: clear_window_alerts "session" "window" ["window_id"]
clear_window_alerts() {
    local session="$1"
    local window="$2"
    local window_id="${3:-}"

    # finished-process rows clear on the same select that dismisses alerts
    clear_window_finished "$window_id"

    # remove from alerts file (any agent) with file locking. window_id (field 4
    # on both agent and exit rows) is the primary key because the stored name
    # drifts under automatic-rename; the session:window match covers rows without
    # an id (names are stored percent-encoded, so encode the lookup)
    if [[ -f "$ALERTS_FILE" ]] && _acquire_alerts_lock; then
        local tmp_file enc_window
        tmp_file=$(mktemp "${ALERTS_FILE}.tmp.XXXXXX")
        enc_window=$(alerts_encode_window "$window")
        if awk -F: -v s="$session" -v w="$enc_window" -v wid="$window_id" '
            ($1 == s && $2 == w) { next }
            (wid != "" && $4 == wid) { next }
            { print }
        ' "$ALERTS_FILE" >"$tmp_file" 2>/dev/null; then
            mv "$tmp_file" "$ALERTS_FILE" 2>/dev/null || rm -f "$tmp_file" 2>/dev/null
        else
            rm -f "$tmp_file" 2>/dev/null
        fi

        _release_alerts_lock
    fi

    # unset all @*_alert window options (agent-agnostic wildcard clearing)
    local target
    if [[ -n "$window_id" ]]; then
        target="$window_id"
    else
        target="${session}:${window}"
    fi

    local alert_options
    alert_options=$(tmux show-options -wt "$target" 2>/dev/null | grep '@.*_alert' | cut -d' ' -f1 || true)

    if [[ -n "$alert_options" ]]; then
        while IFS= read -r option; do
            tmux set-option -wt "$target" -u "$option" 2>/dev/null || true
        done <<<"$alert_options"
    fi
}

# clean up stale alerts (for windows/sessions that no longer exist)
cleanup_stale_alerts() {
    # the rename hooks call this on every automatic rename, so keep the
    # no-alerts case to a single stat
    [[ -s "$ALERTS_FILE" ]] || return 0

    _acquire_alerts_lock || return 1

    local tmp_file
    tmp_file=$(mktemp "${ALERTS_FILE}.tmp.XXXXXX")
    local cleaned=0

    # prefetch every live window once: this runs on every automatic rename, where
    # a has-session plus list-windows round-trip per row forks too often
    local live
    live=$(tmux list-windows -a -F $'#{session_name}\t#{window_id}\t#{window_name}' 2>/dev/null) || live=""
    if [[ -z "$live" ]]; then
        rm -f "$tmp_file"
        _release_alerts_lock
        return 0
    fi

    # read each alert and verify its target window still exists. rows carry the
    # window id in field 4 (agent rows: session:window:agent:window_id, exit
    # rows: session:window:exit:window_id:code:label) and are validated on it;
    # rows without an id fall back to the window name
    while IFS= read -r line; do
        IFS=':' read -r session window field3 field4 _rest <<<"$line"

        # validate format, need at least session, window, and one more field
        if [[ -z "$session" || -z "$window" || -z "$field3" ]]; then
            cleaned=1
            continue
        fi

        local live_name=""
        if [[ -n "$field4" ]]; then
            live_name=$(awk -F'\t' -v s="$session" -v i="$field4" \
                '$1 == s && $2 == i { print $3; exit }' <<<"$live")
            if [[ -z "$live_name" ]]; then
                cleaned=1
                continue
            fi
        elif [[ "$field3" == "exit" ]]; then
            # an exit row with no id can't be validated
            cleaned=1
            continue
        else
            # agent row without an id: the percent-encoded name is the only key
            local decoded_window
            decoded_window=$(alerts_decode_window "$window")
            if ! awk -F'\t' -v s="$session" -v n="$decoded_window" \
                '$1 == s && $3 == n { found = 1; exit } END { exit !found }' <<<"$live"; then
                cleaned=1
                continue
            fi
        fi

        # refresh a drifted agent-row name so the picker and status bar show
        # what the window is called now, not what it was called when it alerted
        if [[ "$field3" != "exit" && -n "$live_name" ]]; then
            local enc_live
            enc_live=$(alerts_encode_window "$live_name")
            if [[ "$enc_live" != "$window" ]]; then
                line="${session}:${enc_live}:${field3}:${field4}"
                cleaned=1
            fi
        fi

        echo "$line" >>"$tmp_file"
    done <"$ALERTS_FILE"

    if [[ $cleaned -eq 1 ]]; then
        if [[ -f "$tmp_file" ]]; then
            mv "$tmp_file" "$ALERTS_FILE" 2>/dev/null
        else
            : >"$ALERTS_FILE"
        fi
    else
        rm -f "$tmp_file"
    fi

    _release_alerts_lock
}

# drop agent-state files whose pane no longer exists. per-pane files are
# independent, so no locking is needed; catches orphans left by crashed agents
# or a tmux server restart (SessionEnd handles the normal exit path)
cleanup_stale_agent_state() {
    [[ -d "$AGENT_STATE_DIR" ]] || return 0

    local live_panes
    live_panes=$(tmux list-panes -a -F '#{pane_id}' 2>/dev/null) || return 0

    local f pane
    for f in "$AGENT_STATE_DIR"/*; do
        [[ -e "$f" ]] || continue
        pane="${f##*/}"
        grep -qxF "$pane" <<<"$live_panes" || rm -f "$f"
    done
}

# update window name in alerts file (for window renames)
# usage: update_window_name_in_alerts "session" "old_window" "new_window"
update_window_name_in_alerts() {
    local session="$1"
    local old_window="$2"
    local new_window="$3"

    [[ ! -f "$ALERTS_FILE" ]] && return 0

    # window names are stored percent-encoded; encode both sides to match
    local enc_old enc_new
    enc_old=$(alerts_encode_window "$old_window")
    enc_new=$(alerts_encode_window "$new_window")

    # check if there are any alerts for this window before locking
    grep -qF "${session}:${enc_old}:" "$ALERTS_FILE" 2>/dev/null || return 0

    if ! _acquire_alerts_lock; then
        return 0
    fi

    local tmp_file
    tmp_file=$(mktemp "${ALERTS_FILE}.tmp.XXXXXX")
    local update_success=0

    if sed "s|^${session}:${enc_old}:|${session}:${enc_new}:|" "$ALERTS_FILE" >"$tmp_file" 2>/dev/null; then
        if mv "$tmp_file" "$ALERTS_FILE" 2>/dev/null; then
            update_success=1
        fi
    fi

    if [[ $update_success -eq 0 ]]; then
        rm -f "$tmp_file"
    fi

    _release_alerts_lock
}

# update session name in alerts file (for session renames)
# usage: update_session_name_in_alerts "old_session" "new_session"
update_session_name_in_alerts() {
    local old_session="$1"
    local new_session="$2"

    [[ ! -f "$ALERTS_FILE" ]] && return 0

    # check if there are any alerts for the old session before locking
    grep -qF "${old_session}:" "$ALERTS_FILE" 2>/dev/null || return 0

    if ! _acquire_alerts_lock; then
        return 0
    fi

    local tmp_file
    tmp_file=$(mktemp "${ALERTS_FILE}.tmp.XXXXXX")
    local update_success=0

    if sed "s|^${old_session}:|${new_session}:|" "$ALERTS_FILE" >"$tmp_file" 2>/dev/null; then
        if mv "$tmp_file" "$ALERTS_FILE" 2>/dev/null; then
            update_success=1
        fi
    fi

    if [[ $update_success -eq 0 ]]; then
        rm -f "$tmp_file"
    fi

    _release_alerts_lock
}

# clear all alerts for a session
# usage: clear_session_alerts "session"
clear_session_alerts() {
    local session="$1"

    # finished-process rows for every window in this session clear with it,
    # mirroring how clear_window_alerts drops a single window's rows on select
    clear_session_finished "$session"

    # remove all entries for this session from alerts file with locking
    if [[ -f "$ALERTS_FILE" ]] && _acquire_alerts_lock; then
        local tmp_file
        tmp_file=$(mktemp "${ALERTS_FILE}.tmp.XXXXXX")
        local grep_exit=0
        grep -vF "${session}:" "$ALERTS_FILE" >"$tmp_file" 2>/dev/null || grep_exit=$?

        # exit code 0 or 1 are both success (0 = matches found, 1 = no matches/all filtered)
        if [[ $grep_exit -le 1 ]]; then
            mv "$tmp_file" "$ALERTS_FILE" 2>/dev/null || rm -f "$tmp_file" 2>/dev/null
        else
            rm -f "$tmp_file" 2>/dev/null
        fi

        _release_alerts_lock
    fi

    # unset agent options for all windows in session
    local win
    for win in $(tmux list-windows -t "$session" -F '#D' 2>/dev/null); do
        local alert_options
        alert_options=$(tmux show-options -wt "$win" 2>/dev/null | grep '@.*_alert' | cut -d' ' -f1 || true)

        if [[ -n "$alert_options" ]]; then
            while IFS= read -r option; do
                tmux set-option -wt "$win" -u "$option" 2>/dev/null || true
            done <<<"$alert_options"
        fi
    done
}
