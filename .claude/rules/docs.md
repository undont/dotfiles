# Documentation Updates

After completing any code change, check whether relevant documentation needs updating. This is a final step -- do it after the implementation is done, not during.

**Key documentation locations:**

- `README.md` -- feature summaries, keybindings, aliases
- `zsh/dotfiles.zsh` -- shell aliases/functions; `dotfiles aliases` parses this file
- `CLAUDE.md` -- architecture, conventions, common commands
- `docs/` -- detailed guides (theme system, agent hooks, troubleshooting, etc.)

**What to check:**

- New aliases -> add the `alias` line in `zsh/dotfiles.zsh` with a trailing
  `# description` comment; the `dotfiles aliases` cheatsheet picks it up
  automatically. Aliases without a description are silently skipped (curated).
- New functions for the cheatsheet -> add a `# @cheat: <description>` directive
  on the line directly above the function definition.
- Free-form rows (ZLE bindings, external tools, dotfiles CLI subcommands) ->
  add a `# @cheat: <name> | <description>` directive.
- New section -> add `# @section: <NAME>` before the relevant block.
- New tmux/nvim keybindings -> update `README.md` keybindings section
- New install behaviour/presets -> update `CLAUDE.md` and `README.md`
- New test files -> confirm they're discovered by `scripts/run-tests.sh` (auto-discovery)

## Style

- **No em-dashes (`—`) in `docs/` or `README.md`.** Use a colon for
  definition lists and headings (`- **Term**: description`), a semicolon or
  comma to join clauses in prose, or split into separate sentences. This scope
  is `docs/**` and `README.md` only -- leave `CHANGELOG.md`, `.claude/`, and
  code/comments as they are. If a doc shows literal CLI output that contains an
  em-dash, fix the source string so the transcript stays accurate.
