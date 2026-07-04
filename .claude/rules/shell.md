---
paths:
  - "**/*.sh"
  - "**/*.zsh"
  - "zsh/**"
  - "scripts/**"
  - "launchers/**"
---

# Shell Script Conventions

- Use `set -euo pipefail` at script start
- Source `scripts/_lib/common.sh` for shared utilities
- Use printf for coloured output (not echo)
- Conditional PATH additions: `[[ -n "$VAR" ]] && export PATH=$PATH:$VAR/bin`
- All scripts pass ShellCheck with standard exclusions (SC1091, SC2059, SC2015, SC2016, SC2034)

## SCRIPT_DIR Pattern

Use consistent patterns for setting `SCRIPT_DIR` across all shell scripts:

**Entry-point / standalone scripts** (`install.sh`, `scripts/dotfiles`, `scripts/theme-switch`, `scripts/generate-theme`):

```bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
```

These scripts need absolute paths because they export `DOTFILES_DIR`, resolve symlinks, or are invoked directly from arbitrary working directories.

**Module scripts** (tmux scripts, installer modules, launchers):

```bash
SCRIPT_DIR="${BASH_SOURCE%/*}"
```

These are invoked from known paths and source libraries via relative paths, so the simpler pattern is sufficient.

**Test scripts** (test-_.sh, test-_-libs.sh):

```bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
```

Full `cd` + `pwd` ensures absolute paths when tests are invoked from different directories.

**Rationale**:

- Entry-point scripts: Need absolute paths for `DOTFILES_DIR` export and symlink resolution
- Module scripts: Simpler `${BASH_SOURCE%/*}` is faster and sufficient for scripts invoked from standard paths
- Test scripts: Absolute paths needed when tests are invoked from different directories
- Resurrect scripts: Use test pattern for consistency (invoked in various contexts)

**Examples**:

- `install.sh` - Uses `$(cd "$(dirname ...)" && pwd)` (entry point, exports DOTFILES_DIR)
- `tmux/scripts/sessions/list.sh` - Uses `${BASH_SOURCE%/*}` (module script)
- `scripts/tests/test-brewfile.sh` - Uses `$(cd "$(dirname ...)" && pwd)` (test script)
- Don't mix patterns within the same category of scripts

## Shared Libraries

**`scripts/_lib/common.sh`**: Core utilities used by all installation scripts

- Colour definitions (RED, GREEN, YELLOW, CYAN, NC)
- Output functions (error, warn, info, success, print_header, print_step)
- Platform detection (is_macos, get_homebrew_prefix)
- Preset validation (should_install)
