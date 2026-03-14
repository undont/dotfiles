#!/usr/bin/env bash
# Brewfile filtering utilities
# Source this file: source "${BASH_SOURCE%/*}/_lib/brewfile.sh"

# Guard against multiple sourcing
[[ -n "${_DOTFILES_BREWFILE_SH_LOADED:-}" ]] && return 0
_DOTFILES_BREWFILE_SH_LOADED=1

# Filter Brewfile based on preset
# The Brewfile uses section markers like "# @preset: minimal"
# We include sections based on hierarchy: minimal < core < full
#
# Usage: filter_brewfile "preset" "brewfile_path"
# Arguments:
#   preset      - One of: minimal, core, full
#   brewfile    - Path to the Brewfile to filter
#
# Output: Filtered brewfile content to stdout
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

    # AWK state machine: filters Brewfile by preset.
    # Lines before the first @preset marker are always included (headers, taps).
    # When a @preset marker is hit, `include` is set based on whether that
    # preset level was requested (preset hierarchy: minimal ⊂ core ⊂ full).
    # The `next` skips the marker line itself from output.
    # Cask lines are additionally stripped on Linux (macOS-only packages).
    awk -v inc_min="$include_minimal" -v inc_core="$include_core" -v inc_full="$include_full" -v darwin="$is_darwin" '
    BEGIN {
        include = 1  # Include header lines before any preset marker
    }

    # Detect preset section markers
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

    # Skip cask lines on Linux (casks are macOS-only)
    darwin != "true" && /^cask / { next }

    # Skip formulas marked as macOS-only on Linux
    darwin != "true" && /# macOS-only/ { next }

    # Print lines if we should include this section
    include { print }
    ' "$brewfile"
}

# Create a temporary filtered Brewfile
# Creates a temp file and filters the Brewfile into it
#
# Usage: FILTERED_FILE=$(create_filtered_brewfile "preset" "brewfile_path")
# Arguments:
#   preset      - One of: minimal, core, full
#   brewfile    - Path to the Brewfile to filter
#
# Output: Path to temporary filtered Brewfile (caller must clean up)
# Note: Caller is responsible for removing the temp file
create_filtered_brewfile() {
    local preset="$1"
    local brewfile="$2"
    local filtered_file

    filtered_file=$(mktemp)

    # Filter and write to temp file
    if ! filter_brewfile "$preset" "$brewfile" > "$filtered_file"; then
        rm -f "$filtered_file"
        return 1
    fi

    echo "$filtered_file"
}
