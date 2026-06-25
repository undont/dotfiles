#!/usr/bin/env bash
# migration: convert ~/.config/yazi from a whole-directory symlink into a real
# directory with per-file symlinks.
#
# yazi was previously symlinked as a whole directory (~/.config/yazi -> repo/yazi).
# `dotfiles theme` now generates a theme.toml into the yazi config dir, and with a
# whole-dir symlink that generated file would land back inside the repo. removing
# the symlink here lets the symlinks step (create-symlinks.sh, which runs straight
# after migrations during `dotfiles update`) recreate yazi.toml and keymap.toml as
# individual links and leave room for the generated theme.toml

set -euo pipefail

yazi_dir="$HOME/.config/yazi"

if [[ -L "$yazi_dir" ]]; then
    rm "$yazi_dir"
    echo "    Removed legacy whole-dir symlink ~/.config/yazi"
    echo "    (per-file symlinks are recreated by the symlinks step)"
fi
