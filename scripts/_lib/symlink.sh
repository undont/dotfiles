#!/usr/bin/env bash
# shellcheck disable=SC1091
# Symlink / config-install helpers shared by the installer and slice scripts.
# source this file: source "${BASH_SOURCE%/*}/symlink.sh"
#
# Requires (source these FIRST):
#   common.sh   - colour vars (RED/GREEN/YELLOW/CYAN/NC) + success/info/warn
#   rollback.sh - record_symlink (a no-op when rollback state is not initialised,
#                 so slices run standalone still work; run under install.sh they
#                 append to the shared .install-state log for rollback)
#
# Callers read the FAILED counter after a batch of create_link calls to decide
# overall success (see create-symlinks.sh). It is guard-initialised so sourcing
# this file never clobbers a caller that already tracks its own FAILED.

# guard against multiple sourcing
[[ -n "${_DOTFILES_SYMLINK_SH_LOADED:-}" ]] && return 0
_DOTFILES_SYMLINK_SH_LOADED=1

# shared failure flag for a batch of link operations (don't clobber caller's)
FAILED="${FAILED:-0}"

# create a symlink, backing up any existing non-symlink destination inline.
# records the link for rollback and flips FAILED on error.
create_link() {
    local source="$1"
    local dest="$2"

    # validate source exists before creating symlink
    if [[ ! -e "$source" && ! -L "$source" ]]; then
        printf "${RED}FAILED:${NC} Source not found: %s\n" "$source"
        FAILED=1
        return 1
    fi

    # ensure parent directory exists
    mkdir -p "$(dirname "$dest")"

    # remove existing symlink if present
    if [[ -L "$dest" ]]; then
        rm "$dest"
    fi

    # if destination exists and is not a symlink, back it up inline
    if [[ -e "$dest" ]]; then
        local backup_base="$HOME/.dotfiles-backup"
        local backup_dir
        backup_dir="$backup_base/inline-$(date +%Y%m%d-%H%M%S)-$$"
        mkdir -p "$backup_base"
        chmod 700 "$backup_base"
        mkdir -p "$backup_dir"
        chmod 700 "$backup_dir"

        local relative_path="${dest#"$HOME"/}"
        local backup_path="$backup_dir/$relative_path"
        mkdir -p "$(dirname "$backup_path")"

        mv "$dest" "$backup_path"
        printf "${YELLOW}Backed up:${NC} %s -> %s\n" "$dest" "$backup_path"
    fi

    # create symlink
    if ln -sf "$source" "$dest"; then
        printf "${GREEN}Created:${NC} %s -> %s\n" "$dest" "$source"
        # record for rollback (no-op if state not initialised)
        record_symlink "$dest" "$source"
        return 0
    else
        printf "${RED}FAILED:${NC} Could not create symlink %s\n" "$dest"
        FAILED=1
        return 1
    fi
}

# copy config file from repo to destination (copy-on-install pattern).
# if destination already exists, keeps it untouched (user-owned)
copy_config() {
    local source="$1"
    local dest="$2"

    # ensure parent directory exists
    mkdir -p "$(dirname "$dest")"

    if [[ ! -e "$dest" ]]; then
        cp "$source" "$dest"
        success "Created $dest from dotfiles"
        printf '  %s→%s Edit with: nvim %s\n' "${CYAN}" "${NC}" "$dest"
    else
        info "Kept existing $dest"
    fi
}

# install a local override file from template (never overwrite user customisations)
install_local() {
    local template="$1"
    local dest="$2"

    mkdir -p "$(dirname "$dest")"
    if [[ ! -f "$dest" ]]; then
        cp "$template" "$dest"
        success "Created $dest from template"
        printf '  %s→%s Edit with: nvim %s\n' "${CYAN}" "${NC}" "$dest"
    else
        info "Kept existing $dest"
    fi
}
