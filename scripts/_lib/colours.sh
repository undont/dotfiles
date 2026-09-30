#!/usr/bin/env bash
# colour definitions for dotfiles scripts
# source this file: source "${BASH_SOURCE%/*}/_lib/colours.sh"

# readonly variables can't be redefined on a second source
if [[ -z "${DOTFILES_COLOURS_LOADED:-}" ]]; then
    readonly DOTFILES_COLOURS_LOADED=1

    readonly RED=$'\033[0;31m'
    readonly GREEN=$'\033[0;32m'
    readonly YELLOW=$'\033[0;33m'
    readonly CYAN=$'\033[0;36m'
    readonly GREY=$'\033[0;90m'
    readonly NC=$'\033[0m'

    export RED GREEN YELLOW CYAN GREY NC
fi
