---
status: proposed
date: 2026-10-19
decision-makers: [owner]
---

# 0011. Family format: link to upstream sources of truth, check against them, and give back

## Context and Problem Statement

Microsoft Learn, the product repos (the AVD Landing Zone Accelerator, Azure Verified Modules,
Bicep, the Windows Desktop Optimization Tool) and vendor docs are the sources of truth for what a
product is documented to do. The KBs in the family must not become a second copy of them: a
paraphrase goes stale the day the original changes, and nothing tells us it did. On 2026-10-19 no
topic page in this KB linked a Microsoft Learn page; every "verified" page was verified against a
real run, but none said which documented behavior the run confirmed, extended or contradicted. The
format also has a place for asks to Microsoft (`upstream.yaml`) but no path from an ask to a filed
issue or pull request, and nothing for upstreams that aren't Microsoft. How should the shared
format link out, check against and contribute to upstream sources?

## Considered Options

- Keep format v1; each KB links upstream as it sees fit
- A writing rule only, in each KB's README and curation page
- A writing rule now, plus a front matter field, a freshness check and a contribution path in the
  next format version

## Decision Outcome

Chosen option: "A writing rule now, plus a front matter field, a freshness check and a
contribution path in the next format version", because a rule nobody checks drifts, and the check
needs no model and no new service.

**Now, in format v1 (this KB, no code change):**

- **Link, don't restate.** A page states only what upstream doesn't: a gap, a contradiction found
  in a real run, or how documented pieces combine. For everything else it links the upstream page.
  A sibling KB's topic still gets a link to the sibling (decision 0006), and an upstream topic gets
  a link to upstream.
- **Who wins.** Upstream is the source of truth for what a product is documented to do. A real run
  is the source of truth for what it did (P1 in [knowledge-spec.md](../../knowledge-spec.md)). When
  they disagree, the page keeps the finding, links both, and the disagreement becomes an entry in
  [upstream.yaml](../microsoft/upstream.yaml).
- **Verified means checked against both.** A page is `verified` when its claims were checked
  against a primary source or a real run, and every claim about documented behavior links that
  source.
- **Giving back is a person's act.** Candidates go in `upstream.yaml`; a draft goes in
  [microsoft/drafts/](../microsoft/drafts/README.md); a person reviews it, checks it holds no
  customer data, secrets or identifiers (the [guardrails](../../guardrails.md)), follows the
  upstream's own contributing rules, files it under their own account and records the link. No
  agent, avd-swarm's Scribe and Improve included, opens an issue or pull request outside the
  connected repos.

**Proposed for format v2, in all four KBs:**

- **`upstream:` in page front matter:** a list of `https://` URLs the page builds on. `validate.py`
  checks the field's shape. `freshness.py` lists `verified` pages with no `upstream` entry, and
  pages whose upstream changed after their `last_reviewed`: for a GitHub file, its last commit
  date; for a Microsoft Learn page, its `ms.date` or `updated_at` metadata. Warnings, never
  failures, because upstream sites are slow and change their markup (P6).
- **`upstream.yaml` covers any upstream:** an optional `target` (the repo, docs set or product team
  it goes to), a `drafted` status between `candidate` and `raised`, and an optional `draft` path to
  the draft page. The file and its page move from `microsoft/` to `upstream/` in each KB.

### Consequences

- Good, because a page that links its source tells the reader where the full, current answer is,
  and the freshness check tells us when that answer changes.
- Good, because what we learn the hard way has a route back to the people who can fix the product
  or the docs.
- Bad, because the freshness check fetches pages outside GitHub, so it runs only in the monthly job,
  never at PR time, and some networks block it.
- Neutral, because the v2 part is a proposal: nothing changes in the shared code until the other
  three KBs accept it.

## More Information

- Proposed to the family per [curation.md](../curation.md#staying-aligned-with-the-family). The
  rule also lands in [docs-spec.md](../../docs-spec.md) section 4 (who wins), and avd-swarm spec
  section 6e records that Scribe links out and never files upstream.
- The default upstream set is Microsoft Learn plus the repos already watched in
  [sources.toml](../sources.toml).
