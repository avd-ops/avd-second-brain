# CLAUDE.md

avd-second-brain: the organizational second brain for Azure Virtual Desktop, connecting avd-readiness-stratusphere (assess and design), avd-current-state (inventory and validate) and avd-landing-zone (deploy and operate). Design: `docs/architecture.md`; interfaces: `docs/contracts.md`.

## Validate before pushing
CI (`.github/workflows/validate.yml`) runs:

```bash
pwsh -c "./scripts/Test-Knowledge.ps1"
pwsh -c "foreach (\$p in 'scripts','vault') { Invoke-ScriptAnalyzer -Path \$p -Recurse -Settings ./PSScriptAnalyzerSettings.psd1 -EnableExit }"
pwsh -c "Invoke-Pester -Path ./tests -CI"
```

## Rules
- **Three layers, three kinds of data** (`docs/architecture.md` §3). `knowledge/` holds generalized knowledge only; estate vaults (built by `vault/avd_second_brain.ps1`) hold one customer's tenant data and live in that customer's private repo; never copy vault or engagement content into this repo, an issue or a PR.
- **Knowledge changes only by a PR a person merges**, normally a harvest (`.claude/skills/harvest`). Run `scripts/Test-Knowledge.ps1` first; a `sensitive:*` finding means customer data got through: remove it, never loosen the pattern to pass.
- **A model never decides.** It may normalize names and draft text; verdicts need evidence, rule changes need a reason and a history entry.
- **Contracts change in pairs.** A change to `docs/contracts.md` or `contracts/schemas/` comes with the tests in `tests/Connectors.Tests.ps1`, and the producing repo follows.
- **Checks are pure functions** in `scripts/AvdBrain.psm1`, tested offline with Pester. Approved verbs: `Get-` for functions that only build data. Knowledge scripts need PowerShell 7.4 (`Test-Json`); `vault/avd_second_brain.ps1` stays Windows PowerShell 5.1-compatible.
- **Answer with citations.** Use `scripts/Find-BrainKnowledge.ps1` (after `scripts/Sync-BrainSources.ps1`) and cite what it returns: `knowledge/...#id`, `knowledge/rules/<id>.json@v<n>`, `<repo>@<commit>:<path>`.
- **Personal project, not for production, as is, not affiliated with the author's employer, Liquidware or Microsoft.** The LICENSE, the README warning and the notice at the top of every entry point stay (a test checks entry points).
- **American English** in docs, script output and comments. The vault's own text came from avd-current-state in British English; leave it until it is next edited.
