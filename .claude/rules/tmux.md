---
paths:
  - "tmux/**"
---

# Tmux Scripts Architecture

Scripts live under `tmux/scripts/` in functional subdirectories (`sessions/`,
`windows/`, `panes/`, `launchers/`, `instances/`, `alerts/`, `resurrect/`,
`themes/`, `utils/`, `tests/`), with shared libraries in `_lib/` (`common.sh`,
`paths.sh`, `session.sh`, `alerts.sh`, `process.sh`, `ui.sh`). `process.sh`
provides the graceful SIGTERM → wait → SIGKILL termination shared by the
`kill.sh` scripts across `sessions/`, `panes/`, `windows/`, and `instances/`.

## Template Conventions

**Navigation hint formatting** in `tmux/tmux.conf.template`:

- **Comments** use brackets: `# Navigation: j/k (↓/↑), g/G (top/bottom)`
- **Border labels** (fzf `--border-label`) omit brackets: `j/k ↓/↑ · g/G top/bottom · ...`
- Use arrow icons (`↓/↑`) instead of words for up/down direction
- Use `top/bottom` (not `first/last`) for `g/G` navigation

## Responsive Popup Pattern

Use `if-shell` with `#{client_width}` to show compact or full-width popups:

```
bind <key> if-shell '[ #{client_width} -ge 80 ]' \
  'display-popup -w 50 -h 10 -E "..."' \
  'display-popup -w 95% -h 14 -E "..."'
```

- **Wide (≥80 cols)**: Fixed compact size (e.g., 50 wide, 10 tall)
- **Narrow/mobile**: Percentage-based full width (95%), usually taller
- Include `source {{DOTFILES_ROOT}}/scripts/fzf-theme.sh` for theme colours
