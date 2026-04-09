# Documentation Updates

After completing any code change, check whether relevant documentation needs updating. This is a final step -- do it after the implementation is done, not during.

**Key documentation locations:**
- `README.md` -- feature summaries, keybindings, aliases
- `scripts/dotfiles` -- the `cmd_aliases()` function powering `dot aliases`
- `CLAUDE.md` -- architecture, conventions, common commands
- `docs/` -- detailed guides (theme system, agent hooks, troubleshooting, etc.)

**What to check:**
- New aliases/functions -> update `scripts/dotfiles` (`cmd_aliases`) and `README.md`
- New tmux/nvim keybindings -> update `README.md` keybindings section
- New install behaviour/presets -> update `CLAUDE.md` and `README.md`
- New test files -> confirm they're discovered by `scripts/run-tests.sh` (auto-discovery)
