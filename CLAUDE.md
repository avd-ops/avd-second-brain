# CLAUDE.md

avd-second-brain: the organizational second brain for Azure Virtual Desktop, connecting avd-readiness-stratusphere (assess and design), avd-liquidware (the Stratusphere instrument and the Liquidware tier), avd-current-state (inventory and validate) and avd-landing-zone (deploy and operate). Design: `docs/architecture.md`; interfaces: `docs/contracts.md`.

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
- **The brain thinks, avd-swarm acts, and they change together** (decision 0003). The brain never holds a write credential; every change to an estate goes through avd-swarm's approval and its one kill switch. A change here to a contract (C8–C12, C14, C15), a playbook's shape, an agent's role, grading, models or identity comes with the matching avd-swarm PR, and each links the other.
- **The brain's agents read current state as C11 facts**, never as collector or validator packages (`docs/contracts.md` C11), and measured performance as C12 forensic facts, never Stratusphere exports. C11 and C12 are the only estate facts that reach avd-swarm, as cited evidence. The vault's own `/ask`, `/brief` and `/capture` are a person's tools inside their private vault. Each changes in three places: here, its producer and avd-swarm.
- **One registry, one fact register** (decision 0005). `contracts/schemas/` is the authority for every format that crosses a repo boundary; `contracts/fact-register.json` (C15) is the one list of fact IDs that manifests (C14), the brain's agents and avd-swarm cite. Renaming or removing a fact bumps the register's `version`. A manifest never goes into `knowledge/`; `Test-BrainKnowledge` refuses estate pseudonyms there.
- **Contracts change in pairs.** A change to `docs/contracts.md` or `contracts/schemas/` comes with the tests in `tests/Connectors.Tests.ps1`, and the producing repo follows.
- **Checks are pure functions** in `scripts/AvdBrain.psm1`, tested offline with Pester. Approved verbs: `Get-` for functions that only build data. Knowledge scripts need PowerShell 7.4 (`Test-Json`); `vault/avd_second_brain.ps1` stays Windows PowerShell 5.1-compatible.
- **Answer with citations.** Use `scripts/Find-BrainKnowledge.ps1` (after `scripts/Sync-BrainSources.ps1`) and cite what it returns: `knowledge/...#id`, `knowledge/rules/<id>.json@v<n>`, `<repo>@<commit>:<path>`.
- **Personal project, not for production, as is, not affiliated with the author's employer, Liquidware or Microsoft.** The LICENSE, the README warning and the notice at the top of every entry point stay (a test checks entry points).
- **American English** in docs, script output and comments. The vault's own text came from avd-current-state in British English; leave it until it is next edited.
