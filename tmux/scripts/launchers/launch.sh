#!/usr/bin/env bash
# build or focus the session a launcher describes
# usage: launch.sh NAME [DIR]   (SESSION_NAME picks an instance name)
set -euo pipefail

SCRIPT_DIR="${BASH_SOURCE%/*}"

# shellcheck source=tmux/scripts/_lib/launcher-data.sh
source "$SCRIPT_DIR/../_lib/launcher-data.sh"
# shellcheck source=tmux/scripts/_lib/launcher-backend.sh
source "$SCRIPT_DIR/../_lib/launcher-backend.sh"
# shellcheck source=tmux/scripts/_lib/ui.sh
source "$SCRIPT_DIR/../_lib/ui.sh"

name="${1:-}"
dir="${2:-}"
if [[ -z "$name" ]]; then
    error "usage: launch.sh NAME [DIR]"
    exit 1
fi
if ! file=$(launcher_file "$name"); then
    error "No launcher named $name"
    exit 1
fi

if [[ -n "$dir" ]]; then
    dir=$(expand_home "$dir")
    if [[ ! -d "$dir" ]]; then
        show_visual_confirm "Create directory?" "$dir" || exit 1
        mkdir -p "$dir"
    fi
fi

resolved=$(launcher_resolve "$file" "$dir")
launcher_launch "$resolved"
