#!/usr/bin/env bash
set -euo pipefail

# binds code file extensions to zed with duti (macOS only)
#
# macOS 15+ shows a modal consent dialog per handler change, so an extension
# is asked about once: it is skipped when zed already handles it or when it is
# listed in .state/declined-default-apps

SCRIPT_DIR="${BASH_SOURCE%/*}"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/../_lib/common.sh"

ZED_BUNDLE="dev.zed.Zed"
LSREGISTER="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"
STATE_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/dotfiles/.state"
DECLINED_FILE="$STATE_DIR/declined-default-apps"

# html is left to the browser
EXTENSIONS=(go cs lua md ts tsx env json yaml yml toml css js jsx log)

# an extension governed by a system-declared UTI that another app claims is
# bound by that UTI, since the bare extension loses to it. a case, not an
# associative array: macOS ships bash 3.2
bind_target() {
    case "$1" in
        log) printf '%s' 'com.apple.log' ;;
        *) printf '.%s' "$1" ;;
    esac
}

if ! is_macos; then
    info "default-app handlers are macOS-only, skipping"
    exit 0
fi

if ! command_exists duti; then
    warn "duti not installed, skipping default-app setup (brew install duti)"
    exit 0
fi

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

# with a stale LaunchServices registration duti's set succeeds but another
# app keeps the binding
if [[ -x "$LSREGISTER" ]]; then
    "$LSREGISTER" -f "$zed_app" 2>/dev/null || true
fi

# an extension with only dynamic (dyn.*) UTIs can't be bound: LaunchServices
# returns -50
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

# duti -x prints the handler bundle id on its own line
handler_is_zed() {
    duti -x "$1" 2>/dev/null | grep -qx "$ZED_BUNDLE"
}

declined_before() {
    [[ -f "$DECLINED_FILE" ]] && grep -qx "$1" "$DECLINED_FILE"
}

record_declined() {
    declined_before "$1" || printf '%s\n' "$1" >>"$DECLINED_FILE"
}

mkdir -p "$STATE_DIR"

set_count=0      # newly bound this run
already_count=0  # already handled by Zed
declined_count=0 # skipped or recorded as declined
skip_count=0     # unbindable, no stable UTI
for ext in "${EXTENSIONS[@]}"; do
    if ! has_real_uti "$ext"; then
        skip_count=$((skip_count + 1))
        continue
    fi
    if handler_is_zed "$ext"; then
        already_count=$((already_count + 1))
        continue
    fi
    if declined_before "$ext"; then
        declined_count=$((declined_count + 1))
        continue
    fi

    # the consent dialog blocks duti, so the re-check reflects the user's choice
    duti -s "$ZED_BUNDLE" "$(bind_target "$ext")" all 2>/dev/null || true
    if handler_is_zed "$ext"; then
        set_count=$((set_count + 1))
    else
        record_declined "$ext"
        declined_count=$((declined_count + 1))
    fi
done

success "Zed default apps: $set_count set, $already_count already set, $declined_count declined, $skip_count no stable type"
