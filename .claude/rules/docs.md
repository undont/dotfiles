# Documentation Updates

After completing any code change, check whether relevant documentation needs updating. This is a final step -- do it after the implementation is done, not during.

**Key documentation locations:**
- `README.md` -- feature summaries, handy aliases list
- `zsh/README.md` -- aliases & functions tables, tab completion table
- `scripts/dotfiles` -- the `cmd_aliases()` function powering `dot aliases`
- `CLAUDE.md` -- architecture, conventions, common commands
- Component READMEs (`tmux/README.md`, `nvim/README.md`, etc.) -- component-specific docs

**What to check:**
- New aliases/functions -> update `scripts/dotfiles` (`cmd_aliases`), `zsh/README.md`, and `README.md`
- New tmux keybindings/scripts -> update `tmux/README.md`
- New nvim plugins/keymaps -> update `nvim/README.md`
- New install behaviour/presets -> update `CLAUDE.md` and `README.md`
- New test files -> confirm they're discovered by `scripts/run-tests.sh` (auto-discovery)
