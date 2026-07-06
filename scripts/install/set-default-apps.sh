#!/usr/bin/env bash
set -euo pipefail

# set Zed as the default handler for code file types (macOS only)
#
# uses duti to bind file extensions to Zed. two macOS quirks are handled:
#   - a stale LaunchServices registration makes duti's set a silent no-op
#     (the write succeeds but a competing app keeps winning), so Zed is
#     re-registered first
#   - extensions with no system-declared UTI resolve to an ephemeral dyn.*
#     type that LaunchServices refuses to bind (error -50), so they're
#     skipped. Zed already claims some of these (go, jsx) via its own
#     Info.plist, so they open in Zed regardless

SCRIPT_DIR="${BASH_SOURCE%/*}"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/../_lib/common.sh"

ZED_BUNDLE="dev.zed.Zed"
LSREGISTER="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"

# extensions to route to Zed. html is intentionally left to the browser.
# dynamic-UTI extensions (cs, lua, env, ...) are skipped automatically.
EXTENSIONS=(go cs lua md ts tsx env json yaml yml toml css js jsx)

if ! is_macos; then
    info "default-app handlers are macOS-only, skipping"
    exit 0
fi

if ! command_exists duti; then
    warn "duti not installed, skipping default-app setup (brew install duti)"
    exit 0
fi

# locate Zed so its LaunchServices record can be refreshed
zed_app=""
for candidate in "/Applications/Zed.app" "$HOME/Applications/Zed.app"; do
    if [[ -d "$candidate" ]]; then
        zed_app="$candidate"
        break
    fi
done

if [[ -z "$zed_app" ]]; then
    info "Zed not found, skipping default-app setup"
    exit 0
fi

# refresh Zed's registration so duti's writes actually win the type binding
if [[ -x "$LSREGISTER" ]]; then
    "$LSREGISTER" -f "$zed_app" 2>/dev/null || true
fi

# an extension is bindable only if it resolves to at least one real
# (non-dynamic) UTI; dynamic-only extensions can't be set and return -50
has_real_uti() {
    local ext="$1" line
    while IFS= read -r line; do
        case "$line" in
            *identifier:*dyn.*) ;;
            *identifier:*) return 0 ;;
        esac
    done < <(duti -e "$ext" 2>/dev/null)
    return 1
}

set_count=0
skip_count=0
for ext in "${EXTENSIONS[@]}"; do
    if ! has_real_uti "$ext"; then
        skip_count=$((skip_count + 1))
        continue
    fi
    if duti -s "$ZED_BUNDLE" ".$ext" all 2>/dev/null; then
        set_count=$((set_count + 1))
    else
        warn "could not set Zed as handler for .$ext"
    fi
done

success "Zed set as default for $set_count code file types ($skip_count skipped, no stable type)"
