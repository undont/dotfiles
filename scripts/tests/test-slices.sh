#!/usr/bin/env bash
set -euo pipefail

# test suite for the slice framework (_lib/slices.sh) and the shipped slices

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
export DOTFILES_DIR

# shellcheck source=/dev/null
source "$DOTFILES_DIR/scripts/_lib/common.sh"
# shellcheck source=/dev/null
source "$DOTFILES_DIR/scripts/_lib/slices.sh"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/_test-helpers.sh"

section "Slice Framework Tests"

section "Discovery"

# every shipped slice script should be discovered
slices_out="$(slice_list)"
for expected in nvim zoxide nerd-fonts; do
    if printf '%s\n' "$slices_out" | grep -qx "$expected"; then
        pass "slice_list includes '$expected'"
    else
        fail "slice_list should include '$expected'"
    fi
done

assert_success "slice_exists finds nvim" slice_exists nvim
assert_failure "slice_exists rejects unknown slice" slice_exists definitely-not-a-slice

section "Metadata"

assert_equals "nvim description" "Neovim editor + config" "$(slice_desc nvim)"
assert_equals "nvim declares core preset" "core" "$(slice_preset nvim)"
assert_equals "nvim requires nerd-fonts" "nerd-fonts" "$(slice_requires nvim)"
assert_equals "zoxide has no requires" "" "$(slice_requires zoxide)"

section "Dependency Resolution"

# nvim pulls in nerd-fonts, dependency-first
resolved="$(slice_resolve nvim | paste -sd ',' -)"
assert_equals "resolve nvim expands + orders deps first" "nerd-fonts,nvim" "$resolved"

# dedup across multiple requests that share a dependency
resolved_multi="$(slice_resolve nvim nerd-fonts | paste -sd ',' -)"
assert_equals "resolve dedupes shared deps" "nerd-fonts,nvim" "$resolved_multi"

# unknown slice fails resolution
assert_failure "resolve rejects unknown slice" slice_resolve bogus-slice

section "Brewfile @slice tag extraction"

# build a fixture Brewfile with tags and a documentation line that must NOT match
FIXTURE=$(mktemp)
trap 'rm -f "$FIXTURE"' EXIT
cat > "$FIXTURE" << 'EOF'
# @slice: nvim, search   <- this is a doc comment and must be ignored
tap "example/tap"
brew "neovim"       # editor; @slice: nvim
brew "ripgrep"      # search; @slice: nvim, search
brew "zoxide"       # @slice: zoxide
brew "untagged"     # no slice tag
cask "font-x"       # @slice: nerd-fonts
EOF

nvim_pkgs="$(slice_brewfile_packages nvim "$FIXTURE")"
if printf '%s\n' "$nvim_pkgs" | grep -q '"neovim"' && printf '%s\n' "$nvim_pkgs" | grep -q '"ripgrep"'; then
    pass "extracts nvim-tagged formulae"
else
    fail "should extract neovim + ripgrep for nvim"
fi
if printf '%s\n' "$nvim_pkgs" | grep -q '"zoxide"'; then
    fail "nvim extraction leaked an untagged/other-slice package"
else
    pass "nvim extraction excludes other slices"
fi
if printf '%s\n' "$nvim_pkgs" | grep -q 'doc comment'; then
    fail "extraction matched a documentation comment line"
else
    pass "extraction ignores documentation comment lines"
fi

# multi-slice line: ripgrep is tagged for both nvim and search
search_pkgs="$(slice_brewfile_packages search "$FIXTURE")"
if printf '%s\n' "$search_pkgs" | grep -q '"ripgrep"'; then
    pass "multi-slice line matches each listed slice"
else
    fail "ripgrep tagged 'nvim, search' should match slice 'search'"
fi

# platform-aware: casks are dropped on Linux, kept on macOS
fonts_pkgs="$(slice_brewfile_packages nerd-fonts "$FIXTURE")"
if is_macos; then
    if printf '%s\n' "$fonts_pkgs" | grep -q 'cask "font-x"'; then
        pass "cask retained for slice on macOS"
    else
        fail "cask should be retained on macOS"
    fi
else
    if [[ -z "${fonts_pkgs//[[:space:]]/}" ]]; then
        pass "cask-only slice yields no packages on Linux"
    else
        fail "casks should be stripped on Linux (got: $fonts_pkgs)"
    fi
fi

section "Real Brewfile is tagged consistently"

# the shipped slices must resolve to at least one package on some platform;
# nvim is formula-based so it must be non-empty everywhere
real_nvim="$(slice_brewfile_packages nvim)"
if printf '%s\n' "$real_nvim" | grep -q '"neovim"'; then
    pass "real Brewfile tags neovim for the nvim slice"
else
    fail "real Brewfile should tag neovim with @slice: nvim"
fi

print_summary

if [[ $FAIL -gt 0 ]]; then
    exit 1
fi
