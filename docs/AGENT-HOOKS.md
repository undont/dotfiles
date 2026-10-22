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
| Codex    | ⌘    | Green  |
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
    "PreToolUse": [
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
    ],
    "SessionEnd": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "~/dotfiles/scripts/hooks/wrappers/claude-alert-clear.sh",
            "timeout": 5
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
- **PreToolUse** (`AskUserQuestion`): Agent is about to ask you a question. `PostToolUse` is too late here: it fires once you have already answered, which raises an alert for input you just gave
- **UserPromptSubmit**: You sent a message, so clear the alert
- **SessionEnd**: The session ended without another prompt (exit, `/clear`), so clear the alert rather than leaving the last **Stop** alert behind

#### Optional: Nvim Buffer Sync (Beta feature)

If you run Claude Code alongside a Neovim instance that listens on a socket, you can add a hook that adds edited files to Neovim's buffer list:

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

This reads the `NVIM_SOCKET` environment variable and calls `nvim --server` to add the file to the buffer list. Nothing in the dotfiles sets `NVIM_SOCKET`: start Neovim with `nvim --listen <socket>` and export `NVIM_SOCKET=<socket>` in the shell that launches Claude Code. With the variable unset, or pointing at a path that is not a socket, the hook exits without doing anything.

### OpenCode

OpenCode uses the [`opencode-tmux-alert`](https://github.com/undont/opencode-tmux-alert) CLI plugin. It runs inside each terminal OpenCode, so alerts land on the window that OpenCode is in. It alerts on permission requests, questions, and finished, failed or stalled turns. It clears once nothing is pending, e.g. after you answer or send the next message.

**1. Register the plugin** in `~/.config/opencode/cli.json` (CLI settings, not `opencode.json`):

```json
{
  "plugins": ["opencode-tmux-alert"]
}
```

OpenCode installs the package itself; no `bun install` needed.

**2. Set environment variables** so the plugin uses the dotfiles hook scripts (already set in `dotfiles.zsh`):

```bash
export OPENCODE_ALERT_SCRIPT="$HOME/dotfiles/scripts/hooks/wrappers/opencode-alert.sh"
export OPENCODE_CLEAR_SCRIPT="$HOME/dotfiles/scripts/hooks/agent-alert-clear.sh"
export OPENCODE_STATE_SCRIPT="$HOME/dotfiles/scripts/hooks/wrappers/opencode-state.sh"
```

Without these, the plugin falls back to its bundled scripts. Those set a `@opencode-alert` tmux user option and ring the bell.

Don't list the plugin under `plugins` in `opencode.json`. That loads it into the shared OpenCode background service (versions before 2.0 only), which sends every alert to whichever window started the service.

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

## Per-Pane Agent State

Beyond the binary "needs attention" alert, Claude Code hooks and the OpenCode plugin can also maintain a live state per tmux pane. The prefix+c (Claude) and prefix+o (OpenCode) instance switchers render it as a coloured icon, plus, for the states where it's waiting on you (idle, needs-input, error, stuck), how long it's been in that state (a working turn shows no age, since that clock just tracks the last tool call):

| State       | Icon | Meaning                                                    |
| ----------- | ---- | ---------------------------------------------------------- |
| working     | ●    | Processing a prompt or running tools                       |
| needs-input | ◐    | Waiting on a permission prompt, question, or plan approval |
| idle        | ○    | Finished its turn, waiting for your next message           |
| error       | ✗    | Turn died on an API error (rate limit, overload)           |
| stuck       | ⚠    | Nominally working but no hook event for a while            |

State lives in `~/.config/tmux-alerts/agent-state/`, one file per pane named by pane id (e.g. `%12`), one tab-delimited line:

```
agent  state  epoch  event  session_id  cwd
```

Claude Code and OpenCode produce state. The format carries an agent field so other agents can plug in through their own thin wrapper; `agent-state.sh` accepts either hook JSON on stdin (Claude) or an already-mapped state in `AGENT_STATE` (direct mode, used by the OpenCode wrapper).

**Claude event mapping** (in `scripts/hooks/agent-state.sh`):

| Hook event                                                                                           | State                  |
| ---------------------------------------------------------------------------------------------------- | ---------------------- |
| `SessionStart`, `Stop`, `Notification` (`idle_prompt`)                                               | idle                   |
| `UserPromptSubmit`, `PreToolUse` (most tools), `PostToolUse`                                         | working                |
| `PreToolUse` (`AskUserQuestion`, `ExitPlanMode`)                                                     | needs-input            |
| `PermissionRequest`, `Notification` (`permission_prompt`, `elicitation_dialog`, `agent_needs_input`) | needs-input            |
| `StopFailure`                                                                                        | error                  |
| `SessionEnd`                                                                                         | removes the state file |
| `SubagentStop`, anything else                                                                        | no change              |

"Stuck" is never stored: the switcher derives it at render time when the state says working, the last event is older than `AGENT_STUCK_SECS` (default 120), and the pane title no longer starts with Claude's braille spinner character. A long tool run keeps its spinner, so it stays "working" no matter how old the last event is.

The switcher also derives the reverse: no hook event fires at the moment a permission prompt is approved, so a stored needs-input can go stale while the agent is already running again. If the pane title shows the spinner, needs-input is rendered as working. The stored state corrects itself at the next hook event (the approved tool's `PostToolUse`, or the next `PreToolUse`).

Stale files are cleaned up on three paths: `SessionEnd` removes the file, the switcher drops files for panes without a live claude process, and the tmux session-closed/renamed hooks sweep files for dead panes.

**OpenCode** reports state through the `opencode-tmux-alert` plugin's state script (`OPENCODE_STATE_SCRIPT`, already exported in `dotfiles.zsh` to `scripts/hooks/wrappers/opencode-state.sh`). The plugin derives the state from OpenCode's own events and only runs the script when it changes:

| OpenCode event                                                 | State                                              |
| -------------------------------------------------------------- | -------------------------------------------------- |
| OpenCode starts                                                | idle (working if the session is already running)   |
| `session.execution.started`                                    | working                                            |
| `permission.asked`, `form.created`                             | needs-input while unanswered                       |
| `permission.replied`, `form.replied`, `form.cancelled`         | back to working, or idle/error if the turn is over |
| `session.execution.succeeded`, `session.execution.interrupted` | idle                                               |
| `session.execution.failed`                                     | error                                              |
| OpenCode exits                                                 | removes the state file                             |

OpenCode reports permission replies, so needs-input never goes stale. There's no stuck state for OpenCode: its pane title has no activity spinner to tell a long tool run from a hang. The prefix+o switcher drops files for panes without a live opencode process.

**Setup** (in the same `settings.json` as the alert hooks; both can share events):

```json
{
  "hooks": {
    "SessionStart": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "~/dotfiles/scripts/hooks/wrappers/claude-state.sh",
            "timeout": 5
          }
        ]
      }
    ],
    "UserPromptSubmit": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "~/dotfiles/scripts/hooks/wrappers/claude-state.sh",
            "timeout": 5
          }
        ]
      }
    ],
    "PreToolUse": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "~/dotfiles/scripts/hooks/wrappers/claude-state.sh",
            "timeout": 5
          }
        ]
      }
    ],
    "PostToolUse": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "~/dotfiles/scripts/hooks/wrappers/claude-state.sh",
            "timeout": 5
          }
        ]
      }
    ],
    "Notification": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "~/dotfiles/scripts/hooks/wrappers/claude-state.sh",
            "timeout": 5
          }
        ]
      }
    ],
    "PermissionRequest": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "~/dotfiles/scripts/hooks/wrappers/claude-state.sh",
            "timeout": 5
          }
        ]
      }
    ],
    "Stop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "~/dotfiles/scripts/hooks/wrappers/claude-state.sh",
            "timeout": 5
          }
        ]
      }
    ],
    "StopFailure": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "~/dotfiles/scripts/hooks/wrappers/claude-state.sh",
            "timeout": 5
          }
        ]
      }
    ],
    "SessionEnd": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "~/dotfiles/scripts/hooks/wrappers/claude-state.sh",
            "timeout": 5
          }
        ]
      }
    ]
  }
}
```

Hook settings changes are picked up by new Claude Code sessions; instances already running keep their old hooks until restarted.

## How Alerts Are Stored

Alerts are tracked in `~/.config/tmux-alerts/alerts` (the path is shared across all agents, not Claude-specific). Each line has the format:

```
session:window:agent:window_id
```

For example:

```
work:claude:claude:@4
project:opencode:opencode:@11
```

`window_id` is the match key for dismissal and cleanup. The window name is volatile: `automatic-rename` derives it from the agent's pane title, so it changes throughout a turn and a row keyed on the name alone is unmatchable by the time the clear runs. The name stays in the row for display, is rewritten whenever the alert is re-set, and is refreshed by the stale-alert sweep. Rows written before ids were recorded have three fields and still match on the name.

The tmux status bar script (`tmux/scripts/alerts/show.sh`) reads this file and renders icons for sessions other than the one you're currently viewing.

## Clearing Alerts

Alerts are cleared automatically when:

- You send a message to the agent (via the clear hook)
- The agent session ends without another prompt, such as exit or `/clear` (`SessionEnd` hook)
- You switch to the tmux window containing the agent (`after-select-window` hook in tmux)
- The terminal window gains OS focus (`pane-focus-in` hook, covers cmd+` between multiple Ghostty windows attached to the same tmux server)
- The session or window is killed (stale alert cleanup)

The stale-alert sweep also runs on both rename paths. `after-rename-window` covers the `rename-window` command (prefix+,); `automatic-rename` never runs that command and fires `window-renamed` instead, which is the path that matters for agents, since their window name tracks the pane title.

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

The alert system also shows exit alerts for shell commands that finish while you are in another window, with no wrapper needed. See [CMD-ALERTS.md](CMD-ALERTS.md) for details.

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
4. Compare the `window_id` on the stuck row against `tmux list-windows -a -F '#{window_id} #{window_name}'`. A row for a live window that never clears means the clear hook is resolving a different window; a row for a dead window means the sweep is not running

**Exercising the hooks without waiting for an agent:**

Claude Code has no command that fires a hook on demand, but a hook is just a command reading the event JSON on stdin, so it can be replayed:

```bash
printf '%s' '{"hook_event_name":"Stop","session_id":"probe","cwd":"/tmp"}' \
  | ~/dotfiles/scripts/hooks/wrappers/claude-state.sh
```

Point `AGENT_STATE_DIR` or `ALERTS_FILE` at a scratch path first to keep a probe out of the live state. To watch the real hooks fire instead, `claude --debug hooks` logs every match with its exit code and output, and `--debug-file <path>` writes the same to a file you can tail from another pane.

**OpenCode plugin not loading:**

1. Ensure `cli.json` has `"opencode-tmux-alert"` in its `"plugins"` array, then restart OpenCode
2. Check `/plugins` in OpenCode lists it as an active TUI plugin (or run `opencode plugin list`)
3. Verify the env vars are set in the shell that launched OpenCode: `echo $OPENCODE_ALERT_SCRIPT $OPENCODE_CLEAR_SCRIPT`

**OpenCode alerts land on the wrong window:** an old server-plugin install is still active. Remove `opencode-tmux-alert` from `plugins` in `opencode.json` and run `opencode service restart`.
