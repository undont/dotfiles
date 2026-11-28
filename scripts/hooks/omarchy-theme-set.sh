#!/usr/bin/env bash
# omarchy theme-set hook: applies the omarchy theme as the dotfiles theme
# usage: omarchy-theme-set.sh [omarchy-theme-slug]
# linked into ~/.config/omarchy/hooks/theme-set.d/ by the manifest; with no
# argument it reads omarchy's current theme

set -euo pipefail

script_path="$(readlink -f "${BASH_SOURCE[0]}")"
DOTFILES_DIR="$(cd "${script_path%/*}/../.." && pwd)"
# shellcheck source=../_lib/common.sh
source "$DOTFILES_DIR/scripts/_lib/common.sh"

omarchy_current="$HOME/.local/state/omarchy/current"

# omarchy runs hooks with the session PATH, which has no homebrew
brew_bin="$(get_homebrew_prefix)/bin/brew"
if ! command_exists brew && [[ -x "$brew_bin" ]]; then
    eval "$("$brew_bin" shellenv)"
fi

slug="${1:-$(cat "$omarchy_current/theme.name" 2>/dev/null || true)}"
if [[ -z "$slug" ]]; then
    warn "No omarchy theme is set"
    exit 0
fi

# omarchy themes with a hand-crafted dotfiles theme under another name
case "$slug" in
    catppuccin) theme="catppuccin-mocha" ;;
    gruvbox) theme="gruvbox-dark" ;;
    *) theme="$slug" ;;
esac

if [[ ! -f "$DOTFILES_DIR/themes/$theme.theme" ]]; then
    ghostty_conf="$omarchy_current/theme/ghostty.conf"
    if [[ ! -f "$ghostty_conf" ]]; then
        warn "Omarchy theme $slug has no ghostty.conf to generate a dotfiles theme from"
        exit 0
    fi
    tmp=$(mktemp -d)
    trap 'rm -rf "$tmp"' EXIT
    # generate-theme names the theme after the file
    cp "$ghostty_conf" "$tmp/omarchy-$slug"
    theme=$("$DOTFILES_DIR/scripts/generate-theme" "$tmp/omarchy-$slug" --quiet)
fi

"$DOTFILES_DIR/scripts/theme-switch" "$theme" --quiet
