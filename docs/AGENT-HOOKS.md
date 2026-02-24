# Agent Alert Hooks

This dotfiles repo includes a hook system that triggers tmux status bar alerts when AI coding agents (Claude Code, OpenCode) need your attention. When an agent stops and waits for input, a bell rings and an icon appears in the tmux status bar showing which session needs you.

## How It Works

```
Agent stops working
  → Hook wrapper fires (e.g. claude-alert.sh)
    → agent-alert.sh sets a tmux window option + writes to ~/.claude/alerts
      → tmux status bar reads alerts file and displays icons

User sends a message
  → Clear wrapper fires (e.g. claude-alert-clear.sh)
    → agent-alert-clear.sh removes the entry from ~/.claude/alerts
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

Claude Code uses a `settings.json` hooks configuration. The relevant file is `~/.ai/claude/settings.json` (or wherever your Claude Code settings live).

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

#### Optional: Nvim Buffer Sync

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

OpenCode uses a JavaScript plugin system. The plugin file lives at `~/.ai/opencode/plugin/opencode-alert.js`.

**1. Register the plugin** in `opencode.json`:

```json
{
  "plugin": [
    "./plugin/opencode-alert.js"
  ]
}
```

**2. Create the plugin** at `plugin/opencode-alert.js`:

```javascript
var OpencodeAlertPlugin = async ({ $ }) => {
  const alertScript = `${process.env.HOME}/dotfiles/scripts/hooks/wrappers/opencode-alert.sh`;
  const clearScript = `${process.env.HOME}/dotfiles/scripts/hooks/agent-alert-clear.sh`;

  return {
    event: async ({ event }) => {
      try {
        // Alert when agent is idle or waiting for permission
        if (event.type === "session.idle") {
          await $`${alertScript}`;
        }
        if (event.type === "permission.asked") {
          await $`${alertScript}`;
        }
        if (event.type === "message.part.updated" &&
            event.properties?.part?.type === "tool" &&
            event.properties?.part?.state?.status === "waiting") {
          await $`${alertScript}`;
        }
        if (event.type === "tui.prompt.append") {
          await $`${alertScript}`;
        }

        // Clear when user sends a message
        if (event.type === "message.updated" && event.data?.role === "user") {
          await $`${clearScript}`;
        }
      } catch (error) {
        // Silently ignore hook errors
      }
    }
  };
};
export { OpencodeAlertPlugin };
```

## How Alerts Are Stored

Alerts are tracked in `~/.claude/alerts` (the path is shared across all agents, not Claude-specific). Each line has the format:

```
session:window:agent
```

For example:

```
work:claude:claude
dana:opencode:opencode
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

## Troubleshooting

**Alerts not appearing:**

1. Check the hooks are registered — run the wrapper directly and verify it writes to the alerts file:
   ```bash
   bash ~/dotfiles/scripts/hooks/wrappers/claude-alert.sh
   cat ~/.claude/alerts
   ```
2. Verify you're inside a tmux session (hooks need `$TMUX_PANE` to identify the window)
3. Check `~/.claude/alerts` has content after triggering

**Alerts not clearing:**

1. Verify the clear hook is registered for the right event
2. Check the clear script can find the tmux session/window names
3. Run `cat ~/.claude/alerts` to see what's stuck

**OpenCode plugin not loading:**

1. Ensure `opencode.json` has the `"plugin"` array pointing to the correct path
2. Check the debug log at `~/.opencode-alert-debug.log` for event traces
