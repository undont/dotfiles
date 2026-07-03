#!/usr/bin/env bash
# shellcheck disable=SC1091
set -euo pipefail

# nvim slice: Neovim + its config. Pulls in nerd-fonts (icons) as a dependency.
# Packages (neovim, tree-sitter-cli, ripgrep, fd) come from the Brewfile
# @slice tag. lazy.nvim auto-installs on first launch, so there is no plugin
# bootstrap here.

SCRIPT_DIR="${BASH_SOURCE%/*}"
DOTFILES_DIR="${DOTFILES_DIR:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
export DOTFILES_DIR

source "$DOTFILES_DIR/scripts/_lib/common.sh"
source "$DOTFILES_DIR/scripts/_lib/rollback.sh"
source "$DOTFILES_DIR/scripts/_lib/symlink.sh"
source "$DOTFILES_DIR/scripts/_lib/slices.sh"

SLICE_NAME="nvim"
SLICE_DESC="Neovim editor + config"
SLICE_PRESET="core"
SLICE_REQUIRES="nerd-fonts"

slice_link() {
    echo "Neovim configuration:"
    create_link "$DOTFILES_DIR/nvim" "$HOME/.config/nvim"

    install_local "$DOTFILES_DIR/nvim/local.lua.template" "$HOME/.config/nvim/local.lua"

    # install .luarc.json (lua_ls workspace config) from the template. the
    # dotfiles repo root is lua_ls's workspace, so .luarc.json lives there.
    # kept machine-local (gitignored) so diagnostics can be tweaked per machine.
    # plugin and nvim runtime type libraries are supplied on demand by
    # lazydev.nvim, so there is no machine-specific path to substitute
    cp "$DOTFILES_DIR/.luarc.json.template" "$DOTFILES_DIR/.luarc.json"
    success "Installed $DOTFILES_DIR/.luarc.json (lua_ls workspace config)"

    # user spell dictionary (zg adds words here, repo dictionary has shared terms)
    local user_spell_dir="${XDG_DATA_HOME:-$HOME/.local/share}/nvim/spell"
    mkdir -p "$user_spell_dir"
    if [[ ! -f "$user_spell_dir/en.utf-8.add" ]]; then
        touch "$user_spell_dir/en.utf-8.add"
        success "Created user spell dictionary at $user_spell_dir/en.utf-8.add"
    fi

    # propagate create_link failures to the caller's exit code
    [[ "${FAILED:-0}" -eq 0 ]]
}

slice_postinstall() {
    info "lazy.nvim will auto-install plugins when you first open Neovim."
}

slice_main "$@"
