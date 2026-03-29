---
paths:
  - "tmux/**"
---

# Tmux Scripts Architecture

Scripts are organised into functional subdirectories under `tmux/scripts/`:
- **sessions/**: `list.sh`, `new.sh`, `rename.sh`, `kill.sh`, `undo.sh` - Session management with fzf integration
- **windows/**: `list.sh`, `rename.sh`, `kill.sh`, `undo.sh`, `duplicate.sh`, `move.sh` - Window operations
- **panes/**: `kill.sh`, `undo.sh` - Pane management
- **launchers/**: `list.sh`, `picker.sh`, `run.sh`, `prompt.sh`, `new.sh`, `new-dir.sh`, `settings.sh`, `duplicate.sh`, `delete.sh` - Session launcher system
- **instances/**: `claude.sh`, `opencode.sh`, `nvim.sh`, `new.sh`, `kill.sh`, `connect-nvim.sh` - Process instance management (list, create, kill)
- **alerts/**: `show.sh`, `clear.sh`, `cleanup.sh`, `update-timestamp.sh` - Agent alert system for status bar
- **resurrect/**: `split.sh`, `restore.sh`, `delete.sh` - Per-session tmux-resurrect extensions
- **themes/**: `pick.sh`, `reload-fzf.sh`, `reload-ghostty.sh` - Runtime theme switching
- **utils/**: `undo-dispatch.sh`, `pick-url.sh`, `dotfiles-status.sh`, `nav.sh` - Shared utilities
- **_lib/**: `common.sh`, `paths.sh`, `session.sh`, `alerts.sh`, `ui.sh` - Shared libraries
- **tests/**: `test-*.sh` - Test suites

## Tmux Libraries

**`tmux/scripts/_lib/`**: Tmux-specific utilities
- `common.sh`: Error handling, tmux validation
- `paths.sh`: XDG-compliant undo file paths with legacy fallback
- `session.sh`: Session management functions
- `alerts.sh`: Multi-agent alert system (Claude, OpenCode)
- `ui.sh`: Terminal dialogs and prompts

## Template Conventions

**Navigation hint formatting** in `tmux/tmux.conf.template`:
- **Comments** use brackets: `# Navigation: j/k (↓/↑), g/G (top/bottom)`
- **Border labels** (fzf `--border-label`) omit brackets: `j/k ↓/↑ · g/G top/bottom · ...`
- Use arrow icons (`↓/↑`) instead of words for up/down direction
- Use `top/bottom` (not `first/last`) for `g/G` navigation
