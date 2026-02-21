---
description: Commit staged changes and create a PR, push on top if PR already exists.
---

# Commit and Push Changes

## Pre-Commit Validation

1. **Git Status Check**:
    - Run `git status` to see all modified and untracked files
    - Verify you are on the correct branch
    - Ensure working directory has changes to commit

2. **Quality Checks** (mirrors CI workflow):
    - **Lua files** (nvim/): Run `stylua --check nvim/` to verify formatting
      - If check fails, run `stylua nvim/` to auto-format
    - **ShellCheck** (if shell scripts changed):
      ```bash
      # Standard exclusions used by CI
      # Check installation scripts
      shellcheck -x -e SC1091 -e SC2059 -e SC2015 -e SC2016 -e SC2034 install.sh
      shellcheck -x -e SC1091 -e SC2059 -e SC2015 -e SC2016 -e SC2034 scripts/install/*.sh
      shellcheck -x -e SC1091 -e SC2059 -e SC2015 -e SC2016 -e SC2034 scripts/_lib/*.sh
      shellcheck -x -e SC1091 -e SC2059 -e SC2015 -e SC2016 -e SC2034 scripts/hooks/*.sh
      
      # Check tmux scripts
      shellcheck -x -e SC1091 -e SC2059 -e SC2015 -e SC2016 -e SC2034 tmux/.tmux/scripts/*.sh
      shellcheck -x -e SC1091 -e SC2059 -e SC2015 -e SC2016 -e SC2034 tmux/.tmux/scripts/_lib/*.sh
      
      # Check bin utilities (shell scripts only)
      for f in bin/*; do
        if file "$f" | grep -q "shell script"; then
          shellcheck -x -e SC1091 -e SC2059 -e SC2015 -e SC2016 -e SC2034 "$f"
        fi
      done
      ```
    - **Bash syntax check** (for any .sh files changed):
      ```bash
      bash -n <file.sh>
      ```
    - **Tmux script tests**: Run `tmux/.tmux/scripts/_lib/test.sh` to verify library functions
      - Tests gracefully skip tmux-dependent tests when not in tmux
    - **CRITICAL**: Do not proceed with commit if quality checks fail. Fix issues first.

3. **Change Review**:
    - Review `git diff` for all modified files
    - For dotfiles, pay special attention to:
      - `zsh/` - Shell configuration changes
      - `nvim/` - Neovim configuration and plugins
      - `tmux/` - Tmux configuration
      - `bin/` - Custom scripts
    - **CRITICAL**: Never commit files in `.gitignore` (secrets, plugin directories, generated files)

4. **Documentation Update** (MANDATORY):
    - **STOP**: You MUST complete this step before proceeding to commit
    - **Read the relevant documentation files** based on which directories have changes:

    | Directory with changes | Documentation files to read |
    |------------------------|----------------------------|
    | `tmux/` | `tmux/.tmux/README.md`, `tmux/.tmux/tmux-help.txt` |
    | `nvim/` | `nvim/README.md`, `nvim/lua/custom/nvim-help.txt` |
    | `zsh/` | `zsh/.zsh/README.md` |
    | `karabiner/` | `karabiner/README.md` |
    | `ghostty/` | `ghostty/README.md` |
    | `hammerspoon/` | `hammerspoon/README.md` |
    | `bin/` | `README.md` (custom scripts section) |
    | Root files | `README.md` |

    - **Compare changes against documentation content** - for each changed file, check if:
      - New keybindings or keyboard shortcuts were added/changed
      - New features, commands, or scripts were added
      - Installation steps or prerequisites changed
      - Directory structure or file locations changed
      - New custom scripts added to `bin/`
    - **If ANY documentation updates are needed**:
      - Update the README/help files BEFORE creating the commit
      - Stage the documentation changes along with the other changes
    - **If unsure**: Ask the user whether documentation updates are needed
    - **Do NOT skip this step** - documentation drift causes confusion

5. **CHANGELOG Update**:
    - Update `CHANGELOG.md` for user-facing changes
    - **When to update**: `fix:`, `add:`, `update:`, `breaking:` commits
    - **Skip for**: `refactor:`, `test:`, `docs:`, `chore:` commits
    - **Version Bumping**:
      - Bump the version number when adding changelog entries
      - Use semantic versioning: `MAJOR.MINOR.PATCH`
        - `PATCH`: Bug fixes, minor improvements (`fix:`)
        - `MINOR`: New features, enhancements (`add:`, `update:`)
        - `MAJOR`: Breaking changes (`breaking:`)
      - Change `## [Unreleased]` to `## [X.Y.Z] - YYYY-MM-DD` with today's date
      - Add a new empty `## [Unreleased]` section above the new version
    - **Format**: Add entry under the new version section:
      ```markdown
      ### Added
      - New feature or capability

      ### Changed
      - Changes to existing functionality

      ### Fixed
      - Bug fixes

      ### Removed
      - Removed features
      ```
    - Stage CHANGELOG.md with your other changes

## Commit Process

### Analyse Changes

- Run `git diff --staged` to review what will be committed
- Run `git diff` to see unstaged changes that may need to be included
- Identify the scope of changes (zsh, nvim, tmux, bin, or multiple)

### Generate Commit Message

**Commit Convention**: Use lowercase prefixes with colon:
- `add:` - New configuration, scripts, or features
- `update:` - Changes to existing configuration
- `fix:` - Bug fixes or corrections
- `refactor:` - Code restructuring without behaviour change
- `docs:` - Documentation only changes
- `chore:` - Maintenance tasks

**Format**:
```
<prefix>: <concise description>

<optional body with details>
```

**Examples**:
```
add: zsh aliases for docker management
update: nvim telescope keybindings for better ergonomics
fix: tmux session restore not preserving pane layout
refactor: split zsh config into modular files
```

**Rules**:
- Keep subject line under 72 characters
- Use imperative mood ("add feature" not "added feature")
- Do not include AI/Claude attribution in commit messages
- Reference specific tools/files when helpful

### Execute Commit and Push

1. **Branch Strategy** (CRITICAL):
    - **NEVER push directly to `main`** unless the commit is `docs:` only
    - If on `main`, create a feature branch first:
      ```bash
      git checkout -b <branch-name>
      ```
    - Branch naming: Use descriptive kebab-case (e.g., `update-nvim-lsp-config`, `add-fzf-aliases`)
    - **Exception**: `docs:` commits (documentation-only changes) may be pushed directly to `main`

2. Stage relevant files:
    ```bash
    git add <files>
    ```

3. Create commit:
    ```bash
    git commit -m "<prefix>: <description>"
    ```

4. Push to remote:
    ```bash
    git push -u origin <branch>
    ```
    **Note**: Version tags are created automatically by CI when merged to main. The `auto-tag` job reads the latest version from CHANGELOG.md and creates a `vX.Y.Z` tag if it doesn't already exist. No manual tagging needed.

## Pull Request Creation

### Branch Check

- Verify you are on a feature branch (not `main`)
- If you accidentally committed to `main`, move changes to a new branch before pushing

### Create Pull Request

```bash
gh pr create --title "<title>" --body "$(cat <<'EOF'
## Summary
<Brief description of changes>

## Changed Files
- List of modified configuration files

## Testing
- [ ] Sourced zsh config: `source ~/.zshrc`
- [ ] Tested tmux config: reloaded with prefix + r
- [ ] Tested nvim config: opened nvim, ran `:checkhealth`
EOF
)"
```

## Post-PR Actions

### Verification

- Confirm push succeeded
- If PR created, verify it appears on GitHub
- For direct pushes to main, verify changes are reflected

## Notes

### Project Structure
```
dotfiles/
├── zsh/              # Zsh shell configuration
├── tmux/             # Tmux terminal multiplexer
├── nvim/             # Neovim configuration (has .stylua.toml)
├── bin/              # Custom executable scripts
├── ghostty/          # Ghostty terminal configuration
├── hammerspoon/      # macOS automation
├── karabiner/        # Keyboard customisation
├── scripts/          # Installation and utility scripts
│   ├── install/      # Installer modules
│   ├── hooks/        # Tool hooks (e.g. Claude alerts)
│   └── _lib/         # Shared shell libraries
├── Brewfile          # Homebrew dependencies
└── README.md         # Installation and usage docs
```

### Quality Tools Available
- **stylua**: Lua formatter for nvim/ directory (config in `nvim/.stylua.toml`)
- **shellcheck**: Shell script linter (run by CI on all .sh files)
- **luacheck**: Lua linter for nvim/ (advisory in CI, run locally with `luacheck nvim/lua/`)

### CI Workflow
The following checks run on push/PR to main (see `.github/workflows/ci.yml`):
1. **ShellCheck** - Lints all shell scripts with standard exclusions
2. **Library Tests** - Runs tmux and installation library tests
3. **Syntax Check** - Validates bash and zsh syntax
4. **Lua Check** - Advisory luacheck on nvim config
5. **Auto Tag** - On push to main only: creates a git tag from CHANGELOG.md version if new

### Release Management
Tags are created automatically by the `auto-tag` CI job when changes are merged to main. The job extracts the latest version from CHANGELOG.md and creates a `vX.Y.Z` tag if it doesn't already exist. Do NOT create tags manually.

### Files to Never Commit
- `zsh/.zsh/.secrets.zsh` - Contains API keys
- `tmux/.tmux/plugins/` - Managed by TPM
- `tmux/.tmux/resurrect/` - Runtime session data
- `.luarc.json` - Generated by LSP (root level)
- `nvim/.luarc.json` - Generated by LSP
- `.claude/` - Claude Code local configuration (gitignored, changes stay local)
