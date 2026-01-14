#!/usr/bin/env bash
# Brewfile filtering utilities
# Source this file: source "${BASH_SOURCE%/*}/_lib/brewfile.sh"

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

    awk -v inc_min="$include_minimal" -v inc_core="$include_core" -v inc_full="$include_full" '
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

    # Print lines if we should include this section
    include { print }
    ' "$brewfile"
}
