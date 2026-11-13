#!/usr/bin/env bash
# shellcheck disable=SC1091
set -euo pipefail

# creates the symlinks, local override files and generated configs listed in
# scripts/manifest.toml for a preset

SCRIPT_DIR="${BASH_SOURCE%/*}"
DOTFILES_DIR="${DOTFILES_DIR:-$(cd "$(dirname "$(dirname "$SCRIPT_DIR")")" && pwd)}"
export DOTFILES_DIR

source "$SCRIPT_DIR/../_lib/common.sh"
source "$SCRIPT_DIR/../_lib/rollback.sh"
# symlink.sh needs common.sh and rollback.sh loaded first
source "$SCRIPT_DIR/../_lib/symlink.sh"
source "$SCRIPT_DIR/../_lib/manifest.sh"

PRESET="${DOTFILES_PRESET:-full}"
FAILED=0

if ! command_exists yq; then
    error "yq is required to read $MANIFEST_FILE (brew install yq)"
    exit 1
fi

print_section "Creating symlinks"
echo "Source: $DOTFILES_DIR"
echo "Preset: $PRESET"
echo ""

# the yazi dir is linked per file, so a whole-dir symlink from an older
# install is replaced with a real directory first
if should_install "core" && [[ -L "${XDG_CONFIG_HOME:-$HOME/.config}/yazi" ]]; then
    rm "${XDG_CONFIG_HOME:-$HOME/.config}/yazi"
fi

# tmux loads ~/.tmux.conf as well as the generated config, so a ~/.tmux.conf
# symlink to it is removed
tmux_conf="${XDG_CONFIG_HOME:-$HOME/.config}/tmux/tmux.conf"
if [[ -L "$HOME/.tmux.conf" && "$(readlink "$HOME/.tmux.conf")" == "$tmux_conf" ]]; then
    rm "$HOME/.tmux.conf"
elif [[ -e "$HOME/.tmux.conf" ]]; then
    warn "tmux loads $HOME/.tmux.conf as well as the generated $tmux_conf"
fi

# on a preset change, the previous preset's links are removed before this
# preset's are created; one re-pointed by hand is kept
saved_preset_file="${XDG_CONFIG_HOME:-$HOME/.config}/dotfiles/preset"
saved_preset=$(cat "$saved_preset_file" 2>/dev/null || true)
if [[ -n "$saved_preset" && "$saved_preset" != "$PRESET" ]]; then
    while IFS=$'\t' read -r _ _ source dest _; do
        if [[ -L "$dest" && "$(readlink "$dest")" == "$source" ]]; then
            rm "$dest"
        fi
    done < <(PRESET="$saved_preset" manifest_rows link)
    info "Removed the $saved_preset preset's links"
fi

group_shown=""
while IFS=$'\t' read -r kind group source dest _; do
    if [[ "$group" != "$group_shown" ]]; then
        [[ -n "$group_shown" ]] && echo ""
        echo "$group:"
        group_shown="$group"
    fi
    case "$kind" in
        link) create_link "$source" "$dest" ;;
        copy) copy_config "$source" "$dest" ;;
        local) install_local "$source" "$dest" ;;
    esac
done < <(manifest_rows link copy local)

if ! grep -q "dotfiles.zsh" "$HOME/.zshrc" 2>/dev/null; then
    warn "$HOME/.zshrc doesn't source dotfiles.zsh"
    info "Add this line to source the framework: source ~/dotfiles/zsh/dotfiles.zsh"
fi

if should_install "core"; then
    # .luarc.json (lua_ls workspace config) lives at the repo root, which is
    # lua_ls's workspace. gitignored, and overwritten from the template each run
    cp "$DOTFILES_DIR/.luarc.json.template" "$DOTFILES_DIR/.luarc.json"
    success "Installed $DOTFILES_DIR/.luarc.json (lua_ls workspace config)"

    # user spell dictionary (zg adds words here, repo dictionary has shared terms)
    user_spell_dir="${XDG_DATA_HOME:-$HOME/.local/share}/nvim/spell"
    mkdir -p "$user_spell_dir"
    if [[ ! -f "$user_spell_dir/en.utf-8.add" ]]; then
        touch "$user_spell_dir/en.utf-8.add"
        success "Created user spell dictionary at $user_spell_dir/en.utf-8.add"
    fi
fi

# ─────────────────────────────────────────
# generate themed configurations
# ─────────────────────────────────────────
echo ""
info "Generating themed configurations"

if [[ -x "$DOTFILES_DIR/scripts/theme-switch" ]]; then
    current_theme="dracula"
    theme_file="${XDG_CONFIG_HOME:-$HOME/.config}/dotfiles/current-theme"

    if [[ -f "$theme_file" ]]; then
        current_theme=$(cat "$theme_file")
    fi

    info "Applying theme: $current_theme"
    "$DOTFILES_DIR/scripts/theme-switch" "$current_theme" --quiet || {
        warn "Failed to apply theme, using default (dracula)"
        "$DOTFILES_DIR/scripts/theme-switch" dracula --quiet
    }
    success "Generated themed configurations"
else
    warn "theme-switch script not found, skipping theme generation"
fi

echo ""

record_step "symlinks"

if [[ $FAILED -eq 0 ]]; then
    success "All symlinks created successfully!"
    exit 0
else
    error "Some symlinks failed to create. Check the output above."
    exit 1
fi
