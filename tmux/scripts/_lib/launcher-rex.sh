#!/usr/bin/env bash
# build a resolved launcher (launcher-data.sh) as a rex session. a named
# window's name is its tab label; an auto-rename or unnamed window keeps rex's
# default label
# source this file: source "${BASH_SOURCE%/*}/../_lib/launcher-rex.sh"

[[ -n "${_TMUX_LAUNCHER_REX_SH_LOADED:-}" ]] && return 0
_TMUX_LAUNCHER_REX_SH_LOADED=1

REX_SHELL_FLAVOR="com.superlogical.terminal.shell"

_rex_session_api() {
    rex api call -s "$1" "session.$2" "$3"
}

rex_sessions() {
    rex ls --json | jq -r '.sessions[].label // empty'
}

rex_session_id() {
    rex ls --json | jq -r --arg l "$1" '[.sessions[] | select(.label == $l)][0].session_id // empty'
}

rex_session_exists() {
    [[ -n "$(rex_session_id "$1")" ]]
}

# the app to show sessions in: the one that opened the picker, else the local
# app, else any connected one
_rex_app_client() {
    if [[ -n "${PICK_CLIENT:-}" ]]; then
        printf '%s\n' "$PICK_CLIENT"
        return
    fi
    rex client ls --json | jq -r '
        [.clients[] | select(.info.kind == "app" and .connection_state == "connected")] |
        (map(select(.principal.kind == "peer")) + .)[0].client_id // empty'
}

# the app drops a select for a session it hasn't loaded yet and still reports
# success, so wait for it to attach first
# usage: _rex_select SESSION_ID WINDOW_ID
_rex_select() {
    local client
    client=$(_rex_app_client)
    for _ in {1..40}; do
        _rex_session_api "$1" list_clients '{}' |
            jq -e --arg c "$client" 'any(.clients[]; .client_id == $c)' >/dev/null && break
        sleep 0.025
    done
    rex --timeout 3s api call client.perform "$(jq -nc --arg c "$client" --arg s "$1" --arg w "$2" \
        '{client_id: $c, action: "session.select", args: {session_id: $s, window_id: $w}}')" >/dev/null
}

rex_focus_session() {
    local sid window
    sid=$(rex_session_id "$1")
    window=$(_rex_session_api "$sid" view '{}' | jq -r '.active_window_id')
    _rex_select "$sid" "$window"
}

# each window's panes as a split tree, in the order session.create returns
# block ids: splitting pane <of> replaces its leaf with {before: <of>, after: <new>}
# shellcheck disable=SC2016 # jq source
_REX_TREE_JQ='
    def tree: reduce (.panes | to_entries[1:][]) as $e ({pane: 1};
        def put: if .split then (.split.before |= put) | (.split.after |= put)
            elif .pane == $e.value.of then
                {split: {direction: (if $e.value.split == "h" then "horizontal" else "vertical" end),
                    ratio: ((100 - ($e.value.size // 50)) / 100), before: ., after: {pane: ($e.key + 1)}}}
            else . end;
        put);
    def leaves: if .split then (.split.before | leaves), (.split.after | leaves) else .pane end;'

# usage: rex_payload RESOLVED_JSON
# shellcheck disable=SC2016 # jq source
rex_payload() {
    jq -c --arg f "$REX_SHELL_FLAVOR" "$_REX_TREE_JQ"'
        {label: .session, initial_windows: [.windows[] | . as $w |
            (if $w.name != null and ($w.auto_rename | not) then {window_label: $w.name} else {} end) + {layout: (tree |
            def node: if .split then {split: (.split | {direction, ratio, before: (.before | node), after: (.after | node)})}
                else ($w.panes[.pane - 1]) as $p |
                    {block: ({flavor: $f, options: ({cwd: $p.dir}
                        + (if $p.cmd != "" then {initial_input: ($p.cmd + "\r")} else {} end))})}
                end;
            node)}]}' <<<"$1"
}

# the block to focus in each window, active window last so it stays active:
# "<window index> <block index>" with the block index in session.create order
# shellcheck disable=SC2016 # jq source
_rex_focus_order() {
    jq -r "$_REX_TREE_JQ"'
        .windows | to_entries | (map(select(.value.focus | not)) + map(select(.value.focus))) | .[] |
        .key as $i | .value | ([.panes[] | .focus] | index(true) + 1) as $fp |
        "\($i) \([tree | leaves] | index($fp))"' <<<"$1"
}

# usage: rex_launch RESOLVED_JSON
rex_launch() {
    local json="$1" session created sid win="" block i k
    session=$(jq -r .session <<<"$json")
    if rex_session_exists "$session"; then
        rex_focus_session "$session"
        return
    fi
    created=$(rex api call session.create "$(rex_payload "$json")")
    sid=$(jq -r '.session_id' <<<"$created")
    while read -r i k; do
        win=$(jq -r --argjson i "$i" '.initial_windows[$i].window_id' <<<"$created")
        block=$(jq -r --argjson i "$i" --argjson k "$k" '.initial_windows[$i].block_ids[$k]' <<<"$created")
        _rex_session_api "$sid" focus_block "$(jq -nc --arg b "$block" '{block_id: $b}')" >/dev/null
    done < <(_rex_focus_order "$json")
    _rex_select "$sid" "$win"
}
