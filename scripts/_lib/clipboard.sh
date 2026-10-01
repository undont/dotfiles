#!/usr/bin/env bash
# clipboard backend detection, shared by tmux scripts and theme-switch
# no common.sh dependency

[[ -n "${_DOTFILES_CLIPBOARD_SH_LOADED:-}" ]] && return 0
_DOTFILES_CLIPBOARD_SH_LOADED=1

# resolve the active clipboard backend. gates on the live display server, not
# binary presence alone: a wayland session usually has xclip installed too (via
# XWayland), and choosing it there writes to a clipboard nothing reads back.
# the zsh `clip` function mirrors this order; keep the two in sync
clipboard_backend() {
    if [[ "$(uname)" == "Darwin" ]]; then
        printf 'pb'
    elif [[ -n "${WAYLAND_DISPLAY:-}" ]] && command -v wl-copy &>/dev/null; then
        printf 'wayland'
    elif [[ -n "${DISPLAY:-}" ]] && command -v xclip &>/dev/null; then
        printf 'xclip'
    elif [[ -n "${DISPLAY:-}" ]] && command -v xsel &>/dev/null; then
        printf 'xsel'
    elif command -v clip.exe &>/dev/null; then
        printf 'wsl'
    elif command -v termux-clipboard-set &>/dev/null; then
        printf 'termux'
    elif [[ -n "${WAYLAND_DISPLAY:-}" || -n "${DISPLAY:-}" ]]; then
        # a display server is running but its tool is missing. kept apart
        # from `osc52` so callers can refuse instead of writing to the terminal
        printf 'missing'
    else
        printf 'osc52'
    fi
}

# clipboard copy command as a string, for embedding in fzf --bind and tmux
# copy-pipe. `missing` and `osc52` discard stdin: these call sites run detached
# from a tty, and tmux's `set-clipboard on` already emits OSC 52 for copy-pipe
clipboard_copy_cmd() {
    case "$(clipboard_backend)" in
        pb) printf 'pbcopy' ;;
        wayland) printf 'wl-copy' ;;
        xclip) printf 'xclip -selection clipboard' ;;
        xsel) printf 'xsel --clipboard --input' ;;
        wsl) printf 'clip.exe' ;;
        termux) printf 'termux-clipboard-set' ;;
        *) printf 'cat >/dev/null' ;;
    esac
}

# write stdin to the terminal clipboard via OSC 52. needs a writable tty;
# input over the terminal payload cap is refused, not truncated
clipboard_osc52() {
    local b64
    b64=$(base64 | tr -d '\r\n') || return 1

    if [[ ! -w /dev/tty ]]; then
        printf 'clipboard: no tty available for OSC 52\n' >&2
        return 1
    fi
    if ((${#b64} > 74994)); then
        printf 'clipboard: input too large for OSC 52 (%d encoded bytes)\n' "${#b64}" >&2
        return 1
    fi

    printf '\033]52;c;%s\a' "$b64" >/dev/tty
}

# copy stdin to the system clipboard, via OSC 52 when headless or over ssh
clipboard_copy() {
    case "$(clipboard_backend)" in
        pb) pbcopy ;;
        wayland) wl-copy ;;
        xclip) xclip -selection clipboard ;;
        xsel) xsel --clipboard --input ;;
        wsl) clip.exe ;;
        termux) termux-clipboard-set ;;
        osc52) clipboard_osc52 ;;
        *)
            if [[ -n "${WAYLAND_DISPLAY:-}" ]]; then
                printf 'clipboard: no tool for this wayland session; install wl-clipboard\n' >&2
            else
                printf 'clipboard: no tool for this X11 session; install xclip or xsel\n' >&2
            fi
            return 1
            ;;
    esac
}
