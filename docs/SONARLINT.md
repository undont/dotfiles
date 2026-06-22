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
for IDE" plugins: `{ "projectKey": "my-org_my-project" }`.

## `localRules.json`

A project-local file for tuning which rules fire and with what parameters, without
touching the server-side quality profile. It is always loaded; connected mode is not
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
Both top-level fields are optional: supply `rules`, `overrides`, or both.

### Rule values

A rule value is either a bare severity or the array form for parameterised rules:

| Form | Example | Meaning |
|---|---|---|
| Severity string | `"off"`, `"warn"`, `"error"` | Enable or disable the rule |
| Severity number | `0`, `1`, `2` | Same, ESLint's numeric severities |
| Array | `["error", { "param": "value" }]` | Severity plus named rule parameters |

**Severity maps to two states, not three.** SonarLint has no warn/error split, so
`"warn"`/`1` and `"error"`/`2` both map to level `"on"`; only `"off"`/`0` silences a
rule. The warn/error distinction is accepted for familiarity but has no effect; pick
whichever reads best.

For the array form, ESLint options are positional but SonarLint parameters are named,
so only a **trailing object** is carried across (the `{ ... }` at index 1). Parameter
names and accepted values come from the rule's own definition; check the rule in
SonarQube/SonarCloud or via the `mcp-sonarqube` `show_rule` tool.

Unrecognised values are dropped silently rather than erroring, so a malformed entry
disables that one override instead of breaking the whole file.

### `rules`: global overrides

Entries under `rules` are merged into the LSP server's rule config and apply across the
whole project. This works in both standalone and connected mode. In connected mode an
explicit `"off"` here **wins over** the server profile's `"on"`, so the local file can
silence a rule the shared profile enables. (Each entry sends an explicit level to the
server; `"off"` is the reliable, tested direction.)

### `overrides`: per-glob, subtractive only

`overrides` is an eslintrc-style array of `{ "files": [glob], "rules": {...} }` entries,
applied **client-side** at diagnostic-publish time by a wrapped `publishDiagnostics`
handler.

The key constraint: **overrides can only silence diagnostics, never re-enable them.**
A rule that is `"off"` globally has already stopped being produced by the server, so no
per-glob entry can bring it back. In practice this means override `rules` values other
than `"off"` are ignored; the only useful per-glob action is turning a rule off for a
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

## Issue details popup

The first code action on any sonar finding is **"Show issue details for
`<rule>`"**. Selecting it opens a popup with the rule's full description: the
"Why is this an issue?" and "How can I fix it?" sections with their code
examples, rather than the one-line message shown inline. `q` or `<Esc>` closes
it.

Where a rule ships framework-specific fixes (sonar's contextual tabs, for
example "How to fix it in PropTypes" versus "in TypeScript"), each is rendered
under its own subheading, default context first. Sonar's generic "others"
fallback ("How can I fix it in another component or framework?" / "Help us
improve") is dropped, and if that leaves a section empty it is omitted entirely
rather than shown as a bare heading.

For **deprecation findings** (`typescript:S1874` and equivalents) the popup
leads with the specific API instead of the generic rule text. It shows the
deprecated symbol's signature and its `@deprecated` note (the recommended
replacement), pulled from the editor-facing language server's hover at the
finding:

```text
## Deprecated API

function oldFunction(): void

@deprecated: Use newFunction instead.
```

Sonar's own S1874 text is generic and explicitly defers to "the deprecation
message" for the specific alternative, which is why that part comes from the
language server (`ts_ls`, `gopls`, `roslyn`, and so on) rather than from sonar.
Deprecation is detected from a co-located diagnostic carrying the LSP
`Deprecated` tag, so it works for any language whose server tags deprecated
usages, with no per-rule list. When no such tag is present the popup shows the
rule description on its own.

## Silencing from code actions

When hovering over diagnostics, the code-action menu (`gra`) offers up to two quick fixes per rule:

- **Sonar: silence `<rule>` (project)**: adds `"<rule>": "off"` to the
  top-level `rules` map.
- **Sonar: silence `<rule>` in test files**: adds (or extends) an `overrides`
  entry whose `files` are the test globs for the buffer's language, silencing
  the rule only there.

They create `.sonarlint/` and `localRules.json` if they don't exist, preserve
any existing entries, and apply immediately: the project-wide variant pushes
the updated rule config to the running server, and the test variant recompiles
the override matchers, so the warning clears without a restart.

The test globs are per language, so the "in test files" action only appears for
languages with a settled test-naming convention:

| Language | Test globs |
|---|---|
| Go | `**/*_test.go` |
| Python | `**/test_*.py`, `**/*_test.py` |
| JavaScript | `**/*.test.js`, `**/*.spec.js` (+ `.jsx` for React) |
| TypeScript | `**/*.test.ts`, `**/*.spec.ts` (+ `.tsx` for React) |
| C# | `**/*Tests.cs`, `**/*Test.cs` |
| C / C++ | `**/*_test.c`, `**/*_test.cpp`, `**/*_test.cc` |
| PHP | `**/*Test.php` |

The actions are injected into SonarLint's own code-action response, so they sit
directly under its "Show issue details" / "Deactivate rule" entries rather than
at the bottom of the picker. Selecting one runs locally (via `vim.lsp.commands`)
without a server round-trip.

## Scanning

SonarLint only analyses open buffers. Four LSP keymaps run a scan that hidden-loads
files, snapshots the diagnostics into the quickfix list, then unloads what it opened:
one scoped to changed/untracked files (needs a git repo), one scoped to every file
changed vs main, one scoped to the files touched by ticket-matching commits (prompts
for a commit grep with a default pulled from the branch name; the same commit discovery
as the diff-by-ticket and ticket diagnostics-scan bindings), and one for the whole
project (with a confirmation prompt above 500 files). Each mirrors an all-LSP
diagnostics-scan binding under `<leader>x`. The exact bindings live in the `lsp` section
of `nvim/cheatsheet.txt` (and `<leader>?` in the editor) so they stay in one place.

## C# is not analysed locally

The analyzer list deliberately ships no C# plugin: SonarLint's C# analysis
runs through a bundled omnisharp whose second solution load conflicts with
the roslyn.nvim setup. `.cs` files only get the text-and-secrets sensor
locally; `csharpsquid` rules (cognitive complexity and friends) surface on
SonarCloud only. The full investigation and the conditions under which this
could be revisited live in `.claude/rules/sonarlint.md`.

## Troubleshooting

- **A `rules` entry has no effect.** Confirm the rule key and that you used `"off"` to
  silence it; `"warn"`/`"error"` both leave the rule enabled.
- **An `overrides` entry has no effect.** Check you're on Neovim 0.10+, that the value is
  `"off"` (other severities can't re-enable), and that the glob matches; try both a
  relative (`**/...`) and an anchored form.
- **The whole file is ignored.** It must be valid JSON at `.sonarlint/localRules.json` in
  the project root (the directory Neovim resolves as the LSP root). A parse error makes
  the loader return nothing rather than partially applying.
