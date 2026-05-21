#!/usr/bin/env bash
# Common utilities for installation scripts
# Source this file: source "${BASH_SOURCE%/*}/_lib/common.sh"

# Guard against multiple sourcing
[[ -n "${_DOTFILES_COMMON_SH_LOADED:-}" ]] && return 0
_DOTFILES_COMMON_SH_LOADED=1

# Resolve this file's directory once. BASH_SOURCE works when sourced from
# bash; zsh leaves it empty inside the sourced file, so fall back to zsh's
# `%x` prompt expansion. Lets ad-hoc `source scripts/_lib/common.sh` work
# from either shell instead of failing with "no such file: /colours.sh".
if [[ -n "${BASH_VERSION:-}" ]]; then
    _COMMON_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
elif [[ -n "${ZSH_VERSION:-}" ]]; then
    eval '_COMMON_LIB_DIR="${${(%):-%x}:A:h}"'
else
    echo "Error: scripts/_lib/common.sh requires bash or zsh" >&2
    return 1
fi

# Source colour definitions
# shellcheck source=scripts/_lib/colours.sh
source "$_COMMON_LIB_DIR/colours.sh"

# Print error message to stderr
error() {
    printf "${RED}Error:${NC} %s\n" "$1" >&2
}

# Print warning message to stderr
warn() {
    printf "${YELLOW}Warning:${NC} %s\n" "$1" >&2
}

# Print info message
info() {
    printf "${CYAN}%s${NC}\n" "$1"
}

# Print success message
success() {
    printf "${GREEN}%s${NC}\n" "$1"
}

# Print step header with box style
print_header() {
    local title="$1"
    echo ""
    echo "${CYAN}╔════════════════════════════════════════════╗${NC}"
    printf "${CYAN}║%*s%s%*s║${NC}\n" $(( (44 - ${#title}) / 2 )) "" "$title" $(( (45 - ${#title}) / 2 )) ""
    echo "${CYAN}╚════════════════════════════════════════════╝${NC}"
    echo ""
}

# Print section header
print_section() {
    local title="$1"
    echo "============================================"
    echo "$title"
    echo "============================================"
    echo ""
}

# Print step with number
print_step() {
    local step_num="$1"
    local description="$2"
    echo "${CYAN}Step $step_num: $description${NC}"
    echo ""
}

# Print skipped step
print_skip() {
    local step_num="$1"
    local description="$2"
    local reason="$3"
    echo "${YELLOW}Step $step_num: Skipping $description ($reason)${NC}"
    echo ""
}

# Check if a command exists
command_exists() {
    command -v "$1" &>/dev/null
}

# Install a package via the system package manager (Linux only).
# Usage: install_system_package "pkg-name" [fatal]
#   fatal = exit 1 on failure (default: warn and return 1)
install_system_package() {
    local pkg="$1"
    local on_failure="${2:-warn}"

    if command_exists pacman; then
        sudo pacman -S --noconfirm "$pkg" 2>/dev/null && return 0
    elif command_exists apt-get; then
        sudo apt-get install -y "$pkg" 2>/dev/null && return 0
    elif command_exists dnf; then
        sudo dnf install -y "$pkg" 2>/dev/null && return 0
    elif command_exists yum; then
        sudo yum install -y "$pkg" 2>/dev/null && return 0
    fi

    # If we get here, either no package manager was found or install failed
    if [[ "$on_failure" == "fatal" ]]; then
        error "Failed to install '$pkg'. Install manually via your system package manager."
        exit 1
    else
        warn "Failed to install '$pkg'. Install manually via your system package manager."
        return 1
    fi
}

# Check for a command and print status
check_command() {
    local name="$1"
    local cmd="$2"
    local install_hint="${3:-}"
    local is_optional="${4:-false}"

    if [[ "$is_optional" == "true" ]]; then
        printf "Checking %-20s" "$name (optional)..."
    else
        printf "Checking %-20s" "$name..."
    fi

    if command_exists "$cmd"; then
        printf '%s%s%s\n' "$GREEN" "OK" "$NC"
        return 0
    else
        if [[ "$is_optional" == "true" ]]; then
            printf '%s%s%s\n' "$YELLOW" "MISSING" "$NC"
        else
            printf '%s%s%s\n' "$RED" "MISSING" "$NC"
        fi
        if [[ -n "$install_hint" ]]; then
            printf "  ${YELLOW}Install with:${NC} %s\n" "$install_hint"
        fi
        return 1
    fi
}

# Check if running on macOS
is_macos() {
    [[ "$(uname)" == "Darwin" ]]
}

# Check if running on Linux
is_linux() {
    [[ "$(uname)" == "Linux" ]]
}

# Portable in-place sed (macOS BSD sed vs GNU sed)
# Writes to a temp file first to prevent corruption on sed errors.
# Usage: sed_inplace 'sed-expression' file
sed_inplace() {
    local args=("$@")
    local file="${args[-1]}"
    local sed_args=("${args[@]:0:${#args[@]}-1}")
    local tmp
    tmp=$(mktemp "${file}.XXXXXX") || return 1
    if sed "${sed_args[@]}" "$file" > "$tmp"; then
        mv "$tmp" "$file"
    else
        rm -f "$tmp"
        return 1
    fi
}

# Check if running on Apple Silicon
is_apple_silicon() {
    [[ "$(uname -m)" == "arm64" ]]
}

# Get Homebrew prefix based on platform and architecture
get_homebrew_prefix() {
    if is_macos; then
        if is_apple_silicon; then
            echo "/opt/homebrew"
        else
            echo "/usr/local"
        fi
    else
        echo "/home/linuxbrew/.linuxbrew"
    fi
}

# Read with timeout (prevents hanging on interactive prompts)
# Usage: read_with_timeout "prompt" variable_name timeout_seconds
# Note: The variable_name is used via nameref for dynamic assignment
read_with_timeout() {
    local prompt="$1"
    local -n _result_var="$2"
    local timeout="${3:-300}"

    if read -r -t "$timeout" -p "$prompt" _result_var; then
        return 0
    else
        echo ""
        warn "Input timed out after ${timeout}s"
        return 1
    fi
}

# Confirm action (y/n prompt)
confirm() {
    local prompt="${1:-Continue?}"
    local response
    read -r -p "$prompt [y/N] " response
    [[ "$response" =~ ^[Yy]$ ]]
}

# Update or add an export line in ~/.zshrc
# Usage: update_zshrc_export "VAR_NAME" "value"
# - Replaces existing `export VAR_NAME=...` line
# - If not found, appends after the "YOUR PERSONAL CONFIGURATION" section marker
# - Also auto-updates PROJECT_DIRS when DEV_ROOT or PROJECTS_ROOT is changed
update_zshrc_export() {
    local var_name="$1"
    local value="$2"
    local zshrc="$HOME/.zshrc"

    if [[ ! -f "$zshrc" ]]; then
        error "$HOME/.zshrc not found"
        return 1
    fi

    # Validate variable name — only allow standard shell variable names
    if [[ ! "$var_name" =~ ^[A-Z_][A-Z0-9_]*$ ]]; then
        error "Invalid variable name: $var_name"
        return 1
    fi

    # Validate value doesn't contain newlines (would break sed append)
    if [[ "$value" == *$'\n'* ]]; then
        error "Value for $var_name contains newlines"
        return 1
    fi

    # Escape sed-special characters in value (& | \ /)
    local escaped_value
    escaped_value=$(printf '%s' "$value" | sed 's/[&|\\\/]/\\&/g')

    # Check if the export line already exists
    if grep -q "^export ${var_name}=" "$zshrc"; then
        # Replace existing line
        sed_inplace "s|^export ${var_name}=.*|export ${var_name}=\"${escaped_value}\"|" "$zshrc"
    else
        # Append after the "YOUR PERSONAL CONFIGURATION" section marker
        local marker="YOUR PERSONAL CONFIGURATION"
        if grep -q "$marker" "$zshrc"; then
            # Find the marker line and append after the comment block
            local line_num
            line_num=$(grep -n "$marker" "$zshrc" | head -1 | cut -d: -f1)
            # Skip past the comment block (lines starting with #) after the marker
            local total_lines
            total_lines=$(wc -l < "$zshrc" | tr -d ' ')
            local insert_after=$line_num
            for ((i = line_num + 1; i <= total_lines; i++)); do
                local line
                line=$(sed -n "${i}p" "$zshrc")
                if [[ "$line" =~ ^#.*$ ]] || [[ -z "$line" ]]; then
                    insert_after=$i
                else
                    break
                fi
            done
            sed_inplace "${insert_after}a\\
export ${var_name}=\"${value}\"
" "$zshrc"
        else
            # No marker found — append to end
            printf '\nexport %s="%s"\n' "$var_name" "$value" >> "$zshrc"
        fi
    fi

    # Auto-update PROJECT_DIRS when DEV_ROOT or PROJECTS_ROOT changes — but
    # preserve a customised line that already references both vars (e.g. a
    # user appended a third root: `$DEV_ROOT:$PROJECTS_ROOT:$HOME/work`).
    if [[ "$var_name" == "DEV_ROOT" || "$var_name" == "PROJECTS_ROOT" ]]; then
        # shellcheck disable=SC2016
        local project_dirs_line='export PROJECT_DIRS="$DEV_ROOT:$PROJECTS_ROOT"'
        local existing
        existing=$(grep -m1 '^export PROJECT_DIRS=' "$zshrc" || true)
        if [[ -n "$existing" ]]; then
            # Rewrite only if the existing line is missing one of the refs —
            # otherwise the user's customisation already picks up the change.
            if ! { [[ "$existing" == *'$DEV_ROOT'* || "$existing" == *'${DEV_ROOT}'* ]] \
                && [[ "$existing" == *'$PROJECTS_ROOT'* || "$existing" == *'${PROJECTS_ROOT}'* ]]; }; then
                sed_inplace "s|^export PROJECT_DIRS=.*|${project_dirs_line}|" "$zshrc"
            fi
        else
            # Add PROJECT_DIRS after the last of DEV_ROOT/PROJECTS_ROOT
            local last_root_line
            last_root_line=$(grep -n '^export \(DEV_ROOT\|PROJECTS_ROOT\)=' "$zshrc" | tail -1 | cut -d: -f1)
            if [[ -n "$last_root_line" ]]; then
                sed_inplace "${last_root_line}a\\
${project_dirs_line}
" "$zshrc"
            fi
        fi
    fi
}

# Get the script directory (for relative sourcing)
get_script_dir() {
    cd "$(dirname "${BASH_SOURCE[1]}")" && pwd
}

# Source the library from script location
# Usage: source "$(get_lib_path)/common.sh"
get_lib_path() {
    echo "$(get_script_dir)/_lib"
}

# Check if a component should be installed based on preset hierarchy
# Usage: should_install "core" returns true if preset is core or full
# Requires PRESET variable to be set (defaults to "full")
should_install() {
    local required_preset="$1"
    local current_preset="${PRESET:-full}"

    case "$required_preset" in
        minimal)
            return 0  # Always include minimal
            ;;
        core)
            [[ "$current_preset" == "core" || "$current_preset" == "full" ]]
            ;;
        full)
            [[ "$current_preset" == "full" ]]
            ;;
        *)
            error "Unknown preset: $required_preset"
            return 1
            ;;
    esac
}

# Display ASCII logo from logo.txt with theme-aware gradient
# Uses active theme colours when available, red gradient as default
# Usage: print_logo
print_logo() {
    local logo_file="$_COMMON_LIB_DIR/logo.txt"

    if [[ -f "$logo_file" ]]; then
        echo ""

        # Respect NO_COLOR convention (https://no-color.org)
        if [[ -n "${NO_COLOR:-}" ]]; then
            cat "$logo_file"
            echo ""
            return
        fi

        # Load theme colours if a theme is active (skip on first install)
        if [[ -z "${TMUX_ACCENT_CYAN:-}" ]]; then
            local fzf_theme="$_COMMON_LIB_DIR/../fzf-theme.sh"
            local config_dir="${XDG_CONFIG_HOME:-$HOME/.config}/dotfiles"
            if [[ -f "$config_dir/current-theme" && -f "$fzf_theme" ]]; then
                # shellcheck disable=SC1090
                source "$fzf_theme"
            fi
        fi

        # Theme-aware: use accent colours if available, sage → forest gradient as default
        local from="${TMUX_ACCENT_CYAN:-#8baf9e}"
        local to="${TMUX_ACCENT_PURPLE:-#38604a}"

        # Use truecolor gradient when terminal supports it, otherwise basic ANSI
        if [[ "${COLORTERM:-}" == "truecolor" || "${COLORTERM:-}" == "24bit" ]]; then
            local r1=$((16#${from:1:2})) g1=$((16#${from:3:2})) b1=$((16#${from:5:2}))
            local r2=$((16#${to:1:2})) g2=$((16#${to:3:2})) b2=$((16#${to:5:2}))

            local i=0
            while IFS= read -r line || [[ -n "$line" ]]; do
                local r=$(( r1 + (r2 - r1) * i / 4 ))
                local g=$(( g1 + (g2 - g1) * i / 4 ))
                local b=$(( b1 + (b2 - b1) * i / 4 ))
                printf "\033[38;2;%d;%d;%dm%s${NC}\n" "$r" "$g" "$b" "$line"
                i=$((i + 1))
            done < "$logo_file"
        else
            # Fallback: basic ANSI green
            while IFS= read -r line || [[ -n "$line" ]]; do
                printf "${GREEN}%s${NC}\n" "$line"
            done < "$logo_file"
        fi
        echo ""
    fi
}
