#!/usr/bin/env bash
# reader for scripts/manifest.toml. source after common.sh

[[ -n "${_DOTFILES_MANIFEST_SH_LOADED:-}" ]] && return 0
_DOTFILES_MANIFEST_SH_LOADED=1

: "${DOTFILES_DIR:?DOTFILES_DIR must be set before sourcing manifest.sh}"

MANIFEST_FILE="$DOTFILES_DIR/scripts/manifest.toml"

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
# tab-separated and unexpanded, in file order, with - for an omitted source.
# a local, copy or sync entry's local key is its dest with ~/. dropped, $cfg/
# as config/ and $appsupport/ dropped, unless it sets local; a link's is -
# shellcheck disable=SC2016 # yq source
manifest_entries() {
    if ! command_exists yq; then
        error "yq is required to read $MANIFEST_FILE"
        return 1
    fi
    yq -p toml -o tsv '
        to_entries[] | .key as $group | .value as $tool
        | ($tool | to_entries[] | select(.key | test("^(link|copy|local|sync)$"))) as $kind
        | $kind.value[]
        | (.local // (.dest | sub("/$"; "") | sub("^~/\\."; "") | sub("^\\$cfg/"; "config/") | sub("^\\$appsupport/"; ""))) as $derived
        | [$kind.key, $tool.preset, .os // $tool.os // "any", $group, .source // "-", .dest,
           (if $kind.key == "link" then "-" else $derived end)]
        | @tsv' "$MANIFEST_FILE"
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
