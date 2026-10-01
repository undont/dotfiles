#!/usr/bin/env bash
set -euo pipefail

# installs nerd fonts into the user font directory on linux (macOS gets them
# from the Brewfile casks)
# usage: install-fonts.sh [--force]    --force reinstalls over existing files
#
# Meslo and JetBrainsMono are TTF assets from ryanoasis/nerd-fonts; Monaspace is
# the OTF build from githubnext/monaspace

SCRIPT_DIR="${BASH_SOURCE%/*}"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/../_lib/common.sh"

# release asset names (<name>.zip) on github.com/ryanoasis/nerd-fonts/releases
NERD_FONTS=("Meslo" "JetBrainsMono")

# installed for the standard and Mono variants; Propo is skipped. matched as
# "-<weight>", so Bold does not match ExtraBold or SemiBold
FONT_WEIGHTS=("Regular" "Bold" "Italic" "BoldItalic")

# monaspace family tokens as they appear in the file name
# (MonaspaceNeonNF-Regular.otf); others are Argon, Xenon, Radon, Krypton
MONASPACE_FAMILIES=("Neon")

FONT_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/fonts"
NF_DIR="$FONT_DIR/nerd-fonts"
FORCE="${1:-}"

if is_macos; then
    info "Nerd Fonts install via Homebrew casks on macOS — skipping Linux path."
    exit 0
fi

# a missing tool skips the font install without failing
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

    if [[ "$FORCE" != "--force" ]] && compgen -G "$dest/*.ttf" >/dev/null 2>&1; then
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

# the monaspace release asset name embeds the version
# (monaspace-nerdfonts-vX.Y.Z.zip), so its URL is resolved through the GitHub
# API instead of the latest/download shortcut
install_monaspace() {
    local dest="$NF_DIR/Monaspace"

    if [[ "$FORCE" != "--force" ]] && compgen -G "$dest/*.otf" >/dev/null 2>&1; then
        echo "Monaspace Nerd Font already installed."
        return 0
    fi

    local api="https://api.github.com/repos/githubnext/monaspace/releases/latest"
    local url
    url="$(curl -fsSL --retry 2 "$api" 2>/dev/null |
        grep -oE '"browser_download_url":[[:space:]]*"[^"]*monaspace-nerdfonts-[^"]*\.zip"' |
        sed -E 's/.*"(https[^"]*)"/\1/' | head -1)"
    if [[ -z "$url" ]]; then
        warn "Could not resolve latest Monaspace release (API/network issue?). Skipping."
        return 0
    fi

    local tmp
    tmp="$(mktemp -d)"
    # shellcheck disable=SC2064
    trap "rm -rf '$tmp'" RETURN

    echo "Downloading Monaspace Nerd Font..."
    if ! curl -fL --retry 2 -o "$tmp/monaspace.zip" "$url"; then
        warn "Failed to download Monaspace Nerd Font (network issue?). Skipping."
        return 0
    fi

    if ! unzip -o -q "$tmp/monaspace.zip" -d "$tmp/extract"; then
        warn "Failed to extract Monaspace Nerd Font. Skipping."
        return 0
    fi

    # exact names: the standard width has no width token, so Wide and
    # SemiWide files do not match
    local find_args=()
    local family weight first=1
    for family in "${MONASPACE_FAMILIES[@]}"; do
        for weight in "${FONT_WEIGHTS[@]}"; do
            [[ $first -eq 1 ]] || find_args+=(-o)
            find_args+=(-name "Monaspace${family}NF-${weight}.otf")
            first=0
        done
    done

    mkdir -p "$dest"
    local before after
    before=$(find "$dest" -maxdepth 1 -name '*.otf' 2>/dev/null | wc -l)
    find "$tmp/extract" -type f \( "${find_args[@]}" \) -exec cp {} "$dest/" \;
    after=$(find "$dest" -maxdepth 1 -name '*.otf' 2>/dev/null | wc -l)

    if [[ "$after" -gt "$before" ]]; then
        success "Installed Monaspace Nerd Font ($((after - before)) files)"
        installed_any=1
    else
        warn "No matching Monaspace Nerd Font files found (upstream naming changed?)."
        rmdir "$dest" 2>/dev/null || true
    fi
}

echo "Installing Nerd Fonts (Linux)..."
mkdir -p "$NF_DIR"
for font in "${NERD_FONTS[@]}"; do
    install_font "$font"
done
install_monaspace

if [[ "$installed_any" -eq 1 ]]; then
    echo "Rebuilding font cache..."
    fc-cache -f "$FONT_DIR" >/dev/null 2>&1 || warn "fc-cache reported an issue."
    success "Nerd Fonts ready. Set your terminal font to 'JetBrainsMono Nerd Font', 'MesloLGS Nerd Font', or 'Monaspace Neon NF'."
fi
