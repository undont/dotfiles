# Secrets

API keys live in `~/.config/dotfiles/secrets` (mode 600), one `NAME=value` per line. The shell never sources it; a program reads a key only when it asks for one, so keys stay out of the main environment, and only get consumed when specifically requested.

## Storing a key

```bash
secret set BRAVE_API_KEY     # prompts without echoing; replaces an existing value
secret list                  # list stored secrets
dotfiles edit secrets        # edit the file
```

## Reading a key

- **One command**: `with-secret NAME... -- command` sets the listed variables for that command only.
- **Tools that take a key command**: give them `secret NAME`, e.g. a pi `auth.json` key of `"!secret ANTHROPIC_API_KEY"`.
- **Inline**: `$(secret NAME)`.
- **codecompanion.nvim**: the anthropic adapter uses `ANTHROPIC_API_KEY` when it is exported, and `secret ANTHROPIC_API_KEY` otherwise.

## Moving from secrets.zsh

`~/.config/zsh/secrets.zsh` is still sourced while it exists, which exports every key in it to every shell.

```bash
secret import     # copies each export into the secrets file; stored names are kept
```

Check a key with `secret NAME`, then delete `secrets.zsh` and open a new shell.
