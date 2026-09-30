#!/usr/bin/env bash
# Brewfile filtering utilities
# source this file: source "${BASH_SOURCE%/*}/_lib/brewfile.sh"

[[ -n "${_DOTFILES_BREWFILE_SH_LOADED:-}" ]] && return 0
_DOTFILES_BREWFILE_SH_LOADED=1

# prints the Brewfile sections for a preset (minimal, core or full). sections
# start at "# @preset: <name>" markers and nest: minimal < core < full
# usage: filter_brewfile "preset" "brewfile_path"
filter_brewfile() {
    local preset="$1"
    local brewfile="$2"
    local include_minimal=true
    local include_core=false
    local include_full=false

    case "$preset" in
        minimal)
            include_minimal=true
            ;;
        core)
            include_minimal=true
            include_core=true
            ;;
        full)
            include_minimal=true
            include_core=true
            include_full=true
            ;;
        *)
            echo "Error: Invalid preset '$preset'. Must be: minimal, core, or full" >&2
            return 1
            ;;
    esac

    local is_darwin="true"
    [[ "$(uname)" != "Darwin" ]] && is_darwin="false"

    # lines before the first @preset marker (headers, taps) are always
    # included; marker lines themselves are dropped
    awk -v inc_min="$include_minimal" -v inc_core="$include_core" -v inc_full="$include_full" -v darwin="$is_darwin" '
    BEGIN {
        include = 1
    }

    /^# @preset: minimal/ {
        include = (inc_min == "true") ? 1 : 0
        next
    }
    /^# @preset: core/ {
        include = (inc_core == "true") ? 1 : 0
        next
    }
    /^# @preset: full/ {
        include = (inc_full == "true") ? 1 : 0
        next
    }

    # casks are macOS-only
    darwin != "true" && /^cask / { next }

    darwin != "true" && /# macOS-only/ { next }

    include { print }
    ' "$brewfile"
}

# prints the path of a temp file holding the filtered Brewfile; the caller
# removes it
# usage: FILTERED_FILE=$(create_filtered_brewfile "preset" "brewfile_path")
create_filtered_brewfile() {
    local preset="$1"
    local brewfile="$2"
    local filtered_file

    filtered_file=$(mktemp)

    if ! filter_brewfile "$preset" "$brewfile" >"$filtered_file"; then
        rm -f "$filtered_file"
        return 1
    fi

    echo "$filtered_file"
}
