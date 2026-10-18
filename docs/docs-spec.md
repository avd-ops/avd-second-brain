# Spec: one set of docs, consistent with the brain

- **Status:** Proposed ([decision 0004](decisions/0004-docs-consistency.md)). Not built; nothing here runs until the owner agrees.
- **Date:** 2026-10-18
- **Pair:** avd-swarm spec §6e and its decision 0004 say the same from the acting side. The two change together.
- **Red team:** [docs-redteam.md](docs-redteam.md). Every finding is folded in below.

## 1. Summary

Every connected repo carries five kinds of text about the same system: code comments (PowerShell comment-based help, Bicep `@description`), the README, the changelog, the docs under `docs/`, and the decisions and lessons. They drift. Today, for example, this repo's README "How it connects" table (at d2415e6) lists three repos while `sources/sources.json` lists four: avd-swarm is missing from the README entirely, and nothing caught it. It stays unfixed until D0, as the first real drift the check must catch.

This spec adds three things:

1. **A docs consistency check** (deterministic code, no model) that compares each repo's text with its code and with the brain's **facts of record**: the contracts, the connected sources, the decisions and a terms list. It runs in each repo's CI and as a nightly sweep across all of them here.
2. **A generated wiki** for people and agents: one handbook across the repos, built from the docs and the code, plus a machine-readable index that agents search and cite.
3. **Scribe**, a drafting role in avd-swarm that turns the check's findings into draft PRs (a changelog line, a README row, a comment-help block). It never merges and never decides; the check decides whether a draft is right.

The brain thinks (checks, facts of record, the wiki, the findings); avd-swarm acts (Scribe opens the PRs). The findings travel as a new contract, **C13**.

## 2. Recommendation: no new repo; the check and wiki here, the drafting in avd-swarm

| Option | For | Against | Verdict |
|---|---|---|---|
| New repo (`avd-docs`) holding the checker, generator and wiki | One place to look | A seventh repo whose own docs drift; it would duplicate `sources/sources.json`, `Sync-BrainSources.ps1` and the C7 index this repo already has; another pair to keep connected | No, for now |
| A swarm function only | Fits "agents open draft PRs" | The deterministic check isn't an agent, and putting facts of record in the actor layer breaks decision 0003 | No |
| **Split: check, facts of record and wiki in the brain; Scribe in avd-swarm** | Reuses C7 (sources, sync, citations); keeps "brain thinks, swarm acts"; the deterministic part works with no model and no Azure | Two repos change together, as every other contract already does | **Yes** |

Revisit a separate repo only if the wiki becomes a public site in its own right: then a public `avd-docs` repo that only receives generated output for GitHub Pages, with no logic in it.

## 3. Goals and non-goals

### Goals
- A person or an agent reading any doc, README, changelog or code comment in a connected repo gets the same facts: names, parameters, paths, contract status, what feeds what.
- Drift is found by code within a day, with the exact file, line and the fact it contradicts.
- Reference pages (scripts, parameters, Bicep parameters) are generated from the code, never written by hand.
- Agents (avd-swarm's coordinator through the Concierge, Claude Code sessions in any repo) answer from the same index and cite `<repo>@<commit>:<path>#<anchor>`.
- Phase D0 costs nothing: no Azure resource, no model call.

### Non-goals
- A GitHub wiki that people edit (red team W1). The wiki is generated output.
- Rewriting existing prose for style. The check finds contradictions, not taste.
- tenant-swarm (private). It is not a connected source, and nothing from it is indexed here.
- Private evidence (`/mnt/project-files/evidence/`, spike outputs, vaults). Never indexed, never published.

## 4. Sources of truth: who wins when two texts disagree

This rule is what "consistent with the brain" means. The check reports the losing side as the one to fix.

| Kind of fact | Source of truth | Examples |
|---|---|---|
| Behavior of code | **The code** at the pinned commit | Script parameters, default values, entry points, Bicep parameters and outputs, file paths |
| Cross-repo facts | **The brain's facts of record** (§5) | Contract IDs, names, status, producer and consumer; which repo feeds or reads what; paired decisions; canonical terms |
| Intent and why | **The decision** (newest accepted one wins; a superseded one says so) | "avd-swarm is the only write path" |
| What changed and when | **Merged PRs**, recorded in the changelog | Changelog entries |

Where the code and a brain fact disagree (a contract says "Built" but the importer is missing), the finding goes to the brain's side, because the fact of record is wrong.

## 5. Facts of record

What the check compares against. All already exist except the terms list.

| File | Holds | Status |
|---|---|---|
| `docs/contracts.md` (the table) | Contract ID, name, producer, consumer, format, status | Exists; the check parses the table |
| `contracts/schemas/*.json` | The authoritative schema per built contract; vendored copies elsewhere must match by hash | Exists |
| `sources/sources.json` | Connected repos, their ref, what they feed and read, the paths indexed | Exists |
| `docs/decisions/*.md` and the paired decisions in avd-swarm | Number, title, status, `Pair:` link | Exists |
| `sources/terms.json` (new) | Canonical terms and the variants to flag: kill switch positions (`run`, `halt-actions`, `halt-agents`, `halt-all`), avd-buddy, the contract names, repo names, "Entra ID" not "Azure AD", the American English spellings already required | Proposed, D0 |

## 6. The check

`scripts/Test-DocConsistency.ps1`, with the checks as pure functions in `scripts/AvdBrain.psm1` (this repo's rule), tested offline with Pester against fixture repos. PowerShell 7.4. Output: console, or `-Json` as `avd-doc-findings/v1` (C13, §9).

Each finding has a check ID, severity, repo, file, line, what the text says, what the source of truth says, and which side to fix.

| ID | Check | How (all deterministic) | Severity |
|---|---|---|---|
| D1 | **Links and paths resolve** | Every relative Markdown link and every backticked path that looks like a repo path exists at the commit; cross-repo citations `<repo>@<commit>:<path>` resolve through `.sources/` | Error |
| D2 | **Entry points are documented** | Every script a README calls an entry point (or that carries the project notice) appears in the README's entry point table, has comment-based help with `.SYNOPSIS`, and the README's one-line description matches the synopsis's first sentence word for word (the README row is generated, §7) | Error |
| D3 | **Parameters match** | Every `-Name` written next to a script name in any doc exists in that script's `param()` block (parsed with the PowerShell AST); every `.PARAMETER` in comment help exists in `param()` and every parameter has one; for Bicep, every documented parameter exists with the same default | Error |
| D4 | **Contracts agree** | Each repo's mentions of `C<n>` use the name and status in the contracts table; a "Built" contract has its schema and a test in `tests/Connectors.Tests.ps1`; vendored schema copies (avd-current-state `contracts/`) match the authority by SHA-256; `sources.json` `feeds` and `reads` name the same contracts the table gives that repo | Error |
| D5 | **Paired decisions agree** | Every decision with a `Pair:` line links a decision that exists, links back, and has the same status | Error |
| D6 | **Changelog is kept** | Every merged PR that touches an entry point, a contract, a schema or a workflow has a line under `## Unreleased` (or a release) in `CHANGELOG.md`, taken from the PR body's `Changelog:` line; a version a script prints matches the changelog's latest release | Warning in D0, error from D1 |
| D7 | **The connection tables agree** | Every table that lists connected repos (READMEs, `architecture.md`, avd-swarm spec §6c) lists the same repos as `sources/sources.json`, with the same stage | Error. Today's README drift is this check |
| D8 | **Terms** | Variants listed in `terms.json` are flagged, outside code blocks and quotations | Warning |
| D9 | **Knowledge citations resolve** | `knowledge/...#id` and `knowledge/rules/<id>.json@v<n>` cited in any doc exist at that version | Error |
| D10 | **Generated text is current** | Regenerating the reference pages, README blocks and wiki gives no diff | Error |
| D11 | **Nothing private gets through** | The generated wiki and index pass this repo's sensitive-data guard (`Test-Knowledge` patterns) and each public repo's `check-no-ids.sh` | Error, never downgraded |

**What the check deliberately doesn't do:** judge whether prose is accurate beyond these facts. That is a model's job (§8), and a model only flags.

**Rollout.** D0 runs everything as warnings for two weeks, so the first sweep's backlog doesn't block unrelated PRs (red team W8). Then D1–D5, D7, D9–D11 become errors; D6 and D8 stay warnings until the backlog is clear.

## 7. What is generated, and where it lives

Generated text sits between markers, `<!-- generated:<name> begin -->` and `<!-- generated:<name> end -->`, and a header that says not to edit it. Everything outside markers is a person's.

| Output | Built from | Lives in | For |
|---|---|---|---|
| **Reference pages**, one per entry point | Comment-based help and `param()` (AST), Bicep `@description` and parameter types | Each repo's `docs/reference/<script>.md` | People reading a repo on GitHub |
| **README blocks**: the entry point table, the "How it connects" table | The reference data; `sources/sources.json` | Each README, between markers | First thing a person reads |
| **Changelog** | `Changelog:` lines in merged PR bodies, grouped Added/Changed/Fixed/Removed ([Keep a Changelog](https://keepachangelog.com/en/1.1.0/)) | Each repo's `CHANGELOG.md` | Release notes, agents asking "what changed" |
| **The wiki** (the handbook) | Every indexed doc at the commits in `.sources/lock.json`, the reference pages, the contracts and decisions, arranged by lifecycle stage | `wiki/` in this repo, as Markdown GitHub renders | One place to read the whole system |
| **The agent index** | The same pages, chunked by heading | `wiki/index.json` (each chunk: repo, commit, path, anchor, title, terms, contracts named, first 300 characters) and `wiki/llms.txt` | `Find-BrainKnowledge.ps1 -Wiki`, the Concierge, Claude Code |

**Why not GitHub's wiki feature.** A GitHub wiki is a separate git repository with no pull requests and no CI, and this repo is private, where wikis need a paid plan. Generated Markdown in `wiki/` gets review, history and the guards for free. A public repo may later mirror its own pages to its GitHub wiki one way, overwritten on each publish, with a banner that says so (red team W1).

**Per-repo generation without depending on this private repo.** A public repo's Actions can't call a reusable workflow in a private repo (red team W2). So the small generator and the per-repo checks (D1, D2, D3, D6, D10, D11) are **vendored** into each repo as `scripts/docs/` with a pinned SHA-256, the way avd-current-state vendors the C11 schema; D4, D5, D7, D8 and D9 need the facts of record and run here, in the nightly sweep.

## 8. Who does what

| Step | Who | Model? | Writes |
|---|---|---|---|
| Check one repo on its PR | That repo's CI, vendored check | No | Nothing; fails or passes the PR |
| Sweep all repos nightly | This repo's scheduled workflow: `Sync-BrainSources.ps1`, then `Test-DocConsistency.ps1 -All -Json` | No | A findings file (C13) as a workflow artifact, and one issue here per repo with open errors, updated in place |
| Build the wiki and index | Same workflow, after the sweep | No | A draft PR here that only touches `wiki/`, when it changed |
| Judge prose against code | The Critic's pattern (brain), on demand or weekly: for each changed doc section, a Claude model lists claims the code or facts of record don't support | Yes; flags only | Findings marked `judge`, never errors; a person confirms each before Scribe may act on it |
| Draft fixes | **Scribe**, in avd-swarm (its spec §6e), from the C13 findings | Yes, for prose; the generator for generated text | Draft PRs in the repo the finding names |
| Decide | A person merges, and the check on the draft PR must pass | — | — |

**Judging is graded the same way as avd-swarm's answers** (its spec §6b): the mechanical auditor seeds faults into copies of real docs (a parameter renamed, a contract status flipped, a repo dropped from a table, a path broken) and measures the judge's catch rate; the deterministic checks above are the ground truth for the kinds they cover. Thresholds live in avd-swarm's `governance/`.

## 9. Contract C13: `avd-doc-findings/v1`

Brain → avd-swarm, like C9: the brain decides what is inconsistent; avd-swarm drafts the fix.

```json
{
  "schema": "avd-doc-findings/v1",
  "generated": "2026-10-19T03:00:00Z",
  "sources": { "avd-second-brain": "d2415e6", "avd-swarm": "25725a5" },
  "findings": [
    { "id": "D7-0001", "check": "D7", "severity": "error", "origin": "check",
      "repo": "avd-second-brain", "path": "README.md", "line": 14,
      "says": "3 connected repos", "truth": "sources/sources.json lists 4 (avd-swarm missing)",
      "fix": "repo", "generated": true }
  ]
}
```

- `origin` is `check` or `judge`; Scribe acts on a `judge` finding only once a person has confirmed it (`confirmedBy`).
- `generated: true` means the fix is regenerating a marked block, which Scribe does with the generator, not a model.
- No free text beyond `says` and `truth`, which quote the repos' own public text; the sweep only reads connected repos, so no tenant data can appear. D11 runs on the findings file too.
- Status: **Specified.** The schema (`contracts/schemas/doc-findings.schema.json`) and its test in `tests/Connectors.Tests.ps1` land in D0 with the check, and avd-swarm's Scribe follows in D1.

Scribe's outcomes need no new contract: a finding closes when the next sweep no longer reports it, and the counts (opened, drafted, merged, rejected) go to the brain in C8's insights.

## 10. Agents reading the docs

- `Find-BrainKnowledge.ps1 -Wiki '<query>'` searches `wiki/index.json` and cites `<repo>@<commit>:<path>#<anchor>`, the same form as C7.
- avd-swarm's coordinator reaches the wiki only through the Concierge read tool, as with every brain read (decision 0003).
- Each repo's `CLAUDE.md` keeps its rules and gains one line pointing at its `docs/reference/` and the brain's wiki. `CLAUDE.md` itself is never generated or edited by Scribe (red team W5).

## 11. Cost

| Phase | Azure | Model calls | GitHub |
|---|---|---|---|
| D0 | None | None | Nightly sweep in this private repo: about 3 minutes a night, roughly 90 of the 2,000 free Actions minutes a month; public repos' CI is free |
| D1 | None | Scribe and the judge, through avd-swarm's model access. Estimated before enabling in the spend format (avd-swarm `docs/spend.md`), with a monthly token cap; a docs PR draft is small (one finding's file and the facts it cites) | Same |
| D2 | None | Same, inside avd-swarm's Improve schedule | Same |

Nothing here creates an Azure resource. Any later public site (GitHub Pages) is free for public repos.

## 12. Phases

| Phase | Delivers | Exit |
|---|---|---|
| **D0** | `terms.json`; `Test-DocConsistency.ps1` with D1–D11 as pure functions and Pester fixtures; C13 schema and test; the generator for reference pages, README blocks and changelog; the nightly sweep; the first `wiki/` and `wiki/index.json`; `Find-BrainKnowledge.ps1 -Wiki`; vendored checks in the four connected repos, one PR each | The sweep runs green on the brain itself; every finding in the first sweep is fixed or recorded as accepted |
| **D1** | Scribe in avd-swarm (its spec §6e): draft PRs from C13 errors, generated fixes first; the judge, flag-only, with the seeded-fault auditor; checks become errors | Ten Scribe PRs merged with no hand edits beyond review nits; judge seeded-fault catch rate ≥ 95% |
| **D2** | Scribe runs inside avd-swarm's Improve schedule once that exists; optional one-way GitHub wiki mirror for public repos | Owner's call |

## 13. Open questions

- **DQ1.** Should the per-repo changelog start at the next merged PR, or be backfilled from merged PR titles? Default: start at the next PR, with one "Earlier history: see merged pull requests" line.
- **DQ2.** Is `wiki/` in this private repo enough, or should the public repos' share of the handbook also be published publicly? Default: private `wiki/` only until the owner decides; the public repos already have their own `docs/`.
- **DQ3.** Should avd-readiness-stratusphere's factory docs be in scope from D0, or after its phase 1? Default: from D0 for D1–D3 only.
- **DQ4.** Until avd-swarm's Scribe exists (D1), the findings issues are fixed by hand or in a Claude Code session. Is that acceptable for the first weeks? Default: yes.
