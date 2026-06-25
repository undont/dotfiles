#!/usr/bin/env bash
# migration: remove CSharpier from Mason
# C# formatting now uses Roslyn LSP (via easy-dotnet) instead of CSharpier

set -euo pipefail

mason_pkg="${XDG_DATA_HOME:-$HOME/.local/share}/nvim/mason/packages/csharpier"

if [[ -d "$mason_pkg" ]]; then
    echo "    Removing CSharpier from Mason..."
    rm -rf "$mason_pkg"
    # remove the Mason bin symlink too
    mason_bin="${XDG_DATA_HOME:-$HOME/.local/share}/nvim/mason/bin/csharpier"
    rm -f "$mason_bin"
    echo "    CSharpier removed"
else
    echo "    CSharpier not installed in Mason, skipping"
fi
