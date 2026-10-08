#!/usr/bin/env bash
set -euo pipefail

# verifies the dotfiles installation for the current preset

if [[ "${1:-}" == "--help" ]] || [[ "${1:-}" == "-h" ]]; then
    cat <<'EOF'
health-check.sh - Dotfiles installation health check

USAGE:
    ./scripts/install/health-check.sh

DESCRIPTION:
    Checks the dotfiles installation for the active preset:
      • Symlinks point to the correct locations
      • Generated configs exist (tmux, ghostty, gh-dash, theme)
      • Plugin managers and TPM-managed plugins are installed
      • No stale packer install shadows lazy.nvim
      • Secrets file exists
      • Optional environment variables (informational)
      • Session launchers are in PATH
      • Alert system hooks are executable
      • Local override files and local layer sync (informational)
      • ~/.local/bin is in PATH and yq is installed
      • zsh completion directories pass compaudit

OPTIONS:
    -h, --help   Show this help message

EXAMPLES:
    # Run health check from dotfiles root
    ./scripts/install/health-check.sh

OUTPUT:
    Prints one status per check: OK in green, a problem in red or yellow
    (MISSING, WRONG TARGET, WARN, ...). Informational checks print in cyan
    and never fail.

    Exit code 0 if no check found a problem, 1 otherwise.

SEE ALSO:
    ./install.sh --check-only    Only run prerequisite and health checks
    ./scripts/install/rollback.sh  Restore backup if issues found
EOF
    exit 0
fi

SCRIPT_DIR="${BASH_SOURCE%/*}"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/../_lib/common.sh"

if [[ -z "${DOTFILES_DIR:-}" ]]; then
    DOTFILES_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
fi
export DOTFILES_DIR
# shellcheck source=/dev/null
source "$SCRIPT_DIR/../_lib/manifest.sh"

PRESET="${DOTFILES_PRESET:-full}"

ISSUES=0

check_symlink() {
    local link="$1"
    local target="$2"
    local name="$3"

    printf "Checking %-44s " "$name..."

    if [[ -L "$link" ]]; then
        local actual_target
        actual_target=$(readlink "$link")
        if [[ "$actual_target" == "$target" ]]; then
            printf '%sOK%s\n' "${GREEN}" "${NC}"
            return 0
        else
            printf '%sWRONG TARGET%s (points to %s)\n' "${YELLOW}" "${NC}" "$actual_target"
            ISSUES=1
            return 1
        fi
    elif [[ -e "$link" ]]; then
        printf '%sEXISTS BUT NOT SYMLINK%s\n' "${RED}" "${NC}"
        ISSUES=1
        return 1
    else
        printf '%sMISSING%s\n' "${RED}" "${NC}"
        ISSUES=1
        return 1
    fi
}

check_directory() {
    local dir="$1"
    local name="$2"

    printf "Checking %-44s " "$name..."

    if [[ -d "$dir" ]]; then
        printf '%sOK%s\n' "${GREEN}" "${NC}"
        return 0
    else
        printf '%sMISSING%s\n' "${RED}" "${NC}"
        ISSUES=1
        return 1
    fi
}

check_file() {
    local file="$1"
    local name="$2"

    printf "Checking %-44s " "$name..."

    if [[ -f "$file" ]]; then
        printf '%sOK%s\n' "${GREEN}" "${NC}"
        return 0
    else
        printf '%sMISSING%s\n' "${YELLOW}" "${NC}"
        ISSUES=1
        return 1
    fi
}

check_executable() {
    local file="$1"
    local name="$2"

    printf "Checking %-44s " "$name..."

    if [[ -x "$file" ]]; then
        printf '%sOK%s\n' "${GREEN}" "${NC}"
        return 0
    elif [[ -f "$file" ]]; then
        printf '%sNOT EXECUTABLE%s\n' "${YELLOW}" "${NC}"
        printf '  Run: chmod +x %s\n' "$file"
        ISSUES=1
        return 1
    else
        printf '%sMISSING%s\n' "${RED}" "${NC}"
        ISSUES=1
        return 1
    fi
}

# informational check, does not set ISSUES
check_local_override() {
    local file="$1"
    local name="$2"

    printf "Checking %-44s " "$name..."

    if [[ -f "$file" ]]; then
        printf '%sOK%s\n' "${GREEN}" "${NC}"
    else
        printf '%sNOT CREATED%s\n' "${CYAN}" "${NC}"
        printf '  Create from template with: dotfiles update\n'
    fi
    return 0
}

print_section "Dotfiles Health Check"
echo "Preset: $PRESET"
echo ""

echo "Symlinks:"
echo "---------"

# zsh (minimal)
printf "Checking %-44s " ".zshrc..."
if [[ -f "$HOME/.zshrc" ]]; then
    if grep -q "dotfiles.zsh" "$HOME/.zshrc" 2>/dev/null; then
        printf '%sOK%s\n' "${GREEN}" "${NC}"
    else
        printf '%sWARN%s\n' "${YELLOW}" "${NC}"
        echo "  ~/.zshrc exists but doesn't source dotfiles.zsh"
        ISSUES=1
    fi
else
    printf '%sMISSING%s\n' "${RED}" "${NC}"
    echo "  Run: cp ~/dotfiles/zsh/zshrc.template ~/.zshrc"
    ISSUES=1
fi
check_file "$HOME/.p10k.zsh" ".p10k.zsh"

while IFS=$'\t' read -r kind _ source dest _; do
    case "$kind" in
        link | link-generated) check_symlink "$dest" "$source" "${dest/#"$HOME"/\~}" ;;
        copy) check_file "$dest" "${dest/#"$HOME"/\~} (copy-on-install)" ;;
    esac
done < <(manifest_rows link link-generated copy)

# config is generated to the XDG location, which ghostty reads on all platforms
if should_install "core"; then
    check_file "${XDG_CONFIG_HOME:-$HOME/.config}/ghostty/config" "ghostty config (XDG)"
fi

echo ""
echo "Generated Configs:"
echo "------------------"

# tmux generated config (minimal): the file that .tmux.conf symlinks to
check_file "${XDG_CONFIG_HOME:-$HOME/.config}/tmux/tmux.conf" "tmux config (generated)"

# current theme (minimal)
printf "Checking %-44s " "current theme..."
THEME_FILE="${XDG_CONFIG_HOME:-$HOME/.config}/dotfiles/current-theme"
if [[ -f "$THEME_FILE" ]]; then
    printf '%sOK%s (%s)\n' "${GREEN}" "${NC}" "$(cat "$THEME_FILE")"
else
    printf '%sMISSING%s\n' "${YELLOW}" "${NC}"
    printf '  Run: dotfiles theme switch <theme-name>\n'
    ISSUES=1
fi

# gh-dash generated config (core)
if should_install "core"; then
    check_file "$HOME/.config/gh-dash/config.yml" "gh-dash config (generated)"
fi

echo ""
echo "Plugin Managers:"
echo "----------------"
check_directory "$HOME/.tmux/plugins/tpm" "TPM (Tmux Plugin Manager)"

# key TPM-managed plugins (installed via prefix + I inside tmux)
printf "Checking %-44s " "tmux plugins (via TPM)..."
MISSING_PLUGINS=()
for plugin in tmux-resurrect tmux-continuum tmux-yank tmux-fingers; do
    if [[ ! -d "$HOME/.tmux/plugins/$plugin" ]]; then
        MISSING_PLUGINS+=("$plugin")
    fi
done
if [[ ${#MISSING_PLUGINS[@]} -eq 0 ]]; then
    printf '%sOK%s\n' "${GREEN}" "${NC}"
else
    printf '%sWARN%s\n' "${YELLOW}" "${NC}"
    printf '  Missing: %s\n' "${MISSING_PLUGINS[*]}"
    printf '  Install with: prefix + I (inside tmux)\n'
    ISSUES=1
fi

if should_install "core"; then
    check_directory "$HOME/.local/share/nvim/lazy" "lazy.nvim (Neovim)"

    # a packer install shadows lazy.nvim plugins in the runtimepath
    PACKER_DIR="$HOME/.local/share/nvim/site/pack/packer"
    printf "Checking %-44s " "no stale packer install..."
    if [[ -d "$PACKER_DIR" ]]; then
        printf '%sWARN%s\n' "${YELLOW}" "${NC}"
        printf '  Stale packer plugins at %s\n' "$PACKER_DIR"
        printf '  These shadow lazy.nvim plugins and can break Neovim.\n'
        printf '  Remove with: rm -rf %s\n' "$PACKER_DIR"
        ISSUES=1
    else
        printf '%sOK%s\n' "${GREEN}" "${NC}"
    fi
fi

echo ""
echo "Secrets:"
echo "--------"
ZSH_CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/zsh"
check_file "$ZSH_CONFIG_DIR/secrets.zsh" "Secrets file"

# environment variables used by plugins (core), informational only
if should_install "core"; then
    echo ""
    echo "Environment Variables:"
    echo "----------------------"

    # informational check, does not set ISSUES (copilot is the default adapter)
    check_env_var() {
        local var="$1"
        local desc="$2"

        printf "Checking %-44s " "$var..."

        if [[ -n "${!var:-}" ]]; then
            printf '%sOK%s\n' "${GREEN}" "${NC}"
        else
            printf '%sNOT SET%s\n' "${CYAN}" "${NC}"
            printf '  %s\n' "$desc"
        fi
        return 0
    }

    check_env_var "ANTHROPIC_API_KEY" "Optional: enables anthropic adapter in codecompanion.nvim"
fi

# session launchers (core)
if should_install "core"; then
    echo ""
    echo "Session Launchers:"
    echo "------------------"
    if command_exists dev; then
        printf "Checking %-44s ${GREEN}OK${NC}\n" "dev command"
    else
        printf "Checking %-44s ${YELLOW}NOT IN PATH${NC}\n" "dev command"
        echo "  Add ~/.local/launchers to your PATH"
    fi

fi

echo ""
echo "Alerts System:"
echo "--------------"

check_executable "$DOTFILES_DIR/scripts/hooks/agent-alert.sh" "agent-alert hook"
check_executable "$DOTFILES_DIR/scripts/hooks/agent-alert-clear.sh" "agent-alert-clear hook"
check_executable "$DOTFILES_DIR/scripts/hooks/cmd-alert.sh" "cmd-alert hook"

# wrapper scripts (used by Claude Code and OpenCode hook configs)
check_executable "$DOTFILES_DIR/scripts/hooks/wrappers/claude-alert.sh" "claude alert wrapper"
check_executable "$DOTFILES_DIR/scripts/hooks/wrappers/claude-alert-clear.sh" "claude alert-clear wrapper"
check_executable "$DOTFILES_DIR/scripts/hooks/wrappers/opencode-alert.sh" "opencode alert wrapper"
check_executable "$DOTFILES_DIR/scripts/hooks/wrappers/opencode-alert-clear.sh" "opencode alert-clear wrapper"

echo ""
echo "Local Overrides:"
echo "----------------"

# informational only
while IFS=$'\t' read -r _ _ _ dest _; do
    # ~/.zshrc is checked with the symlinks
    [[ "$dest" == "$HOME/.zshrc" ]] && continue
    check_local_override "$dest" "${dest/#"$HOME"/\~}"
done < <(manifest_rows local)

# local layer sync is optional: a broken pointer warns without setting ISSUES
printf "Checking %-44s " "local layer sync..."
local_layer_dir="${DOTFILES_LOCAL_DIR:-}"
local_ptr="${XDG_CONFIG_HOME:-$HOME/.config}/dotfiles/local-repo"
if [[ -z "$local_layer_dir" && -f "$local_ptr" ]]; then
    local_layer_dir=$(head -1 "$local_ptr")
fi
if [[ -z "$local_layer_dir" ]]; then
    printf '%sNOT CONFIGURED%s\n' "${CYAN}" "${NC}"
    printf '  Optional: sync personal config with: dotfiles local init | clone <url>\n'
elif git -C "$local_layer_dir" rev-parse --git-dir &>/dev/null; then
    printf '%sOK%s (%s)\n' "${GREEN}" "${NC}" "$local_layer_dir"
else
    printf '%sWARN%s\n' "${YELLOW}" "${NC}"
    echo "  Configured repo missing or not a git repository: $local_layer_dir"
    echo "  Fix with: dotfiles local init (or remove $local_ptr)"
fi

echo ""
echo "Tools & PATH:"
echo "-------------"

# ~/.local/bin in PATH (required for dotfiles CLI, dash-repo-sync)
# shellcheck disable=SC2088
printf "Checking %-44s " "~/.local/bin in PATH..."
if [[ ":$PATH:" == *":$HOME/.local/bin:"* ]]; then
    printf '%sOK%s\n' "${GREEN}" "${NC}"
else
    printf '%sNOT IN PATH%s\n' "${YELLOW}" "${NC}"
    printf '  dotfiles CLI requires ~/.local/bin in PATH\n'
    ISSUES=1
fi

# yq (required for gh-dash local merge)
if should_install "core"; then
    printf "Checking %-44s " "yq (gh-dash merge)..."
    if command_exists yq; then
        printf '%sOK%s\n' "${GREEN}" "${NC}"
    else
        printf '%sNOT FOUND%s\n' "${YELLOW}" "${NC}"
        printf '  gh-dash local overrides will not apply without yq\n'
        printf '  Install with: brew install yq\n'
        ISSUES=1
    fi
fi

# compinit prompts on its full run when compaudit reports insecure dirs
printf "Checking %-44s " "compinit dir permissions..."
if ! command_exists zsh; then
    printf '%sSKIPPED%s (zsh not found)\n' "${YELLOW}" "${NC}"
elif [[ -z "$(zsh -fc 'autoload -Uz compaudit; compaudit' 2>/dev/null)" ]]; then
    printf '%sOK%s\n' "${GREEN}" "${NC}"
else
    printf '%sINSECURE DIRS%s\n' "${YELLOW}" "${NC}"
    printf '  compinit prompts on its next full run (zsh/dotfiles.zsh runs one daily)\n'
    printf '  Fix with: %s/scripts/fix-compinit-insecure-dirs.sh\n' "$DOTFILES_DIR"
    ISSUES=1
fi

echo ""

if [[ $ISSUES -eq 0 ]]; then
    success "All checks passed! Your dotfiles are correctly installed."
    exit 0
else
    warn "Some issues were found. See above for details."
    exit 1
fi
