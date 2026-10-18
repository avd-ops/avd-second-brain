---
status: proposed
date: 2026-10-18
decision-makers: [owner]
---

# 0004. Docs consistency: the brain checks and generates, avd-swarm drafts

## Context and Problem Statement

The owner asked on 2026-10-18 for a repo or swarm function that builds a wiki and documentation for people and agents from the functions being added, and keeps code comments, changelogs, READMEs and the wiki consistent with the second brain. Drift already exists: this repo's README lists three connected repos while `sources/sources.json` lists four. Where does that check live, and who fixes what it finds?

## Considered Options

- A new repo for the check, the generator and the wiki
- The check and generator here, avd-swarm drafting the fixes, the wiki as generated Markdown in `wiki/`
- The same, with the wiki in GitHub's wiki feature

## Decision Outcome

Chosen option: "The check and generator here, avd-swarm drafting the fixes, the wiki as generated Markdown in `wiki/`", because this repo already owns the connected sources and their commit-pinned citations, and a wiki in the repo gets review, history and the guards.

- **No new repo.** The check, the facts of record, the generator and the wiki live here, because this repo already owns the connected sources, their sync and commit-pinned citations (C7). Spec: [docs-spec.md](../../docs-spec.md); red team: [docs-redteam.md](../../docs-redteam.md).
- **The brain thinks:** `Test-DocConsistency.ps1` (deterministic, no model) decides what is inconsistent, against the code and the facts of record (contracts, sources, decisions, `sources/terms.json`). Code wins on behavior; the facts of record win on cross-repo facts.
- **avd-swarm acts:** its Scribe role turns findings into draft PRs. It never merges and can't touch `CLAUDE.md`, prompts, governance, workflows or the notice.
- **The handoff is contract C13**, `avd-doc-findings/v1`, brain → avd-swarm.
- **The wiki is generated Markdown in `wiki/`**, reviewed by PR, not a GitHub wiki.

### Consequences

- Phase D0 (check, generator, wiki, and the shared check each repo calls pinned by SHA) costs no Azure and no model calls, and works before avd-swarm exists.
- Each connected repo gains a caller for `docs-check.yml` (pinned by SHA), `docs/reference/`, generated README blocks and a `CHANGELOG.md`.
- A change to C13, the checks' rules or Scribe's limits is a pair of PRs here and in avd-swarm.

## More Information

- **Pair:** [avd-swarm decision 0004](https://github.com/nickprignano/avd-swarm/blob/main/docs/decisions/0004-scribe-drafts-docs.md) says the same from the other side. The two change together.
- Moved here from `docs/decisions/` and converted to MADR 4; the decision itself is unchanged.
