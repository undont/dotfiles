#!/usr/bin/env bash
set -euo pipefail

# convert bash user launchers to <name>.toml. each launcher runs against a
# recording tmux stand-in (no session is built), so hand-written ones convert
# as well as wizard output. the root and worktree env vars point at scratch
# dirs during the run, so a project missing on this machine still converts.
# the run's PATH holds only that tmux and a few read-only tools, so a launcher
# that runs anything else (git, mkdir, docker) stops there and is left alone.
# a converted launcher's bash moves to the launcher-backups dir; one that
# can't be recorded stays where it is and is listed

DOTFILES_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
USER_LAUNCHERS="${XDG_CONFIG_HOME:-$HOME/.config}/dotfiles/launchers"
BACKUPS="${XDG_DATA_HOME:-$HOME/.local/share}/dotfiles/launcher-backups/bash"

if [[ ! -d "$USER_LAUNCHERS" ]]; then
    echo "    No user launchers directory, nothing to convert"
    exit 0
fi

# shellcheck source=tmux/scripts/_lib/launcher-data.sh
source "$DOTFILES_ROOT/tmux/scripts/_lib/launcher-data.sh"

WORK=$(mktemp -d)
# the instance suffix the second recording runs as; numeric, so a worktree
# launcher looks for a worktree and finds none
INSTANCE=99999
trap 'rm -rf "$WORK"' EXIT

# the recording tmux: one plan file per run, edited with jq. pane targets
# like win.2 count panes in creation order
mkdir -p "$WORK/bin"
# an absolute interpreter: the launcher's PATH has no env or bash on it
printf '#!%s\n' "$BASH" >"$WORK/bin/tmux"
cat >>"$WORK/bin/tmux" <<'RECORDER'
set -euo pipefail
PATH="$TMUX_RECORD_PATH"
PLAN="$TMUX_RECORD_PLAN"
die() {
    printf '%s\n' "$*" >"$PLAN.error"
    exit 1
}
edit() {
    jq "$@" "$PLAN" >"$PLAN.tmp"
    /bin/mv -f "$PLAN.tmp" "$PLAN"
}

cmd="$1"
shift
declare -A opt=()
flags=""
args=()
while [[ $# -gt 0 ]]; do
    case "$1" in
        # display-message -p prints; split-window -p is a percentage
        -p) if [[ "$cmd" == display* ]]; then flags+=p; shift; else opt[p]="$2"; shift 2; fi ;;
        -l) if [[ "$cmd" == send* ]]; then flags+=l; shift; else opt[l]="$2"; shift 2; fi ;;
        -[tsncFxy]) opt[${1#-}]="$2"; shift 2 ;;
        -[dPhvbaAwgquEZ]*) flags+="${1#-}"; shift ;;
        *) args+=("$1"); shift ;;
    esac
done
has() { [[ "$flags" == *"$1"* ]]; }

# a target as "<window> <pane>" (0-based window, 1-based pane), from @wN,
# %wN.K, S, S:, S:N, S:name, S:name.K
target() {
    local t="${1#=}" win pane=""
    case "$t" in
        @w*) printf '%s 0\n' "${t#@w}"; return ;;
        %w*) t="${t#%w}"; printf '%s %s\n' "${t%.*}" "${t#*.}"; return ;;
    esac
    [[ "$t" == *:* ]] && win="${t#*:}" || win=""
    if [[ "$win" =~ ^(.*)\.([0-9]+)$ ]]; then
        win="${BASH_REMATCH[1]}"
        pane="${BASH_REMATCH[2]}"
    fi
    jq -r --arg w "$win" --arg p "$pane" '
        (if $w == "" then .active
         elif ($w | test("^[0-9]+$")) then ($w | tonumber) - 1
         else [.windows[].name] | index($w) end) as $i |
        if $i == null or $i >= (.windows | length) then "none" else
            "\($i) \(if $p == "" then .windows[$i].active else $p end)" end' "$PLAN"
}
resolve() {
    read -r T_WIN T_PANE < <(target "$1")
    [[ "$T_WIN" != none ]] || die "no window for target $1"
}

case "$cmd" in
    has-session | has) exit 1 ;;
    list-sessions | ls) exit 0 ;;
    new-session | new)
        printf '{"session":%s,"active":0,"windows":[{"name":%s,"auto":false,"active":1,"panes":[{"dir":%s,"cmd":""}]}]}\n' \
            "$(jq -n --arg s "${opt[s]:-}" '$s')" "$(jq -n --arg n "${opt[n]:-}" 'if $n == "" then null else $n end')" \
            "$(jq -n --arg c "${opt[c]:-}" '$c')" >"$PLAN"
        win=0
        ;;
    new-window | neww)
        edit --arg n "${opt[n]:-}" --arg c "${opt[c]:-}" --arg d "$(has d && echo 1)" '
            .windows += [{name: (if $n == "" then null else $n end), auto: false, active: 1, panes: [{dir: $c, cmd: ""}]}] |
            if $d == "" then .active = (.windows | length) - 1 else . end'
        win=$(jq '.windows | length - 1' "$PLAN")
        ;;
    split-window | splitw)
        resolve "${opt[t]:-}"
        size=null
        if [[ "${opt[l]:-}" =~ ^([0-9]+)%$ ]]; then
            size="${BASH_REMATCH[1]}"
        elif [[ -n "${opt[p]:-}" ]]; then
            size="${opt[p]}"
        elif [[ -n "${opt[l]:-}" ]]; then
            die "split size ${opt[l]} is not a percentage"
        fi
        has b && die "split-window -b"
        split=v
        has h && split=h
        edit --argjson w "$T_WIN" --argjson of "$T_PANE" --arg s "$split" --argjson size "$size" \
            --arg c "${opt[c]:-}" --arg d "$(has d && echo 1)" '
            .windows[$w].panes += [{dir: $c, cmd: "", split: $s, of: $of, size: $size}] |
            if $d == "" then .windows[$w].active = (.windows[$w].panes | length) else . end'
        win="$T_WIN"
        pane=$(jq --argjson w "$T_WIN" '.windows[$w].panes | length' "$PLAN")
        ;;
    send-keys | send)
        resolve "${opt[t]:-}"
        [[ "${args[-1]:-}" == Enter || "${args[-1]:-}" == C-m ]] || die "send-keys without Enter"
        unset 'args[-1]'
        [[ ${#args[@]} -eq 1 ]] || die "send-keys with ${#args[@]} key arguments"
        edit --argjson w "$T_WIN" --argjson p "$T_PANE" --arg k "${args[*]}" \
            '.windows[$w].panes[$p - 1].cmd = $k'
        ;;
    select-window | selectw)
        resolve "${opt[t]:-}"
        edit --argjson w "$T_WIN" '.active = $w'
        ;;
    select-pane | selectp)
        resolve "${opt[t]:-}"
        edit --argjson w "$T_WIN" --argjson p "$T_PANE" '.active = $w | .windows[$w].active = $p'
        ;;
    set-option | set | setw | set-window-option)
        if [[ "${args[0]:-}" == automatic-rename && "${args[1]:-}" == on ]]; then
            resolve "${opt[t]:-}"
            edit --argjson w "$T_WIN" '.windows[$w].auto = true'
        fi
        ;;
    display-message | display)
        has p || exit 0
        fmt="${args[0]:-}"
        if [[ "$fmt" == *pane_id* || "$fmt" == *window_id* ]]; then
            resolve "${opt[t]:-}"
            fmt="${fmt//'#{pane_id}'/%w$T_WIN.$T_PANE}"
            fmt="${fmt//'#{window_id}'/@w$T_WIN}"
        fi
        fmt="${fmt//'#{client_width}'/200}"
        fmt="${fmt//'#{client_height}'/50}"
        [[ "$fmt" != *'#{'* ]] || die "display-message format $fmt"
        printf '%s\n' "$fmt"
        ;;
    switch-client | switchc | attach-session | attach | a) exit 0 ;;
    *) die "tmux $cmd" ;;
esac

if has P; then
    fmt="${opt[F]:-}"
    if [[ -z "$fmt" ]]; then
        [[ -n "${pane:-}" ]] && fmt='#{pane_id}' || fmt='#{window_id}'
    fi
    fmt="${fmt//'#{pane_id}'/%w$win.${pane:-1}}"
    fmt="${fmt//'#{window_id}'/@w$win}"
    printf '%s\n' "$fmt"
fi
RECORDER
chmod +x "$WORK/bin/tmux"

# the only other programs a launcher may run while it's recorded
for tool in cat tput tr sed grep awk basename dirname head tail cut wc sort uniq date uname id whoami; do
    if path=$(command -v "$tool"); then
        ln -s "$path" "$WORK/bin/$tool"
    fi
done

# the default a launcher assigns to VAR through nested fallbacks, and the env
# var of the outermost one: VAR="${A:-${B:-$HOME/x}}" -> "A $HOME/x"
assignment() {
    local file="$1" var="$2" value env=""
    value=$(grep -m1 "^$var=" "$file" | sed "s/^$var=//" | tr -d '"' || true)
    [[ "$value" =~ ^\$\{([A-Za-z0-9_]+):- ]] && env="${BASH_REMATCH[1]}"
    while [[ "$value" =~ ^\$\{[A-Za-z0-9_]+:-(.*)\}$ ]]; do
        value="${BASH_REMATCH[1]}"
    done
    printf '%s\t%s\n' "$env" "$value"
}

# a staged `_X_DEFAULT="..."` value when the default names one
staged() {
    local file="$1" value="$2" var
    if [[ "$value" =~ ^\$(_[A-Z0-9_]+_DEFAULT)$ ]]; then
        var="${BASH_REMATCH[1]}"
        value=$(grep -m1 "^$var=" "$file" | sed 's/^[^=]*=//; s/^"//; s/"$//')
    fi
    value="${value/#\$HOME/\~}"
    # shellcheck disable=SC2088 # a literal ~ for the TOML
    [[ "$value" == "~/" ]] && value="~"
    [[ "$value" == */ && "$value" != / ]] && value="${value%/}"
    printf '%s' "$value"
}

# record one launcher and print its TOML-shaped JSON, or fail
convert() {
    local file="$1" name="${1##*/}"
    local plan="$WORK/$name.plan" json root_line root_env root wt_line wt_env wt_dir prefix=""
    json=$(jq -n --arg d "$(grep -m1 '# @description:' "$file" | sed 's/.*# @description: *//')" '{description: $d}')

    root_line=$(assignment "$file" PROJECT_DIR)
    if [[ "${root_line#*$'\t'}" == '$BASE_DIR' ]]; then
        root_line=$(assignment "$file" BASE_DIR)
    fi
    root_env="${root_line%%$'\t'*}"
    root=$(staged "$file" "${root_line#*$'\t'}")

    wt_line=""
    if grep -q '^WORKTREES_DIR=' "$file"; then
        wt_line=$(assignment "$file" WORKTREES_DIR)
        local glob
        glob=$(grep -m1 'ticket_num}"-' "$file" || true)
        [[ "$glob" =~ \"\$WORKTREES_DIR\"/(.+)-\"\$\{ticket_num\}\" ]] && prefix="${BASH_REMATCH[1]}"
    fi
    wt_env="${wt_line%%$'\t'*}"
    wt_dir=$(staged "$file" "${wt_line#*$'\t'}")

    mkdir -p "$WORK/root" "$WORK/worktrees"
    record "$file" "$plan" "" "$root_env" "$wt_env" || return 1
    # an instance, to see what depends on the session name
    record "$file" "$plan.instance" "$(jq -r .session "$plan")-$INSTANCE" "$root_env" "$wt_env" || return 1
    with_session_placeholder "$plan" "$plan.instance" >"$plan.templated" || return 1

    # no PROJECT_DIR is the TOML default root, ~
    local recorded_root="${root:-\~}"
    [[ -n "$root_env" ]] && recorded_root="$WORK/root"
    recorded_root="${recorded_root/#\~/$HOME}"

    # shellcheck disable=SC2016 # jq source
    jq --argjson base "$json" --arg root "$root" --arg root_env "$root_env" --arg rec "$recorded_root" \
        --arg home "$HOME" --arg instance "$(grep -q '# @instance: *prompt' "$file" && echo prompt)" \
        --arg wt_dir "$wt_dir" --arg wt_env "$wt_env" --arg prefix "$prefix" '
        def rel: if . == $rec or . == "" then null
            elif startswith($rec + "/") then .[($rec | length) + 1:]
            elif . == $home then "~"
            elif startswith($home + "/") then "~" + .[($home | length):]
            else . end;
        def pane: {split, of, size, dir: (.dir | rel), cmd: (if .cmd == "" then null else .cmd end)}
            | with_entries(select(.value != null));
        $base + {session: .session}
        + (if $instance != "" then {instance: $instance} else {} end)
        + (if $root != "" and $root != "~" then {root: $root} else {} end)
        + (if $root_env != "" then {root_env: $root_env} else {} end)
        + (if $wt_dir != "" then {worktrees: ({dir: $wt_dir}
            + (if $wt_env != "" then {env: $wt_env} else {} end)
            + (if $prefix != "" then {prefix: $prefix} else {} end))} else {} end)
        # one focus: the active pane when it is not the first in its window, else
        # the active window when it is not the first
        + {window: (.active as $aw | .windows[$aw].active as $ap | .windows | to_entries | map(.key as $w | .value |
            (.panes | to_entries | map(.key as $k | .value | pane
                | if (.of // 0) == $k then del(.of) else . end)) as $panes |
            (if .name != null then {name} else {} end)
            + (if .auto and .name != null then {auto_rename: true} else {} end)
            + (if $w == $aw and $ap == 1 and $w != 0 then {focus: true} else {} end)
            + (if ($panes | length) == 1 then $panes[0]
               else {pane: ($panes | to_entries | map(.value
                    + (if $w == $aw and .key + 1 == $ap and .key != 0 then {focus: true} else {} end)))} end)))}
        ' "$plan.templated"
}

# run a launcher against the recording tmux into PLAN, as session SESSION_NAME
# (empty: the launcher's own default), with its root and worktree env vars on
# the scratch dirs
# usage: record FILE PLAN SESSION_NAME ROOT_ENV WORKTREES_ENV
record() {
    local file="$1" plan="$2"
    rm -f "$plan" "$plan.error"
    (
        export TMUX_RECORD_PLAN="$plan" TMUX_RECORD_PATH="$PATH" TMUX=recording
        unset SESSION_NAME
        [[ -n "$3" ]] && export SESSION_NAME="$3"
        [[ -n "$4" ]] && export "$4=$WORK/root"
        [[ -n "$5" ]] && export "$5=$WORK/worktrees"
        # shellcheck disable=SC2329 # bash calls it for a program not on PATH
        command_not_found_handle() {
            printf "runs %s, which the migration won't run\n" "$1" >"$TMUX_RECORD_PLAN.error"
            return 127
        }
        export -f command_not_found_handle
        PATH="$WORK/bin" "$BASH" "$file" </dev/null >/dev/null 2>&1
    ) || true
    if [[ -f "$plan.error" ]]; then
        cat "$plan.error" >&2
        return 1
    fi
    if [[ ! -f "$plan" ]]; then
        echo "built no session" >&2
        return 1
    fi
}

# the base recording with {SESSION} in each command that names the session in
# capitals, checked against the instance recording; fails when anything else
# differs between them
# usage: with_session_placeholder BASE_PLAN INSTANCE_PLAN
# shellcheck disable=SC2016 # jq source
with_session_placeholder() {
    local out
    if out=$(jq --slurpfile inst "$2" '
        def strip: .windows | map({name, auto, panes: [.panes[] | {dir, split, of, size}]});
        def template($s): split($s | ascii_upcase) | join("{SESSION}");
        $inst[0] as $i | . as $b |
        if (strip) != ($i | strip) then error("the windows depend on the session name") else . end |
        .windows |= (to_entries | map(.key as $w | .value |
            .panes |= (to_entries | map(.key as $k | .value |
                $i.windows[$w].panes[$k].cmd as $ic |
                if .cmd == $ic then .
                elif (.cmd | template($b.session)) == ($ic | template($i.session)) then .cmd |= template($b.session)
                else error("a command depends on the session name") end))))' "$1" 2>&1); then
        printf '%s\n' "$out"
        return
    fi
    printf '%s\n' "$out" | sed 's/^jq: error (at [^)]*): //' >&2
    return 1
}

# the session a resolved launcher describes, in the form compare_plan gives
# a recording: dirs without a trailing slash, auto-rename only on named windows
# shellcheck disable=SC2016 # jq source
resolved_shape() {
    jq -cS 'def d: sub("/+$"; "");
        [.windows[] | {name, auto: (.name != null and .auto_rename), focus,
            panes: [.panes[] | {dir: (.dir | d), cmd, split, of, size, focus}]}]'
}

# a recording in resolved_shape form: a pane without -c starts in ROOT, and
# only the active window keeps its active pane
# usage: plan_shape PLAN ROOT
# shellcheck disable=SC2016 # jq source
plan_shape() {
    jq -cS --arg root "$2" 'def d: if . == "" then $root else . end | sub("/+$"; "");
        .active as $aw | [.windows | to_entries[] | .key as $w | .value |
            (if $w == $aw then .active else 1 end) as $ap |
            {name, auto: (.name != null and .auto), focus: ($w == $aw),
             panes: [.panes | to_entries[] | .key as $k | .value |
                {dir: (.dir | d), cmd, split: (.split // null), of: (.of // null),
                 size: (.size // null), focus: ($k + 1 == $ap)}]}]' "$1"
}

# whether a launcher, run as SESSION_NAME (empty: its default), resolves to
# the session PLAN recorded
# usage: loads_back TOML PLAN SESSION_NAME
loads_back() {
    local resolved
    resolved=$(
        unset SESSION_NAME
        [[ -n "$3" ]] && export SESSION_NAME="$3"
        launcher_resolve "$1" 2>&1
    ) || return 1
    [[ "$(resolved_shape <<<"$resolved")" == "$(plan_shape "$2" "$(jq -r .root <<<"$resolved")")" ]]
}

# the converted launcher: TOML has no env overrides, so a root or worktrees
# env var this machine sets becomes the path, else the script's default does
# usage: with_env_paths DATA
# shellcheck disable=SC2016 # jq source
with_env_paths() {
    local root_env wt_env root="" wt_dir=""
    root_env=$(jq -r '.root_env // empty' <<<"$1")
    wt_env=$(jq -r '.worktrees.env // empty' <<<"$1")
    [[ -n "$root_env" && -n "${!root_env:-}" ]] && root="${!root_env/#$HOME/\~}"
    [[ -n "$wt_env" && -n "${!wt_env:-}" ]] && wt_dir="${!wt_env/#$HOME/\~}"
    jq -c --arg root "$root" --arg wt_dir "$wt_dir" '
        (if $root != "" then .root = $root else . end)
        | (if $wt_dir != "" then .worktrees.dir = $wt_dir else . end)
        | (if .root == "~" then del(.root) else . end)
        | del(.root_env, .worktrees.env)' <<<"$1"
}

# the launcher as recorded: its env-overridden paths on the scratch dirs
# usage: as_recorded DATA
# shellcheck disable=SC2016 # jq source
as_recorded() {
    jq -c --arg w "$WORK" '
        (if .root_env then .root = $w + "/root" else . end)
        | (if .worktrees.env then .worktrees.dir = $w + "/worktrees" else . end)
        | del(.root_env, .worktrees.env)' <<<"$1"
}

shopt -s nullglob
files=("$USER_LAUNCHERS"/*)
shopt -u nullglob

converted=()
kept=()
for f in "${files[@]}"; do
    name="${f##*/}"
    [[ -f "$f" && "$name" != *.toml && "$name" != *.template && "$name" != .* ]] || continue
    grep -q '^# @description:' "$f" || continue
    [[ -e "$f.toml" ]] && continue

    if ! data=$(convert "$f" 2>"$WORK/$name.why"); then
        kept+=("$name ($(head -1 "$WORK/$name.why" 2>/dev/null || true))")
        continue
    fi

    # the TOML has to resolve to the session the recording saw, with the same
    # scratch roots, and must not name a scratch dir
    if [[ "$data" == *"$WORK"* ]]; then
        kept+=("$name (a pane starts outside the project root)")
        continue
    fi
    launcher_toml "$(as_recorded "$data")" >"$WORK/$name.toml"
    if ! loads_back "$WORK/$name.toml" "$WORK/$name.plan" "" ||
        ! loads_back "$WORK/$name.toml" "$WORK/$name.plan.instance" "$(jq -r .session <<<"$data")-$INSTANCE"; then
        kept+=("$name (converted file did not load back the same)")
        continue
    fi

    launcher_toml "$(with_env_paths "$data")" >"$f.toml.tmp"
    /bin/mv -f "$f.toml.tmp" "$f.toml"
    mkdir -p "$BACKUPS"
    /bin/mv -f "$f" "$BACKUPS/$name"
    converted+=("$name")
done

if [[ ${#converted[@]} -eq 0 && ${#kept[@]} -eq 0 ]]; then
    echo "    No bash launchers left to convert"
fi
if [[ ${#converted[@]} -gt 0 ]]; then
    echo "    Converted ${#converted[@]} launcher(s) to TOML: ${converted[*]}"
    echo "    The bash originals are in $BACKUPS"
fi
for k in "${kept[@]}"; do
    echo "    Left as bash, the picker no longer lists it: $k"
done
exit 0
