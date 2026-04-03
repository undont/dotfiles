# Agent Alert Hooks

This dotfiles repo includes a hook system that triggers tmux status bar alerts when AI coding agents (Claude Code, OpenCode) need your attention. When an agent stops and waits for input, a bell rings and an icon appears in the tmux status bar showing which session needs you.

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

| Agent    | Icon | Colour  |
|----------|------|---------|
| Claude   | ⚡   | Yellow  |
| OpenCode | 🔮   | Purple  |

## File Layout

```
scripts/hooks/
├── agent-alert.sh           # Core: set alert for any agent
├── agent-alert-clear.sh     # Core: clear alert for current window
├── cmd-alert.sh             # Core: set exit code alert for a command
├── cmd-alert-hook.zsh       # zsh preexec/precmd hooks (sourced by dotfiles.zsh)
├── nvim-buffer-sync.sh      # Sync edited files to paired nvim
└── wrappers/
    ├── claude-alert.sh      # Calls agent-alert.sh claude
    ├── claude-alert-clear.sh
    ├── opencode-alert.sh    # Calls agent-alert.sh opencode
    └── opencode-alert-clear.sh
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

- **Stop** — Agent finished its turn and is waiting for your next message
- **PermissionRequest** — Agent needs approval to run a tool (e.g. file edit, bash command)
- **PostToolUse** (`AskUserQuestion`) — Agent asked you a question via the AskUserQuestion tool
- **UserPromptSubmit** — You sent a message, so clear the alert

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

OpenCode uses the [`opencode-tmux-alert`](https://github.com/seanhalberthal/opencode-tmux-alert) plugin. The plugin triggers alerts on session idle, permission requests, tool pending, and prompt appends — and clears when the user sends a message.

**1. Install the plugin:**

```bash
cd ~/.config/opencode  # or wherever your opencode.json lives
bun install opencode-tmux-alert
```

**2. Register the plugin** in `opencode.json`:

```json
{
  "plugin": [
    "opencode-tmux-alert"
  ]
}
```

**3. Set environment variables** so the plugin uses the dotfiles hook scripts (already set in `dotfiles.zsh`):

```bash
export OPENCODE_ALERT_SCRIPT="$HOME/dotfiles/scripts/hooks/wrappers/opencode-alert.sh"
export OPENCODE_CLEAR_SCRIPT="$HOME/dotfiles/scripts/hooks/agent-alert-clear.sh"
```

Without these env vars, the plugin falls back to its own bundled scripts that set a `@opencode-alert` tmux user option and send a bell character.

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

1. Check the hooks are registered — run the wrapper directly and verify it writes to the alerts file:
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
