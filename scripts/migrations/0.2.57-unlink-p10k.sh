#!/bin/bash
# migration: convert p10k.zsh from symlink to user-owned copy
# p10k.zsh is no longer tracked in the repo; users should own their config
# via `p10k configure`

set -euo pipefail

p10k="$HOME/.p10k.zsh"

if [[ -L "$p10k" ]]; then
    target="$(readlink "$p10k")"
    if [[ -f "$target" ]]; then
        # copy the symlink target contents to a regular file
        cp "$target" "${p10k}.tmp"
        rm "$p10k"
        mv "${p10k}.tmp" "$p10k"
        echo "    Converted ~/.p10k.zsh from symlink to standalone copy"
    else
        # symlink points to a missing file, remove it
        rm "$p10k"
        echo "    Removed broken symlink ~/.p10k.zsh (run: p10k configure)"
    fi
fi
