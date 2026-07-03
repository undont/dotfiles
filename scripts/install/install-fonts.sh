#!/usr/bin/env bash
set -euo pipefail

# install Nerd Fonts on Linux.
#
# on macOS these come from the Brewfile casks (font-meslo-lg-nerd-font,
# font-jetbrains-mono-nerd-font), but Homebrew casks are macOS-only, so Linux
# has no brew path to them. this fetches the matching release archives from
# ryanoasis/nerd-fonts and installs the terminal weights into the user font
# directory. glyphs only render on a locally-attached display; over SSH the
# client terminal supplies the font, so this is skipped on headless servers by
# virtue of running only for the core preset and above.

SCRIPT_DIR="${BASH_SOURCE%/*}"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/../_lib/common.sh"

# fonts to install, keyed by the release asset name (<name>.zip) on
# github.com/ryanoasis/nerd-fonts/releases. mirrors the Brewfile casks.
NERD_FONTS=("Meslo" "JetBrainsMono")

# only the four terminal weights, for both the standard and Mono (single-cell
# glyph) variants; Propo (proportional) is skipped. the leading-hyphen suffixes
# match exact weights only, so -Bold does not also pull -ExtraBold/-SemiBold.
FONT_WEIGHTS=("Regular" "Bold" "Italic" "BoldItalic")

FONT_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/fonts"
NF_DIR="$FONT_DIR/nerd-fonts"
FORCE="${1:-}"

if is_macos; then
    info "Nerd Fonts install via Homebrew casks on macOS — skipping Linux path."
    exit 0
fi

# required tooling; fonts are non-critical so warn and skip rather than fail
for tool in curl unzip fc-cache; do
    if ! command_exists "$tool"; then
        warn "'$tool' not found — skipping Nerd Font install."
        echo "  Install $tool and re-run: dotfiles update --force"
        exit 0
    fi
done

installed_any=0

install_font() {
    local name="$1"
    local dest="$NF_DIR/$name"

    # idempotent: skip if we already populated this font's directory
    if [[ "$FORCE" != "--force" ]] && compgen -G "$dest/*.ttf" > /dev/null 2>&1; then
        echo "$name Nerd Font already installed."
        return 0
    fi

    local tmp
    tmp="$(mktemp -d)"
    # shellcheck disable=SC2064
    trap "rm -rf '$tmp'" RETURN

    local url="https://github.com/ryanoasis/nerd-fonts/releases/latest/download/${name}.zip"
    echo "Downloading $name Nerd Font..."
    if ! curl -fL --retry 2 -o "$tmp/$name.zip" "$url"; then
        warn "Failed to download $name Nerd Font (network issue?). Skipping."
        return 0
    fi

    if ! unzip -o -q "$tmp/$name.zip" -d "$tmp/extract"; then
        warn "Failed to extract $name Nerd Font. Skipping."
        return 0
    fi

    # build the -name predicate list for the wanted weights x variants
    local find_args=()
    local variant weight first=1
    for variant in NerdFont NerdFontMono; do
        for weight in "${FONT_WEIGHTS[@]}"; do
            [[ $first -eq 1 ]] || find_args+=(-o)
            find_args+=(-name "*${variant}-${weight}.ttf")
            first=0
        done
    done

    mkdir -p "$dest"
    local before after
    before=$(find "$dest" -maxdepth 1 -name '*.ttf' 2>/dev/null | wc -l)
    find "$tmp/extract" -type f \( "${find_args[@]}" \) -exec cp {} "$dest/" \;
    after=$(find "$dest" -maxdepth 1 -name '*.ttf' 2>/dev/null | wc -l)

    if [[ "$after" -gt "$before" ]]; then
        success "Installed $name Nerd Font ($((after - before)) files)"
        installed_any=1
    else
        warn "No matching $name Nerd Font files found (upstream naming changed?)."
        rmdir "$dest" 2>/dev/null || true
    fi
}

echo "Installing Nerd Fonts (Linux)..."
mkdir -p "$NF_DIR"
for font in "${NERD_FONTS[@]}"; do
    install_font "$font"
done

# refresh the fontconfig cache once, only if we added anything
if [[ "$installed_any" -eq 1 ]]; then
    echo "Rebuilding font cache..."
    fc-cache -f "$FONT_DIR" > /dev/null 2>&1 || warn "fc-cache reported an issue."
    success "Nerd Fonts ready. Set your terminal font to 'JetBrainsMono Nerd Font' or 'MesloLGS Nerd Font'."
fi
