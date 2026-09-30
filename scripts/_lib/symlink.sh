#!/usr/bin/env bash
# shellcheck disable=SC1091
# symlink and config-install helpers for the installer
# source after common.sh (colour vars, success/info/warn) and rollback.sh
# (record_symlink)

[[ -n "${_DOTFILES_SYMLINK_SH_LOADED:-}" ]] && return 0
_DOTFILES_SYMLINK_SH_LOADED=1

# set to 1 by a failed create_link; callers read it after a batch of links
FAILED="${FAILED:-0}"

# backs up an existing non-symlink destination, records the link for
# rollback and sets FAILED on error
create_link() {
    local source="$1"
    local dest="$2"

    if [[ ! -e "$source" && ! -L "$source" ]]; then
        printf "${RED}FAILED:${NC} Source not found: %s\n" "$source"
        FAILED=1
        return 1
    fi

    mkdir -p "$(dirname "$dest")"

    if [[ -L "$dest" ]]; then
        rm "$dest"
    fi

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

    if ln -sf "$source" "$dest"; then
        printf "${GREEN}Created:${NC} %s -> %s\n" "$dest" "$source"
        record_symlink "$dest" "$source"
        return 0
    else
        printf "${RED}FAILED:${NC} Could not create symlink %s\n" "$dest"
        FAILED=1
        return 1
    fi
}

# copy-on-install: an existing destination is left untouched
copy_config() {
    local source="$1"
    local dest="$2"

    mkdir -p "$(dirname "$dest")"

    if [[ ! -e "$dest" ]]; then
        cp "$source" "$dest"
        success "Created $dest from dotfiles"
        printf '  %s→%s Edit with: nvim %s\n' "${CYAN}" "${NC}" "$dest"
    else
        info "Kept existing $dest"
    fi
}

# local override from a template: an existing destination is left untouched
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
