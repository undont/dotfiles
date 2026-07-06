# Agent Alert Hooks

This dotfiles repo includes a hook system that triggers tmux status bar alerts when AI coding agents (Claude Code, Codex CLI, OpenCode, GitHub Copilot CLI) need your attention. When an agent stops and waits for input, a bell rings and an icon appears in the tmux status bar showing which session needs you.

## How It Works

```
Agent stops working
  → Hook wrapper fires (e.g. claude-alert.sh)
    → agent-alert.sh sets a tmux window option + writes to ~/.config/tmux-alerts/alerts
      → tmux status bar reads alerts file and displays icons

User sends a message
  → Clear wrapper fires (e.g. claude-alert-clear.sh)
    → agent-alert-clear.sh removes the entry from ~/.config/tmux-alerts/alerts
      → tmux status bar clears
```

Each agent has a dedicated icon and colour in the status bar:

| Agent    | Icon | Colour |
| -------- | ---- | ------ |
| Claude   | ⚡   | Yellow |
| Codex    | ⌘    | Cyan   |
| OpenCode |     | Purple |
| Copilot  |     | Blue   |

## File Layout

```
scripts/hooks/
├── agent-alert.sh           # Core: set alert for any agent
├── agent-alert-clear.sh     # Core: clear alert for current window
├── agent-state.sh           # Core: record per-pane agent state (see below)
├── cmd-alert.sh             # Core: set exit code alert for a command
├── cmd-alert-hook.zsh       # zsh preexec/precmd hooks (sourced by dotfiles.zsh)
├── nvim-buffer-sync.sh      # Sync edited files to paired nvim
└── wrappers/
    ├── claude-alert.sh      # Calls agent-alert.sh claude
    ├── claude-alert-clear.sh
    ├── claude-state.sh      # Calls agent-state.sh claude
    ├── codex-alert.sh       # Calls agent-alert.sh codex
    ├── codex-alert-clear.sh
    ├── opencode-alert.sh    # Calls agent-alert.sh opencode
    ├── opencode-alert-clear.sh
    ├── copilot-alert.sh     # Calls agent-alert.sh copilot
    └── copilot-alert-clear.sh
```

The wrappers are thin scripts that pass the agent name to the shared core scripts. Adding a new agent is as simple as creating a new pair of wrappers.

## Setup by Agent

### Claude Code

Claude Code uses a `settings.json` hooks configuration. The relevant file is `~/.claude/settings.json` (or wherever your Claude Code settings live).

Add the following to your `settings.json`:

```json
{
  "hooks": {
    "Stop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "~/dotfiles/scripts/hooks/wrappers/claude-alert.sh"
          }
        ]
      }
    ],
    "PermissionRequest": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "~/dotfiles/scripts/hooks/wrappers/claude-alert.sh"
          }
        ]
      }
    ],
    "PostToolUse": [
      {
        "matcher": "AskUserQuestion",
        "hooks": [
          {
            "type": "command",
            "command": "~/dotfiles/scripts/hooks/wrappers/claude-alert.sh"
          }
        ]
      }
    ],
    "UserPromptSubmit": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "~/dotfiles/scripts/hooks/wrappers/claude-alert-clear.sh"
          }
        ]
      }
    ]
  }
}
```

**Hook events explained:**

- **Stop**: Agent finished its turn and is waiting for your next message
- **PermissionRequest**: Agent needs approval to run a tool (e.g. file edit, bash command)
- **PostToolUse** (`AskUserQuestion`): Agent asked you a question via the AskUserQuestion tool
- **UserPromptSubmit**: You sent a message, so clear the alert

#### Optional: Nvim Buffer Sync (Beta feature)

If you pair Claude Code with a running Neovim instance (via the `nvim-pair` function), you can add a hook that automatically loads edited files into Neovim's buffer list:

```json
{
  "hooks": {
    "PermissionRequest": [
      {
        "matcher": "Edit|Write",
        "hooks": [
          {
            "type": "command",
            "command": "~/dotfiles/scripts/hooks/nvim-buffer-sync.sh"
          }
        ]
      }
    ]
  }
}
```

This reads the `NVIM_SOCKET` environment variable (set by `nvim-pair`) and calls `nvim --server` to add the file to the buffer list.

### OpenCode

OpenCode uses the [`opencode-tmux-alert`](https://github.com/undont/opencode-tmux-alert) plugin. The plugin triggers alerts on session idle, permission requests, tool pending, and prompt appends, and clears when the user sends a message.

**1. Install the plugin:**

```bash
cd ~/.config/opencode  # or wherever your opencode.json lives
bun install opencode-tmux-alert
```

**2. Register the plugin** in `opencode.json`:

```json
{
  "plugin": ["opencode-tmux-alert"]
}
```

**3. Set environment variables** so the plugin uses the dotfiles hook scripts (already set in `dotfiles.zsh`):

```bash
export OPENCODE_ALERT_SCRIPT="$HOME/dotfiles/scripts/hooks/wrappers/opencode-alert.sh"
export OPENCODE_CLEAR_SCRIPT="$HOME/dotfiles/scripts/hooks/agent-alert-clear.sh"
```

Without these env vars, the plugin falls back to its own bundled scripts that set a `@opencode-alert` tmux user option and send a bell character.

### Codex CLI

Codex CLI uses `~/.codex/hooks.json` for lifecycle hooks and requires a feature flag in `~/.codex/config.toml`.

**1. Enable the feature flag** in `~/.codex/config.toml`:

```toml
[features]
codex_hooks = true
```

**2. Create `~/.codex/hooks.json`**:

```json
{
  "hooks": {
    "Stop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "~/dotfiles/scripts/hooks/wrappers/codex-alert.sh"
          }
        ]
      }
    ],
    "PermissionRequest": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "~/dotfiles/scripts/hooks/wrappers/codex-alert.sh"
          }
        ]
      }
    ],
    "UserPromptSubmit": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "~/dotfiles/scripts/hooks/wrappers/codex-alert-clear.sh"
          }
        ]
      }
    ]
  }
}
```

**Hook events explained:**

- **Stop**: Agent finished its turn and is waiting for your next message
- **PermissionRequest**: Agent needs approval to run a tool (e.g. file edit, bash command)
- **UserPromptSubmit**: You sent a message, so clear the alert

### GitHub Copilot CLI

GitHub Copilot CLI uses `~/.copilot/hooks/hooks.json` for lifecycle hooks. The wrappers also short-circuit (`exit 0`) when `$NVIM` is set so they don't fire when Copilot runs as an ACP subprocess inside Neovim (e.g. via `codecompanion.nvim`).

Create `~/.copilot/hooks/hooks.json`:

```json
{
  "hooks": {
    "agentStop": [
      {
        "type": "command",
        "command": "~/dotfiles/scripts/hooks/wrappers/copilot-alert.sh"
      }
    ],
    "preToolUse": [
      {
        "type": "command",
        "command": "~/dotfiles/scripts/hooks/wrappers/copilot-alert.sh"
      }
    ],
    "userPromptSubmitted": [
      {
        "type": "command",
        "command": "~/dotfiles/scripts/hooks/wrappers/copilot-alert-clear.sh"
      }
    ]
  }
}
```

**Hook events explained:**

- **agentStop**: Agent finished its turn and is waiting for your next message
- **preToolUse**: Agent is about to run a tool (covers permission-request style prompts)
- **userPromptSubmitted**: You sent a message, so clear the alert

## Per-Pane Agent State (Claude Code)

Beyond the binary "needs attention" alert, Claude Code hooks can also maintain a live state per tmux pane. The prefix+c instance switcher renders it as a coloured icon, plus, for the states where it's waiting on you (idle, needs-input, error, stuck), how long it's been in that state (a working turn shows no age, since that clock just tracks the last tool call):

| State       | Icon | Meaning                                              |
| ----------- | ---- | ---------------------------------------------------- |
| working     | ●    | Processing a prompt or running tools                 |
| needs-input | ◐    | Waiting on a permission prompt, question, or plan approval |
| idle        | ○    | Finished its turn, waiting for your next message     |
| error       | ✗    | Turn died on an API error (rate limit, overload)     |
| stuck       | ⚠    | Nominally working but no hook event for a while      |

State lives in `~/.config/tmux-alerts/agent-state/`, one file per pane named by pane id (e.g. `%12`), one tab-delimited line:

```
agent  state  epoch  event  session_id  cwd
```

Only Claude Code produces state today; the format carries an agent field so other agents can plug in later via their own thin wrapper.

**Event mapping** (in `scripts/hooks/agent-state.sh`):

| Hook event                                                    | State       |
| ------------------------------------------------------------- | ----------- |
| `SessionStart`, `Stop`, `Notification` (`idle_prompt`)        | idle        |
| `UserPromptSubmit`, `PreToolUse` (most tools), `PostToolUse`  | working     |
| `PreToolUse` (`AskUserQuestion`, `ExitPlanMode`)              | needs-input |
| `PermissionRequest`, `Notification` (`permission_prompt`)     | needs-input |
| `StopFailure`                                                 | error       |
| `SessionEnd`                                                  | removes the state file |
| `SubagentStop`, anything else                                 | no change   |

"Stuck" is never stored: the switcher derives it at render time when the state says working, the last event is older than `AGENT_STUCK_SECS` (default 120), and the pane title no longer starts with Claude's braille spinner character. A long tool run keeps its spinner, so it stays "working" no matter how old the last event is.

Stale files are cleaned up on three paths: `SessionEnd` removes the file, the switcher drops files for panes without a live claude process, and the tmux session-closed/renamed hooks sweep files for dead panes.

**Setup** (in the same `settings.json` as the alert hooks; both can share events):

```json
{
  "hooks": {
    "SessionStart": [
      { "hooks": [{ "type": "command", "command": "~/dotfiles/scripts/hooks/wrappers/claude-state.sh", "timeout": 5 }] }
    ],
    "UserPromptSubmit": [
      { "hooks": [{ "type": "command", "command": "~/dotfiles/scripts/hooks/wrappers/claude-state.sh", "timeout": 5 }] }
    ],
    "PreToolUse": [
      { "hooks": [{ "type": "command", "command": "~/dotfiles/scripts/hooks/wrappers/claude-state.sh", "timeout": 5 }] }
    ],
    "PostToolUse": [
      {
        "matcher": "AskUserQuestion|ExitPlanMode",
        "hooks": [{ "type": "command", "command": "~/dotfiles/scripts/hooks/wrappers/claude-state.sh", "timeout": 5 }]
      }
    ],
    "Notification": [
      { "hooks": [{ "type": "command", "command": "~/dotfiles/scripts/hooks/wrappers/claude-state.sh", "timeout": 5 }] }
    ],
    "PermissionRequest": [
      { "hooks": [{ "type": "command", "command": "~/dotfiles/scripts/hooks/wrappers/claude-state.sh", "timeout": 5 }] }
    ],
    "Stop": [
      { "hooks": [{ "type": "command", "command": "~/dotfiles/scripts/hooks/wrappers/claude-state.sh", "timeout": 5 }] }
    ],
    "StopFailure": [
      { "hooks": [{ "type": "command", "command": "~/dotfiles/scripts/hooks/wrappers/claude-state.sh", "timeout": 5 }] }
    ],
    "SessionEnd": [
      { "hooks": [{ "type": "command", "command": "~/dotfiles/scripts/hooks/wrappers/claude-state.sh", "timeout": 5 }] }
    ]
  }
}
```

Hook settings changes are picked up by new Claude Code sessions; instances already running keep their old hooks until restarted.

## How Alerts Are Stored

Alerts are tracked in `~/.config/tmux-alerts/alerts` (the path is shared across all agents, not Claude-specific). Each line has the format:

```
session:window:agent
```

For example:

```
work:claude:claude
project:opencode:opencode
```

The tmux status bar script (`tmux/scripts/alerts/show.sh`) reads this file and renders icons for sessions other than the one you're currently viewing.

## Clearing Alerts

Alerts are cleared automatically when:

- You send a message to the agent (via the clear hook)
- You switch to the tmux window containing the agent (`after-select-window` hook in tmux)
- The terminal window gains OS focus (`pane-focus-in` hook, covers cmd+` between multiple Ghostty windows attached to the same tmux server)
- The session or window is killed (stale alert cleanup)

You can also manually clear alerts by running:

```bash
tmux/scripts/alerts/clear.sh
```

## Adding a New Agent

1. Create wrapper scripts in `scripts/hooks/wrappers/`:

   ```bash
   # myagent-alert.sh
   SCRIPT_DIR="${BASH_SOURCE%/*}/.."
   "$SCRIPT_DIR/agent-alert.sh" myagent

   # myagent-alert-clear.sh
   SCRIPT_DIR="${BASH_SOURCE%/*}/.."
   "$SCRIPT_DIR/agent-alert-clear.sh" myagent
   ```

2. Add an icon and colour in `tmux/scripts/_lib/alerts.sh`:

   ```bash
   # In get_agent_display()
   myagent) echo "🔧|#50fa7b" ;;
   ```

3. Wire the wrappers into your agent's hook/plugin configuration.

## Command Exit Alerts

The alert system also supports command exit code notifications via the `notify` shell function. See [CMD-ALERTS.md](CMD-ALERTS.md) for details.

## Troubleshooting

**Alerts not appearing:**

1. Check the hooks are registered: run the wrapper directly and verify it writes to the alerts file:
   ```bash
   bash ~/dotfiles/scripts/hooks/wrappers/claude-alert.sh
   cat ~/.config/tmux-alerts/alerts
   ```
2. Verify you're inside a tmux session (hooks need `$TMUX_PANE` to identify the window)
3. Check `~/.config/tmux-alerts/alerts` has content after triggering

**Alerts not clearing:**

1. Verify the clear hook is registered for the right event
2. Check the clear script can find the tmux session/window names
3. Run `cat ~/.config/tmux-alerts/alerts` to see what's stuck

**OpenCode plugin not loading:**

1. Ensure `opencode-tmux-alert` is installed (`bun install opencode-tmux-alert` in the opencode config directory)
2. Ensure `opencode.json` has `"opencode-tmux-alert"` in the `"plugin"` array
3. Verify the env vars are set: `echo $OPENCODE_ALERT_SCRIPT $OPENCODE_CLEAR_SCRIPT`
