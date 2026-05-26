# SonarLint

SonarLint runs as a second LSP client (`sonarlint-language-server`, Mason-managed)
surfacing SonarQube/SonarCloud diagnostics alongside the editor-facing language
servers. Config lives in `nvim/lua/custom/plugins/sonarlint.lua`.

Two per-project files drive it, both under `.sonarlint/` at the project root:

| File | Purpose |
|---|---|
| `connectedMode.json` | Binds the project to a SonarCloud project key (connected mode) |
| `localRules.json` | Project-local rule overrides (works in both standalone and connected mode) |

`connectedMode.json` follows the same convention as the JetBrains/VSCode "SonarQube
for IDE" plugins — `{ "projectKey": "my-org_my-project" }`.

## `localRules.json`

A project-local file for tuning which rules fire and with what parameters, without
touching the server-side quality profile. It is always loaded — connected mode is not
required. The schema is **ESLint-style**: rule values are ESLint severities, not
SonarLint's native `{ level }` shape.

```json
{
  "rules": {
    "go:S100": "off",
    "go:S3776": "warn",
    "javascript:S103": ["error", { "maximumLineLength": "120" }]
  },
  "overrides": [
    {
      "files": ["**/*_test.go"],
      "rules": { "go:S3776": "off" }
    }
  ]
}
```

Rule keys are SonarLint's `language:ruleId` form (e.g. `go:S100`, `javascript:S103`).
Both top-level fields are optional — supply `rules`, `overrides`, or both.

### Rule values

A rule value is either a bare severity or the array form for parameterised rules:

| Form | Example | Meaning |
|---|---|---|
| Severity string | `"off"`, `"warn"`, `"error"` | Enable or disable the rule |
| Severity number | `0`, `1`, `2` | Same, ESLint's numeric severities |
| Array | `["error", { "param": "value" }]` | Severity plus named rule parameters |

**Severity maps to two states, not three.** SonarLint has no warn/error split, so
`"warn"`/`1` and `"error"`/`2` both map to level `"on"`; only `"off"`/`0` silences a
rule. The warn/error distinction is accepted for familiarity but has no effect — pick
whichever reads best.

For the array form, ESLint options are positional but SonarLint parameters are named,
so only a **trailing object** is carried across (the `{ ... }` at index 1). Parameter
names and accepted values come from the rule's own definition — check the rule in
SonarQube/SonarCloud or via the `mcp-sonarqube` `show_rule` tool.

Unrecognised values are dropped silently rather than erroring, so a malformed entry
disables that one override instead of breaking the whole file.

### `rules` — global overrides

Entries under `rules` are merged into the LSP server's rule config and apply across the
whole project. This works in both standalone and connected mode. In connected mode an
explicit `"off"` here **wins over** the server profile's `"on"`, so the local file can
silence a rule the shared profile enables. (Each entry sends an explicit level to the
server; `"off"` is the reliable, tested direction.)

### `overrides` — per-glob, subtractive only

`overrides` is an eslintrc-style array of `{ "files": [glob], "rules": {...} }` entries,
applied **client-side** at diagnostic-publish time by a wrapped `publishDiagnostics`
handler.

The key constraint: **overrides can only silence diagnostics, never re-enable them.**
A rule that is `"off"` globally has already stopped being produced by the server, so no
per-glob entry can bring it back. In practice this means override `rules` values other
than `"off"` are ignored — the only useful per-glob action is turning a rule off for a
subset of files (the `**/*_test.go` example above).

Globs are compiled with `vim.glob.to_lpeg` (**requires Neovim 0.10+**; on older versions
`overrides` is skipped, `rules` still applies). Each glob is matched against **both** the
absolute path and the path relative to the project root, so you can write either style:

```json
{ "files": ["**/*_test.go"] }            // relative-style, matches anywhere
{ "files": ["internal/**/*_test.go"] }   // anchored under a subdirectory
```

## Worked example

Disable the cognitive-complexity rule (`go:S3776`) in test files only, raise the
JS max-line-length to 120, and turn off a noisy naming rule project-wide:

```json
{
  "rules": {
    "go:S100": "off",
    "javascript:S103": ["error", { "maximumLineLength": "120" }]
  },
  "overrides": [
    {
      "files": ["**/*_test.go", "**/testdata/**"],
      "rules": { "go:S3776": "off" }
    }
  ]
}
```

## Scanning

SonarLint only analyses open buffers. Two LSP keymaps run a project scan that
hidden-loads files, snapshots the diagnostics into the quickfix list, then unloads what
it opened — one scoped to changed/untracked files (needs a git repo), one for the whole
project (with a confirmation prompt above 500 files). The exact bindings live in the
`lsp` section of `nvim/cheatsheet.txt` (and `<leader>?` in the editor) so they stay in
one place.

## Troubleshooting

- **A `rules` entry has no effect.** Confirm the rule key and that you used `"off"` to
  silence it — `"warn"`/`"error"` both leave the rule enabled.
- **An `overrides` entry has no effect.** Check you're on Neovim 0.10+, that the value is
  `"off"` (other severities can't re-enable), and that the glob matches — try both a
  relative (`**/...`) and an anchored form.
- **The whole file is ignored.** It must be valid JSON at `.sonarlint/localRules.json` in
  the project root (the directory Neovim resolves as the LSP root). A parse error makes
  the loader return nothing rather than partially applying.
