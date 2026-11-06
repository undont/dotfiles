#!/usr/bin/env bash
# launcher files (<name>.toml) and the resolved session they describe, which
# the tmux and rex backends build. the schema is in launchers/launcher.toml.template
# source this file: source "${BASH_SOURCE%/*}/../_lib/launcher-data.sh"
#
# a resolved launcher is JSON:
#   {name, session, root, windows: [{name, auto_rename, focus, panes:
#     [{dir, cmd, split, of, size, focus}]}]}
# with absolute dirs, commands with {SESSION} filled in, one focused window,
# one focused pane per window (pane 1 outside the focused window), and split
# and of set on every pane after the first (size stays null for an even split)

[[ -n "${_TMUX_LAUNCHER_DATA_SH_LOADED:-}" ]] && return 0
_TMUX_LAUNCHER_DATA_SH_LOADED=1

# shellcheck source=tmux/scripts/_lib/common.sh
source "${BASH_SOURCE%/*}/common.sh"

# usage: launcher_file NAME
launcher_file() {
    local dir
    for dir in "$USER_LAUNCHERS" "$DOTFILES_LAUNCHERS"; do
        if [[ -f "$dir/$1.toml" ]]; then
            printf '%s\n' "$dir/$1.toml"
            return 0
        fi
    done
    return 1
}

# "<name>\t<value of KEY>" for each launcher file in DIR, in one yq run when
# every file parses; a file that isn't valid TOML is skipped
# usage: launcher_field DIR KEY
# shellcheck disable=SC2016 # yq source
launcher_field() {
    local files=() file
    for file in "$1"/*.toml; do
        [[ -f "$file" ]] && files+=("$file")
    done
    [[ ${#files[@]} -gt 0 ]] || return 0
    local query='(filename | sub(".*/"; "") | sub("\\.toml$"; "")) + "\t" + (.'"$2"' // "" | sub("\n"; " "))'
    local rows
    if rows=$(yq -p toml -o yaml "$query" "${files[@]}" 2>/dev/null); then
        printf '%s\n' "$rows"
        return
    fi
    for file in "${files[@]}"; do
        yq -p toml -o yaml "$query" "$file" 2>/dev/null || true
    done
}

# {SESSION} in a command is the session name in capitals (dana-1234 ->
# DANA-1234), for tools that take an instance's ticket key
# shellcheck disable=SC2016 # jq source
LAUNCHER_EXPAND_JQ='def expand_cmd($session): gsub("\\{SESSION\\}"; $session | ascii_upcase);'

# usage: launcher_json FILE
launcher_json() {
    yq -p toml -o json -I0 "$1"
}

# a blank line before each window and the comments above it
_launcher_spacing() {
    awk '
        /^\[\[window\]\]$/ && prev != "" && prev !~ /^[[:space:]]*#/ { print "" }
        { print; prev = $0 }'
}

# yq keeps a comment above a key inside a table, but drops one on its own
# line after a key or above a [[window]] header. this puts each comment block
# OLD_FILE had back above the same line in the new TOML on stdin, matching a
# key by name and a header by text, each by how many times it has appeared
# usage: _launcher_keep_comments OLD_FILE
_launcher_keep_comments() {
    awk '
        function trim(t) { sub(/^[[:space:]]+/, "", t); return t }
        function anchor(line,   k) {
            k = line
            if (k ~ /^[A-Za-z0-9_"-]+[[:space:]]*=/) sub(/[[:space:]]*=.*/, "", k)
            return k SUBSEP (++seen[FILENAME, k])
        }
        FNR == NR {
            if ($0 ~ /^[[:space:]]*#/) { block = block $0 "\n"; next }
            if ($0 ~ /^[[:space:]]*$/) { if (block != "") block = block "\n"; next }
            if (block != "") { kept[anchor($0)] = block; block = "" } else anchor($0)
            next
        }
        { lines[++n] = $0; if ($0 ~ /^[[:space:]]*#/) present[trim($0)] = 1 }
        END {
            for (i = 1; i <= n; i++) {
                line = lines[i]
                if (line !~ /^[[:space:]]*(#|$)/) {
                    key = anchor(line)
                    if (key in kept) {
                        split(kept[key], c, "\n")
                        if (!(trim(c[1]) in present)) {
                            if (line ~ /^\[/ && out != "" && last != "") print ""
                            sub(/\n+$/, "", kept[key])
                            print kept[key]
                        }
                    }
                }
                print line
                out = out "x"; last = line
            }
            if (block != "") { split(block, c, "\n"); if (!(trim(c[1]) in present)) { sub(/\n+$/, "", block); print ""; print block } }
        }' "$1" -
}

# usage: launcher_toml JSON
launcher_toml() {
    yq -p json -o toml <<<"$1" | _launcher_spacing
}

# write a launcher's JSON to FILE. an existing file is updated value by value,
# so a comment stays with its key unless that key goes
# usage: launcher_write FILE JSON
# shellcheck disable=SC2016 # jq and yq source
launcher_write() {
    local file="$1" json="$2" old sets dels tmp
    if [[ ! -f "$file" ]]; then
        launcher_toml "$json" >"$file"
        return
    fi
    old=$(launcher_json "$file")
    # empty tables count as values, so an empty pane or window is written too
    sets=$(jq -c '[paths((type | IN("object", "array") | not) or length == 0) as $p | {p: $p, v: getpath($p)}]' <<<"$json")
    # the outermost paths the new JSON drops, array indexes high to low
    dels=$(jq -nc --argjson o "$old" --argjson n "$json" '
        [$o | paths | select(. as $p | ($n | try getpath($p) catch null) == null)] |
        . as $all | map(select(. as $p | any($all[]; . != $p and . == $p[:length]) | not)) |
        sort | reverse')
    tmp=$(mktemp)
    SETS="$sets" DELS="$dels" yq -p toml -o toml \
        '. as $doc | env(SETS)[] as $s ireduce ($doc; setpath($s.p; $s.v)) | delpaths(env(DELS))' \
        "$file" | _launcher_keep_comments "$file" | _launcher_spacing >"$tmp"
    cat "$tmp" >"$file"
    rm -f "$tmp"
}

# one "<key>: <problem>" line per schema error, nothing when the file is valid
# usage: launcher_problems JSON
# shellcheck disable=SC2016 # jq source
launcher_problems() {
    jq -r '
        def is($k; $t): if has($k) and (.[$k] | type) != $t then "\($k): not a \($t)" else empty end;
        def gone($k): if has($k) then "\($k): no longer supported, set the path directly" else empty end;
        def at($p): sub("^"; $p + ".");
        def pct: type == "number" and . >= 1 and . <= 99;
        def pane_keys: is("dir"; "string"), is("cmd"; "string"), is("focus"; "boolean");
        if type != "object" then "not a table" else
        (if (.description | type) != "string" or .description == "" then "description: missing" else empty end),
        is("session"; "string"), is("root"; "string"), gone("root_env"),
        (if has("instance") and (.instance | IN("prompt", "auto") | not) then "instance: not prompt or auto" else empty end),
        (if has("worktrees") then
            if (.worktrees | type) != "object" then "worktrees: not a table" else
                (if (.worktrees.dir | type) != "string" then "worktrees.dir: missing" else empty end),
                (.worktrees | gone("env"), is("prefix"; "string") | at("worktrees")),
                (if has("session") | not then "worktrees: needs session" else empty end)
            end
         else empty end),
        (if (.window | type) != "array" or (.window | length) == 0 then "window: missing" else
            .window | to_entries[] | .key as $w | .value |
            "window[\($w + 1)]" as $at |
            if type != "object" then "\($at): not a table" else
                (is("name"; "string"), is("auto_rename"; "boolean"), pane_keys | at($at)),
                (if has("pane") and has("cmd") then "\($at): cmd and pane" else empty end),
                (if has("pane") then
                    if (.pane | type) != "array" or (.pane | length) == 0 then "\($at).pane: empty" else
                        .pane | to_entries[] | .key as $k | .value |
                        "\($at).pane[\($k + 1)]" as $p |
                        if type != "object" then "\($p): not a table"
                        elif $k == 0 then
                            (pane_keys | at($p)),
                            (if has("split") or has("of") or has("size") then "\($p): the first pane has no split" else empty end)
                        else
                            (pane_keys | at($p)),
                            (if (.split // "") | IN("h", "v") | not then "\($p).split: not h or v" else empty end),
                            (if has("of") and ((.of | type) != "number" or .of < 1 or .of > $k) then "\($p).of: not an earlier pane" else empty end),
                            (if has("size") and (.size | pct | not) then "\($p).size: not 1-99" else empty end)
                        end
                    end
                 else empty end)
            end
        end),
        # one focus in the whole file, on a window or on a pane
        (if (.window | type) == "array" then
            [.window | to_entries[] | .key as $w | .value | select(type == "object") |
                (if .focus == true then "window[\($w + 1)]" else empty end),
                (if (.pane | type) == "array" then
                    .pane | to_entries[] | select((.value | type) == "object" and .value.focus == true) |
                    "window[\($w + 1)].pane[\(.key + 1)]"
                 else empty end)] |
            .[0] as $first | .[1:][] | "\(.).focus: \($first) already has focus"
         else empty end)
        end
    ' <<<"$1"
}

# usage: expand_home PATH
expand_home() {
    printf '%s' "${1/#\~/$HOME}"
}

# first directory a worktree instance suffix names: <n> opens <prefix>-<n>-*,
# anything else the directory named <suffix>. empty when nothing matches
# usage: worktree_dir WORKTREES_DIR PREFIX SUFFIX
worktree_dir() {
    local dir="$1" prefix="$2" suffix="$3" wt
    if [[ "$suffix" =~ ^[0-9]+$ ]]; then
        for wt in "$dir/$prefix-$suffix-"*; do
            if [[ -d "$wt" ]]; then
                printf '%s' "$wt"
                return
            fi
        done
    elif [[ -d "$dir/$suffix" ]]; then
        printf '%s' "$dir/$suffix"
    fi
}

# resolve a launcher file for a run: SESSION_NAME picks an instance, and a
# launcher without a session key needs the directory argument
# usage: launcher_resolve FILE [DIR]
launcher_resolve() {
    local file="$1" dir_arg="${2:-}" json problems name session base root
    name="${file##*/}"
    name="${name%.toml}"
    json=$(launcher_json "$file") || {
        error "$file: not valid TOML"
        return 1
    }
    problems=$(launcher_problems "$json")
    if [[ -n "$problems" ]]; then
        error "$file: $(printf '%s' "$problems" | paste -sd ';' - | sed 's/;/; /g')"
        return 1
    fi

    base=$(jq -r '.session // empty' <<<"$json")
    if [[ -n "$base" ]]; then
        session="${SESSION_NAME:-$base}"
        root=$(expand_home "$(jq -r '.root // "~"' <<<"$json")")
        if [[ "$session" == "$base-"?* ]] && jq -e 'has("worktrees")' <<<"$json" >/dev/null; then
            local wt_dir prefix wt
            wt_dir=$(jq -r '.worktrees.dir' <<<"$json")
            prefix=$(jq -r --arg n "$name" '.worktrees.prefix // ($n | ascii_upcase)' <<<"$json")
            wt=$(worktree_dir "$(expand_home "$wt_dir")" "$prefix" "${session#"$base"-}")
            [[ -n "$wt" ]] && root="$wt"
        fi
    else
        if [[ -z "$dir_arg" ]]; then
            error "$name needs a directory"
            return 1
        fi
        root=$(expand_home "$dir_arg")
        if [[ -d "$root" ]]; then
            root=$(cd "$root" && pwd)
        fi
        session="${SESSION_NAME:-$(sanitise_session_name "${root##*/}")}"
    fi
    if [[ ! -d "$root" ]]; then
        error "Project directory not found: $root"
        return 1
    fi

    # shellcheck disable=SC2016 # jq source
    jq -c --arg name "$name" --arg session "$session" --arg root "$root" --arg home "$HOME" "$LAUNCHER_EXPAND_JQ"'
        def path:
            if . == null or . == "" then $root
            elif startswith("/") then .
            elif . == "~" then $home
            elif startswith("~/") then $home + .[1:]
            else $root + "/" + . end;
        # [window, pane] of the one focus: a focused window opens on its first pane
        ([.window | to_entries[] | .key as $w | .value |
            (if .focus == true then [$w, 0] else empty end),
            ((.pane // []) | to_entries[] | select(.value.focus == true) | [$w, .key])] | first // [0, 0]) as [$fw, $fp] |
        {name: $name, session: $session, root: $root,
         windows: (.window | to_entries | map(.key as $w | .value |
            (.dir) as $wdir |
            (.pane // [{cmd}]) as $panes |
            {name: (.name // null), auto_rename: (.auto_rename // false), focus: ($w == $fw),
             panes: ($panes | to_entries | map(.key as $k | .value |
                {dir: ((.dir // $wdir) | path), cmd: (.cmd // "" | expand_cmd($session)), focus: ($k == (if $w == $fw then $fp else 0 end))} +
                (if $k == 0 then {split: null, of: null, size: null}
                 else {split, of: (.of // $k), size} end)))}))}' <<<"$json"
}
