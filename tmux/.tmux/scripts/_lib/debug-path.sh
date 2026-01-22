#!/bin/bash
_COMMON_LIB_DIR="$(cd "${BASH_SOURCE%/*}" && pwd)"
echo "_COMMON_LIB_DIR: $_COMMON_LIB_DIR"
DOTFILES_ROOT="$(cd "$_COMMON_LIB_DIR/../../../.." && pwd)"
echo "DOTFILES_ROOT: $DOTFILES_ROOT"
echo "Looking for: $DOTFILES_ROOT/scripts/_lib/colours.sh"
ls -la "$DOTFILES_ROOT/scripts/_lib/colours.sh" 2>&1
