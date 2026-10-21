---
status: accepted
date: 2026-10-16
decision-makers: [owner]
---

# 0001. One brain for the AVD lifecycle, in its own repository

## Context and Problem Statement

Three repositories grew separate second brains: avd-current-state a Markdown vault per customer (built), avd-landing-zone an operations brain for a running landing zone (specified, its decision 0012), and the assessment project (private) the migration factory's knowledge base (built, its decision 0002). They cover one lifecycle (assess, inventory, design, deploy, operate) but couldn't share what they learn: pilot results didn't reach the image pipeline, day-2 utilization didn't correct sizing, one customer's runbook didn't help the next. Where should the brain live so that all three can learn from each other?

## Considered Options

- Keep a separate brain in each repository
- One brain for the whole lifecycle, in its own repository

## Decision Outcome

Chosen option: "One brain for the whole lifecycle, in its own repository", because it is the only option where what one stage learns reaches the others.

- **avd-second-brain** is the one home for the brain: the knowledge base (from the assessment project), the estate vault tool and template (from avd-current-state), the operations brain's spec and red team (from avd-landing-zone), and the contracts between them. The source repos keep their sensors and runtimes and point here.
- Three layers by whose data they hold: **knowledge** (generalized; public here, organization in a private fork), **estate vaults** (one customer's tenant data, private), **operations memory** (in the tenant). Knowledge moves up only by a reviewed PR after it is generalized, and the guard checks every file.
- The repos connect through seven contracts ([contracts.md](../../contracts.md)), each with a schema or a test: evidence packages into the vault; vault harvest; engagement harvest; `avd-sizing-evidence/v1` into calibration; host pool attribution tags; reading the knowledge base at a pinned commit; searchable docs across repos with commit-pinned citations.
- The operations brain's runtime (Bicep module, detections, playbooks, executor, kill switch) stays in avd-landing-zone, because it deploys into the landing zone.
- The repo is public, like the repos it connects. It started **private** and went public on 2026-10-18, at the owner's choice. Anything that must stay private goes to a separate private repo, never here. Its `knowledge/` stays in the `public` scope throughout, so the guard keeps it publishable at any time. Organizations fork it privately for their knowledge; customers keep their vaults in their own private repositories.

### Consequences

- One place to learn the concept, one guard, one set of schemas, and one search across all three repos.
- Contract changes span two repos: the producer's change and this repo's schema and tests move together.
- avd-current-state loses `avd_second_brain.ps1`; users run it from here (`vault/avd_second_brain.ps1`) with the same parameters.
- The landing zone's spec now lives here, while its runtime is built there: links between the two must be kept in sync until the runtime exists.
- While this repo was private, the public repos' links to it didn't resolve for their readers. Their pointer changes (removing the vault from avd-current-state, the spec from avd-landing-zone) were held for this repo to go public, which it did on 2026-10-18.

## More Information

- Narrowed by [0024](0024-the-brain-is-the-estate-brain.md) (2026-10-20): the repo keeps the estate brain and the KB plumbing; the factory knowledge, the foundation contracts and the docs check move to the repos that own them.
- Accepted by the owner on 2026-10-18, when the family knowledge base was set up. Moved here from `docs/decisions/` and converted to MADR 4; the decision itself is unchanged.
