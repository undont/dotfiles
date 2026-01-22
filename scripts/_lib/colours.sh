#!/usr/bin/env bash
# Colour definitions for dotfiles scripts
# Source this file: source "${BASH_SOURCE%/*}/_lib/colours.sh"
#
# Note: Uses $'...' syntax for proper escape interpretation
# Use with printf for coloured output

# Standard colours
readonly RED=$'\033[0;31m'
readonly GREEN=$'\033[0;32m'
readonly YELLOW=$'\033[0;33m'
readonly CYAN=$'\033[0;36m'
readonly GREY=$'\033[0;90m'
readonly NC=$'\033[0m' # No Colour

# Export for subshells if needed
export RED GREEN YELLOW CYAN GREY NC
