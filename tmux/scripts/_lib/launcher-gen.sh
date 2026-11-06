#!/usr/bin/env bash
# the wizard's and save session's view of a launcher file: load a <name>.toml
# into state variables, change them, write them back
# source this file: source "${BASH_SOURCE%/*}/../_lib/launcher-gen.sh"
#
#   name            launcher file name without .toml (also the @launcher tag)
#   description     one-line summary for the picker
#   session_mode    fixed, or directory (no session key: named after the
#                   directory the picker passes, no root)
#   session_kept    a loaded session key that isn't the one derived from the
#                   file name; empty = derive it from name
#   instance_mode   y = prompt for an instance suffix, n = auto
#   instance_auto   1 = the file spells out instance = "auto"
#   project_dir     root, as $HOME/..., ~/... or absolute
#   worktree_aware  y/n, resolve instance suffixes to worktree directories
#   worktrees_dir   worktree root (same forms as project_dir)
#   worktree_prefix instance <n> opens <worktrees_dir>/<prefix>-<n>-*; empty =
#                   the launcher name in capitals, written out unless
#                   prefix_absent=1 (a loaded file without one)
#   focus_window    index of the active window
#   focus_pane      its active pane, 1 = the first (every other window opens
#                   on its first pane)
#   win_names, win_cmds, win_splits (yes/no), win_split_cmds   parallel arrays;
#                   an empty name leaves the window to automatic-rename
#   win_autonames   1 = automatic-rename takes over once the window is built
#   win_dirs        window dir, the default for its panes; empty = the root
#
# a window the wizard's model can't describe (more panes, stacked splits, a
# directory per pane) is "rich": win_panes[i] holds its pane count and the
# simple fields above are ignored for it
#   win_panes       pane count per window, empty for a simple window
#   win_layouts     split steps per window, one per line: <pane> <h|v> <pct> <new>
#                   (layout_splits format, pct "-" for an even split); panes
#                   are numbered 1..N in creation order
#   pane_cmds       ["<window index>:<pane>"] command, empty for a shell
#   pane_dirs       ["<window index>:<pane>"] directory: empty = the window
#                   dir, relative = under the root, absolute or ~/... as is

[[ -n "${_TMUX_LAUNCHER_GEN_SH_LOADED:-}" ]] && return 0
_TMUX_LAUNCHER_GEN_SH_LOADED=1

# shellcheck source=tmux/scripts/_lib/launcher-data.sh
source "${BASH_SOURCE%/*}/launcher-data.sh"

declare -ga win_panes=() win_layouts=() win_autonames=() win_dirs=()
declare -gA pane_cmds=() pane_dirs=()

# copy a user launcher to LAUNCHER_BACKUPS before it's rewritten, replacing
# the previous copy
backup_launcher() {
    mkdir -p "$LAUNCHER_BACKUPS"
    cp "$1" "$LAUNCHER_BACKUPS/${1##*/}"
}

# where a pane of a rich window sits, from the split that created it:
# "top-left" for pane 1, else "right of 1" / "below 2"
# usage: pane_position_label WINDOW_INDEX PANE
pane_position_label() {
    local idx="$1" pane="$2" holder dir pct new
    if [[ "$pane" == 1 ]]; then
        printf 'top-left'
        return
    fi
    while read -r holder dir pct new; do
        [[ "$new" == "$pane" ]] || continue
        if [[ "$dir" == h ]]; then
            printf 'right of %s' "$holder"
        else
            printf 'below %s' "$holder"
        fi
        return
    done <<<"${win_layouts[$idx]:-}"
    printf 'pane %s' "$pane"
}

index_for_window() {
    local target="$1"
    local i
    for ((i = 0; i < ${#win_names[@]}; i++)); do
        if [[ "${win_names[$i]}" == "$target" ]]; then
            printf '%s' "$i"
            return 0
        fi
    done
    return 1
}

# the state assignments for a launcher's JSON, as shell code to eval
# shellcheck disable=SC2016 # jq source
_LOAD_JQ='
    def q: @sh;
    def even: has("size") | not;
    "description=\(.description // "" | q)",
    "session_mode=\(if has("session") then "fixed" else "directory" end)",
    "session_kept=\(if (.session // $derived) == $derived then "" else .session end | q)",
    "instance_mode=\(if .instance == "prompt" then "y" else "n" end)",
    "instance_auto=\(if .instance == "auto" then "1" else "" end)",
    "prefix_absent=\(if has("worktrees") and (.worktrees | has("prefix") | not) then "1" else "" end)",
    "project_dir=\(.root // "~" | q)",
    "worktree_aware=\(if has("worktrees") then "y" else "n" end)",
    "worktrees_dir=\(.worktrees.dir // "" | q)",
    "worktree_prefix=\(.worktrees.prefix // "" | q)",
    ([.window | to_entries[] | .key as $w | .value |
        (if .focus == true then [$w, 0] else empty end),
        ((.pane // []) | to_entries[] | select(.value.focus == true) | [$w, .key])] | first // [0, 0]) as [$fw, $fwp] |
    "focus_window=\($fw)", "focus_pane=\($fwp + 1)",
    (.window | to_entries[] | .key as $i | .value |
        (.pane // [{cmd}]) as $p |
        (if $i == $fw then $fwp else 0 end) as $fp |
        ([$p[] | .dir // ""] | all(. == "")) as $nodirs |
        (($p | length) == 1 or (($p | length) == 2 and $p[1].split == "h"
            and ($p[1].of // 1) == 1 and ($p[1] | even))) as $simple |
        "win_names+=(\(.name // "" | q))",
        "win_dirs+=(\(.dir // "" | q))",
        "win_autonames+=(\(if .auto_rename == true then "1" else "\"\"" end))",
        if $simple and $nodirs then
            "win_cmds+=(\($p[0].cmd // "" | q))",
            "win_splits+=(\(if ($p | length) == 2 then "yes" else "no" end))",
            "win_split_cmds+=(\($p[1].cmd // "" | q))",
            "win_panes+=(\"\")", "win_layouts+=(\"\")"
        else
            "win_cmds+=(\"\")", "win_splits+=(no)", "win_split_cmds+=(\"\")",
            "win_panes+=(\($p | length))",
            "win_layouts+=(\([$p | to_entries[1:][] |
                "\(.value.of // .key) \(.value.split) \(.value.size // "-") \(.key + 1)"] | join("\n") | q))",
            ($p | to_entries[] |
                "pane_cmds[\("\($i):\(.key + 1)" | q)]=\(.value.cmd // "" | q)",
                "pane_dirs[\("\($i):\(.key + 1)" | q)]=\(.value.dir // "" | q)")
        end)'

# usage: load_existing_launcher FILE
load_existing_launcher() {
    local code derived
    derived="${1##*/}"
    derived=$(_derived_session "${derived%.toml}")
    code=$(launcher_json "$1" | jq -r --arg derived "$derived" "$_LOAD_JQ") || return 1
    win_names=() win_cmds=() win_splits=() win_split_cmds=()
    win_panes=() win_layouts=() win_autonames=() win_dirs=()
    pane_cmds=() pane_dirs=()
    eval "$code"
}

# the session a launcher named NAME gets: dots are tmux target separators
_derived_session() {
    printf '%s' "$1" | tr '.' '-' | sed 's/-*$//'
}

# $HOME/... as ~/..., for paths the wizard and save hold in $HOME form
_tilde_path() {
    local path="$1" tilde='~'
    case "$path" in
        '$HOME' | "$HOME") path="$tilde" ;;
        '$HOME/'*) path="$tilde/${path#\$HOME/}" ;;
        "$HOME/"*) path="$tilde/${path#"$HOME"/}" ;;
    esac
    [[ "$path" == */ && "$path" != / ]] && path="${path%/}"
    printf '%s' "$path"
}

# the one focus = true: on the pane when it isn't the window's first, else on
# the window when it isn't the first window, else nowhere
_pane_focused() {
    [[ "${focus_window:-0}" == "$1" && "${focus_pane:-1}" == "$2" && "$2" != 1 ]]
}

_window_focused() {
    [[ "${focus_window:-0}" == "$1" && "${focus_pane:-1}" == 1 && "$1" != 0 ]]
}

# one pane's JSON: split/of/size from a layout step (empty for pane 1)
# usage: _pane_json WINDOW_INDEX PANE [HOLDER DIR PCT]
_pane_json() {
    local i="$1" k="$2" holder="${3:-}" dir="${4:-}" pct="${5:-}" pdir
    pdir=$(_tilde_path "${pane_dirs["$i:$k"]:-}")
    jq -nc --arg split "$dir" --arg of "$holder" --arg size "$pct" --argjson k "$k" \
        --arg dir "$pdir" --arg cmd "${pane_cmds["$i:$k"]:-}" \
        --argjson focus "$(_pane_focused "$i" "$k" && echo true || echo false)" '
        (if $split != "" then {split: $split} else {} end)
        + (if $of != "" and ($of | tonumber) != $k - 1 then {of: ($of | tonumber)} else {} end)
        + (if $size != "" and $size != "-" then {size: ($size | tonumber)} else {} end)
        + (if $dir != "" then {dir: $dir} else {} end)
        + (if $cmd != "" then {cmd: $cmd} else {} end)
        + (if $focus then {focus: true} else {} end)'
}

# one window's JSON
# usage: _window_json WINDOW_INDEX
_window_json() {
    local i="$1" panes holder dir pct new single
    if [[ -n "${win_panes[$i]:-}" ]]; then
        panes=$(
            _pane_json "$i" 1
            while read -r holder dir pct new; do
                [[ -n "$holder" ]] || continue
                _pane_json "$i" "$new" "$holder" "$dir" "$pct"
            done <<<"${win_layouts[$i]:-}"
        )
        panes=$(jq -sc . <<<"$panes")
    elif [[ "${win_splits[$i]}" == yes ]]; then
        panes=$(jq -nc --arg a "${win_cmds[$i]}" --arg b "${win_split_cmds[$i]}" \
            --argjson f "$(_pane_focused "$i" 2 && echo true || echo false)" '
            [if $a != "" then {cmd: $a} else {} end,
             {split: "h"} + (if $b != "" then {cmd: $b} else {} end) + (if $f then {focus: true} else {} end)]')
    else
        panes=$(jq -nc --arg a "${win_cmds[$i]}" '[if $a != "" then {cmd: $a} else {} end]')
    fi
    single=$(jq -c 'if length == 1 then .[0] else null end' <<<"$panes")
    jq -nc --arg name "${win_names[$i]}" --arg auto "${win_autonames[$i]:-}" \
        --arg dir "$(_tilde_path "${win_dirs[$i]:-}")" \
        --argjson focus "$(_window_focused "$i" && echo true || echo false)" \
        --argjson panes "$panes" --argjson single "$single" '
        (if $name != "" then {name: $name} else {} end)
        + (if $auto == "1" then {auto_rename: true} else {} end)
        + (if $focus then {focus: true} else {} end)
        + (if $dir != "" then {dir: $dir} else {} end)
        + (if $single != null then $single else {pane: $panes} end)'
}

instance_value() {
    if [[ "${instance_mode:-}" == y ]]; then
        printf 'prompt'
    elif [[ "${instance_auto:-}" == 1 ]]; then
        printf 'auto'
    fi
}

# shellcheck disable=SC2154 # reads the caller's state variables (see header)
prefix_value() {
    if [[ -n "${worktree_prefix:-}" ]]; then
        printf '%s' "$worktree_prefix"
    elif [[ "${prefix_absent:-}" != 1 ]]; then
        printf '%s' "$name" | tr '[:lower:]' '[:upper:]'
    fi
}

# the launcher JSON for the state variables
# shellcheck disable=SC2154 # reads the caller's state variables (see header)
launcher_state_json() {
    local windows i
    windows=$(for ((i = 0; i < ${#win_names[@]}; i++)); do _window_json "$i"; done | jq -sc .)
    if [[ "${session_mode:-fixed}" == directory ]]; then
        jq -nc --arg d "$description" --argjson w "$windows" '{description: $d, window: $w}'
        return
    fi
    jq -nc --arg d "$description" \
        --arg session "${session_kept:-$(_derived_session "$name")}" \
        --arg instance "$(instance_value)" \
        --arg root "$(_tilde_path "$project_dir")" \
        --arg wt "$([[ "$worktree_aware" == y ]] && echo y)" \
        --arg wt_dir "$(_tilde_path "${worktrees_dir:-}")" \
        --arg prefix "$(prefix_value)" \
        --argjson w "$windows" '
        {description: $d, session: $session}
        + (if $instance != "" then {instance: $instance} else {} end)
        + (if $root != "" and $root != "~" then {root: $root} else {} end)
        + (if $wt != "" then {worktrees: ({dir: $wt_dir}
            + (if $prefix != "" then {prefix: $prefix} else {} end))} else {} end)
        + {window: $w}'
}

# launcher_state_json for writing over FILE: when FILE opens on the same pane,
# its focus = true stays where it was written (a window and its first pane
# mean the same focus)
# usage: launcher_state_json_for FILE [SESSION]
#
# with SESSION, the session the state was captured from, a command written
# with {SESSION} stays written that way where it expands to the captured one
# shellcheck disable=SC2016 # jq source
launcher_state_json_for() {
    local new
    new=$(launcher_state_json)
    if [[ ! -f "$1" ]]; then
        printf '%s\n' "$new"
        return
    fi
    jq -c --argjson old "$(launcher_json "$1")" --arg session "${2:-}" "$LAUNCHER_EXPAND_JQ"'
        def focus_paths: [paths(scalars) | select(.[-1] == "focus")];
        def opens_on: [.window | to_entries[] | .key as $w | .value |
            (if .focus == true then [$w, 1] else empty end),
            ((.pane // []) | to_entries[] | select(.value.focus == true) | [$w, .key + 1])] | first // [0, 1];
        . as $new |
        if ($old | opens_on) == ($new | opens_on)
            and all($old | focus_paths[]; . as $p | ($new | getpath($p[:-1]) | type) == "object")
        then reduce ($old | focus_paths[]) as $p (delpaths($new | focus_paths); setpath($p; true))
        else . end |
        reduce ($old | paths(strings) | select(.[-1] == "cmd")) as $p (.;
            ($old | getpath($p)) as $c |
            if $session != "" and ($c | contains("{SESSION}")) and getpath($p) == ($c | expand_cmd($session))
            then setpath($p; $c) else . end)' <<<"$new"
}

# usage: write_launcher FILE [SESSION]   (SESSION as for launcher_state_json_for)
write_launcher() {
    launcher_write "$1" "$(launcher_state_json_for "$1" "${2:-}")"
}
