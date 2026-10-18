# avd-second-brain

The organizational second brain for **Azure Virtual Desktop**: one memory across the whole lifecycle, from assessing an estate with Stratusphere, through its current state and its deployment, to operating it. It remembers what each estate looked like and what broke. It also remembers what the organization learned and why each rule is what it is, so the next estate starts smarter than the last one.

> [!WARNING]
> **Personal project. Not for production. No warranty.**
>
> - This is my own personal project, built on my own time. It is **not affiliated with, endorsed by or supported by my employer**, and it does not represent my employer's views, products or guidance.
> - It is **not affiliated with or endorsed by Liquidware** or Microsoft. Stratusphere, Azure Virtual Desktop, Entra and FSLogix are trademarks of their owners.
> - It is provided **"as is", without warranty of any kind**, under the [MIT License](LICENSE).

## How it connects

| Repo | Lifecycle stage | Gives the brain | Takes from the brain |
|---|---|---|---|
| [avd-readiness-stratusphere](https://github.com/nickprignano/avd-readiness-stratusphere) | Assess and design (the migration factory) | Engagement harvests, measured sizing per wave, forensic facts (C12), target-state manifests (C14, as buckets), lessons | App catalog, rules, sizing calibration, the fact register (C15) |
| [avd-liquidware](https://github.com/nickprignano/avd-liquidware) | The Stratusphere instrument (moving from avd-readiness-stratusphere) and the optional ProfileUnity tier | Lessons; Liquidware facts once built | The manifest's `liquidware` block, later |
| [avd-current-state](https://github.com/nickprignano/avd-current-state) | Inventory and validate (collector, validator) | Evidence packages, ingested into a customer's estate vault | — |
| [avd-landing-zone](https://github.com/nickprignano/avd-landing-zone) | Deploy and operate (landing zone, operations brain) | Lessons, decisions, day-2 sizing evidence | Workload tiers, calibration, catalog, shared runbooks |

The full design: [docs/architecture.md](docs/architecture.md). The interfaces: [docs/contracts.md](docs/contracts.md).

## What's here

| Layer | What it is | Docs | Status |
|---|---|---|---|
| **Knowledge** (`knowledge/`) | Generalized knowledge shared across customers: app catalog, engine rules with their history, sizing calibration, shared runbooks, pseudonymous engagement records. Public here; an organization keeps its own in a private fork | [knowledge-spec.md](docs/knowledge-spec.md) | Built |
| **Estate vault** (`vault/`) | One customer's estate as a Markdown vault: environments, drift, findings, decisions, runbooks, built from avd-current-state packages. Kept in the customer's private repo | [vault.md](docs/vault.md) | Built (moved from avd-current-state) |
| **Operations brain** | Detections, playbooks with a person approving every change, episodes, the kill switch, for a running landing zone. The runtime deploys from avd-landing-zone | [operations-spec.md](docs/operations-spec.md), [red team](docs/operations-redteam.md) | Specified (moved from avd-landing-zone) |
| **Docs consistency** | A deterministic check that keeps code comments, READMEs, changelogs, docs and a generated wiki consistent with the code and the brain's contracts and sources; avd-swarm's Scribe drafts the fixes | [docs-spec.md](docs/docs-spec.md), [red team](docs/docs-redteam.md) | Specified |

## Quick start

PowerShell 7.4 (Azure Cloud Shell has it). No modules.

```powershell
git clone https://github.com/nickprignano/avd-second-brain.git
Set-Location avd-second-brain

# Ask the brain, across this repo and the three connected repos
./scripts/Sync-BrainSources.ps1                                        # check out the connected repos (.sources/)
./scripts/Find-BrainKnowledge.ps1 'fslogix kerberos'                   # search, with commit-pinned citations
./scripts/Find-BrainKnowledge.ps1 -App 'Skype for Business 2016'       # resolve an inventory app name
./scripts/Find-BrainKnowledge.ps1 -Calibration                         # sizing factors per tier and VM family

# A customer's estate vault, from avd-current-state packages (in their own private repo)
./vault/avd_second_brain.ps1 -BrainPath ../contoso-avd-brain -Init
./vault/avd_second_brain.ps1 -BrainPath ../contoso-avd-brain -PackagePath ../avd-current-state/avd-current-state-20261015T091500
./scripts/Get-VaultHarvest.ps1 -VaultPath ../contoso-avd-brain         # what may cross into the knowledge base

# Measured utilization from the factory's verify stage or the landing zone
./scripts/Import-SizingEvidence.ps1 -EvidencePath ./sizing-evidence.json

# Before every PR that touches knowledge/
./scripts/Test-Knowledge.ps1                                           # RESULT PASS, or what to fix
```

## Rules that keep it trustworthy

- **Tenant data stays with the tenant.** Vaults live in the customer's private repo; the knowledge base holds only generalized facts, and a guard (`scripts/Test-Knowledge.ps1`, in CI) fails on customer names, addresses, IDs, LOB apps and engagement trails in the public scope.
- **Models propose, people approve.** Knowledge changes only by a PR a person merges. A model never sets a verdict, a rule or a plan on its own.
- **Every number traces to evidence.** Rules carry a history with a reason per change; catalog verdicts cite a document, a pilot or an engagement; calibration factors are computed from observations when read.

## Validate

```bash
pwsh -c "./scripts/Test-Knowledge.ps1"
pwsh -c "foreach (\$p in 'scripts','vault') { Invoke-ScriptAnalyzer -Path \$p -Recurse -Settings ./PSScriptAnalyzerSettings.psd1 -EnableExit }"
pwsh -c "Invoke-Pester -Path ./tests -CI"
```
