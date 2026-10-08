#!/usr/bin/env bash
# reader for scripts/manifest.conf. source after common.sh

[[ -n "${_DOTFILES_MANIFEST_SH_LOADED:-}" ]] && return 0
_DOTFILES_MANIFEST_SH_LOADED=1

: "${DOTFILES_DIR:?DOTFILES_DIR must be set before sourcing manifest.sh}"

MANIFEST_FILE="$DOTFILES_DIR/scripts/manifest.conf"

# usage: _manifest_path var path
# ~, $cfg and $appsupport expand to absolute paths, anything else is
# repo-relative
_manifest_path() {
    local cfg="${XDG_CONFIG_HOME:-$HOME/.config}"
    case "$2" in
        -) printf -v "$1" '%s' "-" ;;
        "~"/*) printf -v "$1" '%s' "$HOME/${2#"~/"}" ;;
        '$cfg'/*) printf -v "$1" '%s' "$cfg/${2#'$cfg/'}" ;;
        '$appsupport'/*) printf -v "$1" '%s' "$HOME/Library/Application Support/${2#'$appsupport/'}" ;;
        *) printf -v "$1" '%s' "$DOTFILES_DIR/$2" ;;
    esac
}

# prints every entry as kind, preset, os, group, source, dest and local key,
# tab-separated and unexpanded, with - for an omitted local key
manifest_entries() {
    local line group="" kind preset row_os source dest local_key
    while IFS= read -r line; do
        case "$line" in
            '' | \#*) continue ;;
            \[*\])
                group="${line:1:${#line}-2}"
                continue
                ;;
        esac
        read -r kind preset row_os source dest local_key <<<"$line"
        printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
            "$kind" "$preset" "$row_os" "$group" "$source" "$dest" "${local_key:--}"
    done <"$MANIFEST_FILE"
}

# usage: manifest_rows [kind...]
# prints kind, group, source, dest and local key, tab-separated with paths
# expanded, for rows matching $PRESET and this os. no kinds means every row
manifest_rows() {
    local os=linux kind preset row_os group source dest local_key k want
    is_macos && os=macos

    while IFS=$'\t' read -r kind preset row_os group source dest local_key; do
        [[ "$row_os" == any || "$row_os" == "$os" ]] || continue
        should_install "$preset" || continue
        if [[ $# -gt 0 ]]; then
            want=0
            for k in "$@"; do
                [[ "$k" == "$kind" ]] && want=1
            done
            [[ $want -eq 1 ]] || continue
        fi
        _manifest_path source "$source"
        _manifest_path dest "$dest"
        printf '%s\t%s\t%s\t%s\t%s\n' "$kind" "$group" "$source" "$dest" "$local_key"
    done < <(manifest_entries)
}
