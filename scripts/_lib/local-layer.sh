#!/usr/bin/env bash
# the user-owned local layer (scripts/manifest.conf rows with a local key) and
# private-repo helpers for export/import. source after common.sh and cli.sh

[[ -n "${_DOTFILES_LOCAL_LAYER_SH_LOADED:-}" ]] && return 0
_DOTFILES_LOCAL_LAYER_SH_LOADED=1

[[ -z "${_DOTFILES_COMMON_SH_LOADED:-}" ]] && {
    echo "local-layer.sh requires common.sh to be sourced first" >&2
    return 1
}
[[ -z "${_DOTFILES_CLI_SH_LOADED:-}" ]] && {
    echo "local-layer.sh requires cli.sh to be sourced first" >&2
    return 1
}

: "${DOTFILES_DIR:?DOTFILES_DIR must be set before sourcing local-layer.sh}"

# shellcheck source=/dev/null
source "$DOTFILES_DIR/scripts/_lib/manifest.sh"

# build LOCAL_PAIRS (files) and LOCAL_DIR_PAIRS (directories) as
# "repo-relative|system-absolute" strings from the manifest rows with a local
# key. secrets.zsh, .state/, the preset file and current-theme are never listed
_local_pairs() {
    # should_install reads $PRESET, which is unset when invoked via the CLI
    local PRESET="${PRESET:-$(get_preset)}"
    local dest local_key
    LOCAL_PAIRS=()
    LOCAL_DIR_PAIRS=()
    while IFS=$'\t' read -r _ _ _ dest local_key; do
        [[ "$local_key" == - ]] && continue
        if [[ "$dest" == */ ]]; then
            LOCAL_DIR_PAIRS+=("$local_key|${dest%/}")
        else
            LOCAL_PAIRS+=("$local_key|$dest")
        fi
    done < <(manifest_rows local copy sync)
}

# narrow LOCAL_PAIRS / LOCAL_DIR_PAIRS in place to entries matching the given
# selectors. a selector matches a file pair, or a whole dir pair, by the exact
# or suffix repo-relative path, the basename, or the system path; a single file
# inside a dir pair (dir + "/" + subpath) becomes a LOCAL_PAIRS entry, so the
# dir is neither mirrored nor pruned.
# returns 1 if any selector matches nothing. requires _local_pairs first
_local_select() {
    local -a fpairs=() dpairs=()
    local pair repo sys base sel rest matched
    for sel in "$@"; do
        sel="${sel#./}"
        sel="${sel%/}"
        matched=0
        for pair in "${LOCAL_PAIRS[@]}"; do
            repo="${pair%%|*}" sys="${pair#*|}" base="${repo##*/}"
            if [[ "$sel" == "$repo" || "$repo" == */"$sel" || "$sel" == "$base" ||
                "$sel" == "$sys" || "$sys" == */"$sel" ]]; then
                fpairs+=("$pair")
                matched=1
            fi
        done
        for pair in "${LOCAL_DIR_PAIRS[@]}"; do
            repo="${pair%%|*}" sys="${pair#*|}" base="${repo##*/}"
            if [[ "$sel" == "$repo" || "$repo" == */"$sel" || "$sel" == "$base" ||
                "$sel" == "$sys" || "$sys" == */"$sel" ]]; then
                dpairs+=("$pair")
                matched=1
            elif [[ "$sel" == "$repo/"* ]]; then
                rest="${sel#"$repo"/}"
                fpairs+=("$repo/$rest|$sys/$rest")
                matched=1
            elif [[ "$sel" == "$base/"* ]]; then
                rest="${sel#"$base"/}"
                fpairs+=("$repo/$rest|$sys/$rest")
                matched=1
            elif [[ "$sel" == "$sys/"* ]]; then
                rest="${sel#"$sys"/}"
                fpairs+=("$repo/$rest|$sys/$rest")
                matched=1
            fi
        done
        if [[ $matched -eq 0 ]]; then
            error "No local-layer entry matches: $sel"
            return 1
        fi
    done
    LOCAL_PAIRS=(${fpairs[@]+"${fpairs[@]}"})
    LOCAL_DIR_PAIRS=(${dpairs[@]+"${dpairs[@]}"})
}

# expand github "owner/repo" shorthand to a full https clone url; schemes,
# user@ forms, and existing local paths pass through untouched
_local_expand_url() {
    local url="$1"
    if [[ "$url" =~ ^[A-Za-z0-9][A-Za-z0-9-]*/[A-Za-z0-9._-]+$ && ! -e "$url" ]]; then
        printf 'https://github.com/%s.git' "${url%.git}"
    else
        printf '%s' "$url"
    fi
}

# validate and echo the configured local repo dir. errors to stderr:
# unconfigured (2), missing dir or not a git repo (1)
_local_dir_required() {
    local dir
    dir=$(get_local_dir)
    if [[ -z "$dir" ]]; then
        error "No local repo configured"
        printf "  Run: ${CYAN}dotfiles local init${NC} (new) or ${CYAN}dotfiles local clone <url>${NC} (existing)\n" >&2
        return 2
    fi
    if [[ ! -d "$dir" ]]; then
        error "Local repo path does not exist: $dir"
        printf "  Fix the pointer (%s) or run: ${CYAN}dotfiles local init${NC}\n" "$LOCAL_REPO_FILE" >&2
        return 1
    fi
    if ! git -C "$dir" rev-parse --git-dir &>/dev/null; then
        error "Not a git repository: $dir"
        return 1
    fi
    printf '%s' "$dir"
}

# seed .gitignore in the local repo if missing
_local_seed_gitignore() {
    local dir="$1"
    [[ -f "$dir/.gitignore" ]] && return 0
    printf '%s\n' ".DS_Store" "secrets.zsh" ".state/" "statusline-theme.sh" "config/dotfiles/current-theme" >"$dir/.gitignore"
}

_local_write_pointer() {
    local dir="$1"
    mkdir -p "$CONFIG_DIR"
    printf '%s\n' "$dir" >"$LOCAL_REPO_FILE"
}

# falls back to a generated identity when git has no user.email
_local_commit() {
    local dir="$1" msg="$2"
    if git -C "$dir" config user.email >/dev/null 2>&1; then
        git -C "$dir" commit -q -m "$msg"
    else
        git -C "$dir" -c user.name="${USER:-dotfiles}" \
            -c user.email="${USER:-dotfiles}@$(hostname -s)" commit -q -m "$msg"
    fi
}
