#!/usr/bin/env bash
# shellcheck disable=SC1091
# rollback state for installation scripts; source after common.sh
#
#   state.txt           append-only log of completed install steps
#   symlinks.txt        "link_path|target_path" records of created symlinks
#   backup-location.txt path to the timestamped backup directory
#
# perform_rollback removes the recorded symlinks, restores the backup, then
# deletes the state. cleanup_rollback_state deletes it after a successful install

[[ -n "${_DOTFILES_ROLLBACK_SH_LOADED:-}" ]] && return 0
_DOTFILES_ROLLBACK_SH_LOADED=1

ROLLBACK_STATE_DIR="${DOTFILES_DIR:-.}/.install-state"
ROLLBACK_STATE_FILE="$ROLLBACK_STATE_DIR/state.txt"
SYMLINKS_CREATED_FILE="$ROLLBACK_STATE_DIR/symlinks.txt"
BACKUP_LOCATION_FILE="$ROLLBACK_STATE_DIR/backup-location.txt"

init_rollback_state() {
    rm -rf "$ROLLBACK_STATE_DIR"
    mkdir -p "$ROLLBACK_STATE_DIR"
    chmod 700 "$ROLLBACK_STATE_DIR"

    touch "$ROLLBACK_STATE_FILE"
    touch "$SYMLINKS_CREATED_FILE"
    touch "$BACKUP_LOCATION_FILE"
}

# no-op if state not initialised
record_step() {
    local step="$1"
    [[ -d "$ROLLBACK_STATE_DIR" ]] || return 0
    echo "$step" >>"$ROLLBACK_STATE_FILE"
}

get_last_step() {
    if [[ -f "$ROLLBACK_STATE_FILE" ]]; then
        tail -n1 "$ROLLBACK_STATE_FILE" 2>/dev/null || echo ""
    else
        echo ""
    fi
}

# no-op if state not initialised
record_backup_location() {
    local location="$1"
    [[ -d "$ROLLBACK_STATE_DIR" ]] || return 0
    echo "$location" >"$BACKUP_LOCATION_FILE"
}

get_backup_location() {
    if [[ -f "$BACKUP_LOCATION_FILE" ]]; then
        cat "$BACKUP_LOCATION_FILE"
    else
        echo ""
    fi
}

# no-op if state not initialised
record_symlink() {
    local link_path="$1"
    local target_path="$2"
    [[ -d "$ROLLBACK_STATE_DIR" ]] || return 0
    echo "${link_path}|${target_path}" >>"$SYMLINKS_CREATED_FILE"
}

get_created_symlinks() {
    if [[ -f "$SYMLINKS_CREATED_FILE" ]]; then
        cat "$SYMLINKS_CREATED_FILE"
    fi
}

has_rollback_state() {
    [[ -d "$ROLLBACK_STATE_DIR" ]] && [[ -f "$ROLLBACK_STATE_FILE" ]]
}

cleanup_rollback_state() {
    rm -rf "$ROLLBACK_STATE_DIR"
}

# restores a given backup directory without reading rollback state
restore_from_backup() {
    local backup_dir="$1"

    if [[ ! -d "$backup_dir" ]]; then
        error "Backup directory not found: $backup_dir"
        return 1
    fi

    info "Restoring from backup: $backup_dir"

    find "$backup_dir" -type f | while read -r backup_file; do
        local relative_path="${backup_file#"$backup_dir"/}"

        if [[ "$relative_path" == ../* ]] || [[ "$relative_path" == */../* ]] || [[ "$relative_path" == */./* ]]; then
            warn "Skipping suspicious path: $relative_path"
            continue
        fi

        local original_path="$HOME/$relative_path"

        if [[ -L "$original_path" ]]; then
            rm -f "$original_path"
        fi

        local original_dir
        original_dir=$(dirname "$original_path")
        mkdir -p "$original_dir"

        cp -p "$backup_file" "$original_path"
        success "Restored: $original_path"
    done

    success "Backup restored"
}

perform_rollback() {
    local backup_dir
    backup_dir=$(get_backup_location)

    info "Starting rollback..."

    info "Removing created symlinks..."
    while IFS='|' read -r link_path target_path; do
        if [[ -L "$link_path" ]]; then
            rm -f "$link_path"
            success "Removed: $link_path"
        fi
    done < <(get_created_symlinks)

    if [[ -n "$backup_dir" ]] && [[ -d "$backup_dir" ]]; then
        info "Restoring from backup: $backup_dir"

        find "$backup_dir" -type f | while read -r backup_file; do
            local relative_path="${backup_file#"$backup_dir"/}"

            if [[ "$relative_path" == ../* ]] || [[ "$relative_path" == */../* ]] || [[ "$relative_path" == */./* ]]; then
                warn "Skipping suspicious path: $relative_path"
                continue
            fi

            local original_path="$HOME/$relative_path"

            local resolved_dir
            resolved_dir=$(cd "$(dirname "$original_path")" 2>/dev/null && pwd) || {
                warn "Cannot resolve path: $original_path"
                continue
            }

            if [[ "$resolved_dir" != "$HOME"* ]]; then
                warn "Path resolves outside home directory: $original_path"
                continue
            fi

            local original_dir
            original_dir=$(dirname "$original_path")

            mkdir -p "$original_dir"

            cp -p "$backup_file" "$original_path"
            success "Restored: $original_path"
        done

        success "Backup restored from: $backup_dir"
    else
        warn "No backup found to restore"
    fi

    cleanup_rollback_state

    success "Rollback complete"
}
