#!/usr/bin/env bash
set -euo pipefail

# imports a .theme file into the rex app as a ghostty theme and selects it
# usage: reload-rex.sh <theme-name> <theme-file>

command -v rex >/dev/null 2>&1 || exit 0

theme_name="${1:?theme name required}"
theme_file="${2:?theme file required}"
# shellcheck disable=SC1090
source "$theme_file"

# rex names the imported theme after the file
out_dir=$(mktemp -d)
trap 'rm -f "$out_dir/$theme_name"; rmdir "$out_dir"' EXIT
out="$out_dir/$theme_name"

{
    printf 'background = %s\n' "$GHOSTTY_BACKGROUND"
    printf 'foreground = %s\n' "$GHOSTTY_FOREGROUND"
    printf 'cursor-color = %s\n' "${GHOSTTY_CURSOR_COLOR:-$GHOSTTY_FOREGROUND}"
    printf 'cursor-text = %s\n' "${GHOSTTY_CURSOR_TEXT:-$GHOSTTY_BACKGROUND}"
    printf 'selection-background = %s\n' "${GHOSTTY_SELECTION_BG:-$GHOSTTY_FOREGROUND}"
    printf 'selection-foreground = %s\n' "${GHOSTTY_SELECTION_FG:-$GHOSTTY_BACKGROUND}"
    for i in {0..15}; do
        var="GHOSTTY_PALETTE_$i"
        [[ -n "${!var:-}" ]] && printf 'palette = %s=%s\n' "$i" "${!var}"
    done
} >"$out"

command -v jq >/dev/null 2>&1 || exit 0

# the app opens the import path on its own machine, so only an app connected
# over this machine's socket (principal peer, not tailscale) can read the file
while IFS= read -r client; do
    rex -C "$client" "do" client.theme.import "path=$out" >/dev/null 2>&1 || true
done < <(rex client ls --json 2>/dev/null | jq -r '
    .clients[] | select(.info.kind == "app" and .principal.kind == "peer") | .client_id')

# a switch sent by another host has already reached the rest
[[ -z "${DOTFILES_THEME_FROM_HOST:-}" ]] || exit 0

# the other rex hosts switch their dotfiles theme through the dotfiles_theme
# action (rex/lua/dotfiles-theme.lua). a host that is down or lacks it is skipped.
# the home server isn't in its own host list, and a host following it sees
# itself there, so the targets are the home plus the hosts, minus this machine
self=$(rex whoami --json 2>/dev/null | jq -r '.host_id // empty')
args=("name=$theme_name" "theme=$(<"$theme_file")")
nvim_scheme="${BASH_SOURCE%/*}/../../../nvim/colors/generated/$theme_name.lua"
[[ -f "$nvim_scheme" ]] && args+=("nvim=$(<"$nvim_scheme")")
while IFS= read -r host; do
    rex -S "$host" --timeout 5s "do" dotfiles_theme "${args[@]}" >/dev/null 2>&1 &
done < <(rex hosts --json 2>/dev/null | jq -r --arg self "$self" '
    (if .home.this_machine then empty else .home.endpoint end),
    (.hosts[].host | select(.host_id != $self) | .label)')
