#!/usr/bin/env bash
# shared helpers for the fzf pickers that run in rex floating layers
# source this file: source "${BASH_SOURCE%/*}/_lib.sh"

# ~/.config/rex links to the repo's rex/, so -P resolves to the repo root
# shellcheck source=/dev/null
source "$(cd -P "${BASH_SOURCE%/*}/../.." && pwd)/tmux/scripts/_lib/common.sh"
# shellcheck source=/dev/null
source "$DOTFILES_ROOT/tmux/scripts/_lib/ui.sh"
load_fzf_theme

# scripts run by rex.exec get the server's environment, which may not have rex
# on PATH (terminals rex opens always do)
command -v rex >/dev/null ||
    PATH="$HOME/Library/Application Support/com.superlogical.rex/RexServer/Versions/Current/Rex Server.app/Contents/MacOS:$PATH"

# rows, previews and actions are in do/pick.lua
PICK_LUA="$HOME/.config/rex/do/pick.lua"
pick() {
    rex "do" "$PICK_LUA" "$@"
}

# fzf reads rows starting with a tab as the header
header_count() {
    grep -c $'^\t' <<<"$1" || true
}

# export the origin for child scripts and focus it again on exit: if the popup
# still has focus when its layer closes, rex moves focus to another pane.
# focusing the popup also undoes a zoom, so a zoomed origin is zoomed again
# (which focuses it too); PICK_ORIGIN_ZOOMED is 1 when it was zoomed
picker_start() {
    export PICK_CLIENT PICK_ORIGIN_SESSION="$2" PICK_ORIGIN_BLOCK="$3" PICK_ORIGIN_ZOOMED="${4:-}"
    PICK_CLIENT=$(local_client "$1" "$2")
    trap restore_focus EXIT
}

# the action that opens a popup runs on the home server and passes the app's
# client id there. a popup over another host's session calls that host's
# server, which knows the app by another id: the app labelled
# PICK_CLIENT_LABEL, else the app showing the origin session, else any app
local_client() {
    local clients
    if ! clients=$(rex client ls --json 2>/dev/null); then
        printf '%s\n' "$1"
        return 0
    fi
    jq -r --arg id "$1" --arg label "${PICK_CLIENT_LABEL:-}" --arg session "$2" '
        [.clients[] | select(.info.kind == "app")] as $apps
        | if any(.clients[]; .client_id == $id) then $id
          else first(
              ($apps[] | select($label != "" and .info.label == $label)),
              ($apps[] | select(any(.session_ids[]?; . == $session))),
              $apps[]
          ).client_id // $id
          end' <<<"$clients"
}

restore_focus() {
    [[ -n "$PICK_ORIGIN_BLOCK" ]] || return 0
    pick cmd=restore >/dev/null 2>&1 || true
}

# a popup starts from the rex server's environment, without what ~/.zshrc
# exports (PROJECT_DIRS, *_ROOT); tmux popups get those via update-environment.
# only variables the popup lacks are taken, so rex's own and readonly ones stay
import_shell_env() {
    local entry name line
    # written by dotfiles.zsh at each shell's first prompt; the zsh fallback
    # below covers a machine where no shell has reached a prompt yet
    local cached="${XDG_CACHE_HOME:-$HOME/.cache}/zsh/project-env.sh"
    if [[ -f "$cached" ]]; then
        while IFS= read -r line; do
            name="${line#export }"
            name="${name%%=*}"
            [[ -v "$name" ]] || eval "$line"
        done <"$cached"
        return 0
    fi
    while IFS= read -r -d '' entry; do
        name="${entry%%=*}"
        [[ "$name" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]] || continue
        [[ -v "$name" ]] && continue
        # shellcheck disable=SC2163 # entry is NAME=value
        export "$entry"
    # nomonitor: with job control on, the interactive zsh takes the terminal's
    # foreground and leaves this script in the background, where fzf can't read it
    done < <(zsh -o nomonitor -ic 'env -0 >&3' 3>&1 >/dev/null 2>&1 </dev/null)
}

# the popup's terminal starts at 80x24 and the app resizes it once the layer
# is drawn; starting fzf before that draws it small with a clipped preview
wait_for_resize() {
    local start size
    start=$(stty size </dev/tty)
    [[ "$start" == "24 80" ]] || return 0
    for _ in $(seq 25); do
        sleep 0.02
        size=$(stty size </dev/tty)
        if [[ "$size" != "$start" ]]; then
            save_popup_size "$size"
            break
        fi
    done
    return 0
}

# PICK_SIZE_KEY comes from M.open in lua/layers.lua, which resizes the next
# popup with the same key to this size up front. the size goes to the
# save_popup_size action on the home server, where M.open runs, in the
# background so the popup doesn't wait on it
save_popup_size() {
    local rows="${1% *}" columns="${1#* }"
    [[ -n "${PICK_SIZE_KEY:-}" ]] || return 0
    (
        server=()
        home=$(rex hosts --json 2>/dev/null | jq -r 'if .home.this_machine then "" else .home.endpoint end')
        [[ -n "$home" ]] && server=(-S "$home")
        rex "${server[@]}" "do" save_popup_size "key=$PICK_SIZE_KEY" "columns=$columns" "rows=$rows"
    ) >/dev/null 2>&1 &
}

prompt_name() {
    local prompt="$1" query="$2" label="$3"
    printf '' | fzf --print-query --query="$query" --prompt="$prompt" \
        --height=100% --layout=reverse --border=rounded --no-info --pointer=' ' \
        --border-label=" $label " --border-label-pos=bottom \
        --bind 'enter:print-query' --bind 'esc:abort' 2>/dev/null | head -1
}

# fzf options shared by the pickers: browse mode by default, / to search.
# keys lists every single-letter binding so search mode can unbind them
picker_fzf_opts() {
    local keys="$1" label="$2"
    PICKER_FZF_OPTS=(
        --ansi --reverse --exact --disabled --cycle
        --delimiter=$'\t' --prompt ': ' --border=rounded
        --border-label=" $label " --border-label-pos=bottom
        --preview-window='right,70%,<80(bottom,40%)'
        --bind 'every(0.5):refresh-preview'
        --bind 'j:down,k:up,g:first,G:last,q:abort,space:accept'
        --bind 'change:transform:[[ $FZF_PROMPT == ": " ]] && echo "clear-query"'
        --bind "/:enable-search+change-prompt(> )+unbind($keys)"
        --bind "esc:transform:[[ \$FZF_PROMPT == \"> \" ]] && echo \"disable-search+clear-query+change-prompt(: )+rebind($keys)\" || echo \"abort\""
        --bind 'ctrl-k:up,ctrl-l:clear-query'
    )
}
