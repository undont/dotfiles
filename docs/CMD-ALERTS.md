# Command Exit Alerts

Run a long command in a tmux window, switch away, and get notified automatically when it finishes. Pass/fail results show as icons in the tmux status bar — the same system used for agent alerts.

No wrapping required. Any command that completes while you're in a different window will trigger an alert.

## How It Works

```
You run: make test  (then switch to another window)
  → make test runs normally
  → Command exits (code 0 or non-zero)
    → precmd hook fires
      → Elapsed time ≥ 10s AND you've switched away?
        → cmd-alert.sh sets exit alert
          → Bell rings + window tab highlights green or red
          → Status bar shows ✓ or ✗ for other sessions

You switch back to the window
  → after-select-window hook fires
    → Alert clears automatically
```

The hooks (`preexec`/`precmd`) are registered in `zsh/dotfiles.zsh` and run transparently — zero overhead on the command itself.

## Alert Display


| Result | Icon | Colour | Meaning            |
|--------|------|--------|--------------------|
| Pass   | ✓    | Green  | Exit code 0        |
| Fail   | ✗    | Red    | Exit code non-zero |

### Status bar
Icons appear in the right side of the status bar for commands in **other sessions**, showing `session:command` for context:
- `✓ dev:make test` — tests passed in the `dev` session
- `✗ build:npm run lint` — linting failed in the `build` session

Same-session alerts only highlight the window tab (no status bar entry).

### Window tabs
The window tab colour changes:
- Green for pass
- Red for fail

## Conditions for Alerting

An alert fires only when **all** of the following are true:
1. You are inside tmux
2. You switched to a different window before the command finished

If you're still watching the command, no alert fires — it would just be noise.

## Command Label Truncation

The label shown in the status bar is built from the command line:

| Command | Label |
|---------|-------|
| `make test` | `make test` |
| `npm run build` | `npm run build` |
| `./scripts/run-tests.sh --verbose` | `run-tests.sh --verbose` |
| `docker compose -f prod.yml up --build` | `docker compose…` |

Rules: basename the first word, use as-is if ≤ 3 words, otherwise first 2 words + `…`.

## Clearing Alerts

Alerts clear automatically when you switch to the window. You can also manually clear:
```bash
alerts-clear    # Alias for rm -rf ~/.config/agent-alerts
```

## Technical Details

- `preexec` hook: records `$SECONDS` and current tmux window at command start
- `precmd` hook: on completion, checks elapsed time and whether window changed
- Alert file: `~/.config/agent-alerts/alerts` (format: `session:window:exit:<code>:<label>`)
- Hook script: `scripts/hooks/cmd-alert.sh`
- Bell + status bar rendering: `tmux/scripts/alerts/show.sh`
- Auto-clear on window switch: `after-select-window` hook in `tmux.conf.template`
