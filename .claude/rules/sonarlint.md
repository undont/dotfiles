---
paths:
  - "nvim/lua/custom/plugins/sonarlint.lua"
---

# SonarLint

User-facing documentation lives in `docs/SONARLINT.md`. This file records
implementation constraints that must not be "fixed" without re-reading the
history below.

## C# analysis is deliberately disabled — do not re-add a C# analyzer jar

The analyzer list in `analyzer_jars()` ships no C# plugin. `.cs` files only
get the text-and-secrets sensor locally; `csharpsquid` rules (cognitive
complexity etc.) surface on SonarCloud only. Both candidate jars were
investigated (2026-06) and are dead ends:

### `sonarcsharp.jar` is inert

The server-side C# plugin is flagged `SonarLint-Supported: false` in its
manifest, so the language server silently skips it. With it in the list,
`.cs` files always scan clean while SonarCloud reports issues — a silent
coverage gap that looks like coverage. The official VSCode extension never
passes it to `-analyzers` either; it only hands it to the omnisharp bridge
as the `csharpOssPath` init option.

### `sonarlintomnisharp.jar` works but fights roslyn

The real SonarLint C# path (`SonarLint-Supported: true`) spawns an omnisharp
bundled in the sonarlint vsix (`extension/omnisharp/`), which performs a
second MSBuild design-time load of the whole solution in parallel with
roslyn.nvim's — CPU contention plus shared `obj/` state — destabilising the
carefully sequenced roslyn loading described in `neovim_dotnet.md`. The
roslyn.nvim + easy-dotnet stack is the system to protect; omnisharp is not
welcome alongside it.

For the record, getting that far requires all of:

- `init_options.omnisharpDirectory`, `csharpOssPath` (sonarcsharp.jar) and
  `csharpEnterprisePath` (csharpenterprise.jar), mirroring the vsix's launch.
- A raised load-wait: the server's `omnisharp.projectLoadTimeout` workspace
  setting (read via `workspace/configuration`, maps to
  `sonar.cs.internal.loadProjectsTimeout`) defaults to 60s and big solutions
  miss it, after which the C# sensor logs "Timeout waiting for the solution
  to be loaded" and yields nothing.
- `init_options.showVerboseLogs = false`: sonarlint.nvim defaults it to true,
  which makes the server pass `-v` to omnisharp, and the bundled 1.39.10
  build then dies in a `NullReferenceException`
  (`MSBuildHelpers.GetBuildEnvironmentInfo`, a logging-only path that
  reflects into MSBuild internals that changed in MSBuild 18 / SDK 10). No
  projects load and the sensor times out exactly as above, with the only
  evidence at debug log level. Verified: the identical spawn without `-v`
  loads every project.
- omnisharp cannot read `.slnx` solutions (it predates the format), so on
  slnx-only repos it falls back to recursive directory-mode project
  discovery.

## If local C# parity with SonarCloud is ever needed

Use the `SonarAnalyzer.CSharp` NuGet package hosted by the build and
roslyn.nvim itself — same rule implementations, no second solution load, no
sonarlint involvement. Caveats: it is a team-visible repo change (warnings
appear in everyone's `dotnet build`, and `TreatWarningsAsErrors` projects
break on existing findings), and parameterised rules such as S3776 ship
disabled in the NuGet distribution and need a
`dotnet_diagnostic.S3776.severity` line in `.editorconfig` (parameters stay
at defaults; changing them needs a `SonarLint.xml` additional file).
