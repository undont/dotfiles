#!/usr/bin/env bash
set -euo pipefail

# ══════════════════════════════════════════════════════════════
# duplicate launcher
# ══════════════════════════════════════════════════════════════
# copies a launcher to USER_LAUNCHERS with a "-copy" suffix.
# successive duplicates get "-copy-2", "-copy-3", etc.
#
# usage: duplicate.sh <launcher_name>

SCRIPT_DIR="${BASH_SOURCE%/*}"

# shellcheck source=tmux/scripts/_lib/launcher-data.sh
source "$SCRIPT_DIR/../_lib/launcher-data.sh"

name="${1:-}"
[[ -n "$name" ]] || exit 0

# prevent path traversal
name=$(basename "$name")
if [[ "$name" == *"/"* ]] || [[ "$name" == "." ]] || [[ "$name" == ".." ]]; then
    exit 1
fi

source_file=$(launcher_file "$name") || exit 1

# generate unique copy name: name-copy, name-copy-2, name-copy-3, ...
# strip any existing "-copy" or "-copy-N" suffix first so duplicating a copy
# still bases the numbering on the original name
base_name="$name"
base_name=$(printf '%s' "$base_name" | sed -E 's/-copy(-[0-9]+)?$//')

copy_name="${base_name}-copy"
if launcher_file "$copy_name" >/dev/null; then
    n=2
    while launcher_file "${base_name}-copy-${n}" >/dev/null; do
        ((n++))
    done
    copy_name="${base_name}-copy-${n}"
fi

mkdir -p "$USER_LAUNCHERS"
copy="$USER_LAUNCHERS/$copy_name.toml"
/bin/cp "$source_file" "$copy"
launcher_write "$copy" "$(launcher_json "$copy" | jq -c --arg d "Copy of $name" '.description = $d')"

# output the copy name so the caller can hand off to the wizard
printf '%s' "$copy_name"
