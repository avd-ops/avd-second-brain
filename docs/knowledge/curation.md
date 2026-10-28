---
title: "Keeping the knowledge base current"
summary: "How the KB stays current: the weekly digest, the prior-art check, the feedback loop, the freshness check and family alignment"
topic: curation
status: verified
last_reviewed: 2026-10-21
---

# Keeping the knowledge base current

Four tools keep the KB current without spending time (or LLM tokens) rediscovering things. Two
bring new information in (the weekly digest and the prior-art check), and two check that what's
already here still holds (the feedback loop and the monthly freshness check). A fifth part keeps
this KB aligned with its siblings.

## Weekly digest (`kb-curator`)

[`.github/workflows/kb-curator.yml`](../../.github/workflows/kb-curator.yml) runs every Monday.
It reads [sources.toml](sources.toml), collects anything new from the last 8 days and opens an
issue labelled **kb-digest** with a checklist grouped by source. Each source names the KB page its
findings belong on. Items whose URL is already linked from the KB are left out. If nothing is new,
no issue is opened.

Watched today:

- Microsoft: the AVD Landing Zone Accelerator, the Azure Verified Modules for desktop
  virtualization, Bicep, the Image Builder API release notes, the Windows Desktop Optimization Tool
  and the Microsoft Graph PowerShell SDK
- The Azure Virtual Desktop and FSLogix blogs, and Azure updates filtered to AVD topics
- New GitHub repos on AVD with Bicep, and on FSLogix with Kerberos
- The connected AVD repos: avd-landing-zone's lessons and decisions, avd-swarm's decisions and
  avd-current-state's changes, so the topic pages can link new lessons where they happened
- The sibling KBs' decisions and other changes (see [Staying aligned](#staying-aligned-with-the-family))

Expert feeds come with the experts study: people are chosen with the method in
[experts.md](experts.md), and each feed is added once a curator run shows it works.

Working a digest: tick the items worth adding (a `→ docs/knowledge/<page>.md` at the end of an
item's line sends it to another page than its source's), then label the issue **kb-accepted**.
[kb-feedback](#feedback-loop-kb-feedback) adds each ticked item to its page under "From the
digest", marked *unverified*, and opens a pull request that closes the digest. Before merging, turn
each link into what matters (facts, versions, fixes; not a link dump) with a primary source, and
drop its marker. Or write it up by hand in your own PR with `Closes #<digest>`.

A new digest closes the older open ones nobody ticked anything in, with a link to the new one, so
unworked digests don't pile up. A digest with ticks stays open until it's accepted or closed by hand.
Commit sources leave out merge commits and dependency bumps. A feed or API that answers 5xx gets
one retry after a short wait before it counts as failed for that run.

To watch something else, add a `[[source]]` table to [sources.toml](sources.toml). Supported
kinds: `github_releases`, `github_commits` (optionally limited to one `path`), `github_issues`,
`github_org_repos`, `github_user_repos`, `github_search`, `feed`
(RSS/Atom, with optional `keywords`) and `zendesk`. Run it locally with:

```bash
GITHUB_TOKEN=$(gh auth token) python3 scripts/kb/curate.py --since-days 30
```

A source that fails (rate limit, site down) is listed at the bottom of the digest and doesn't
stop the others.

## Prior-art check (`kb-prior-art`)

Before building something new, check whether it's already solved:

```bash
GITHUB_TOKEN=$(gh auth token) python3 scripts/kb/prior_art.py "fslogix entra kerberos"
```

or run **Actions > kb-prior-art** with the topic (one topic per line for several). It searches, in
order: this KB, each sibling KB in [family.yaml](family.yaml), GitHub repositories, PowerShell and
Bicep code, and issues and pull requests. If something useful turns up, record it on the relevant
topic page, so the next person doesn't search again.

From a build container, GitHub search answers HTTP 403 even with full network access (seen
2026-10-20 and 2026-10-21), so a session there can't run the script itself. It dispatches
**kb-prior-art** instead and reads the run's log or its `prior-art` artifact, which holds one
Markdown report per topic. The workflow is read-only. Until 2026-10-21 it failed at import because
it skipped `pip install -r scripts/kb/requirements.txt` (`kblib` needs PyYAML). Code search allows about 10 calls a
minute and each topic makes several, so the script waits and retries on a rate limit (429, or a 403
that says the limit is spent); any other 403 fails at once.

The digest and prior-art scripts need Python 3.11+ and `scripts/kb/requirements.txt`.

## Feedback loop (`kb-feedback`)

Real results flow back into the KB through three issue forms, and the weekly digest:

- **Knowledge base feedback:** what worked, broke, went out of date or is missing, for one page
  (label `kb-feedback`).
- **Known error:** an error, its cause and fix, for the [troubleshooting catalog](troubleshooting/README.md)
  (label `kb-known-error`).
- **Suggest an expert to follow:** a nomination for the [experts study](experts.md) (label `kb-source`).
- **A weekly digest** with ticked items (label `kb-digest`, see [above](#weekly-digest-kb-curator)).

Each form has a required public-safe tick box. A maintainer reviews the issue and, if it's useful
and public-safe, labels it **kb-accepted**.
[`.github/workflows/kb-feedback.yml`](../../.github/workflows/kb-feedback.yml) then appends it to
[field-reports.yaml](field-reports.yaml), [known-errors.yaml](troubleshooting/known-errors.yaml) or
[experts.yaml](experts.yaml), regenerates and validates the KB, and opens a pull request that closes
the issue. If the form is incomplete or fails validation, the workflow comments on the issue instead.

The label is the safety gate: issue text from anyone is only parsed as data, never executed, the PR
still goes through review, and gitleaks and the KB checks run on it. Two one-time settings matter:

- Run **Actions > kb-freshness** once so the `kb-*` labels exist (issue forms only apply labels
  that already exist).
- Turn on **Settings > Actions > General > Allow GitHub Actions to create and approve pull
  requests**. Without it, the workflow pushes the branch and asks you to open the PR.

Pull requests opened by the workflow's own token don't start other workflows. The job runs the KB
checks itself; close and reopen the PR to run the full CI before merging.

## Freshness check (`kb-freshness`)

[`.github/workflows/kb-freshness.yml`](../../.github/workflows/kb-freshness.yml) runs on the 1st
of each month and keeps one open issue labelled **kb-freshness** listing:

- pages reported broken or outdated in field reports that aren't marked `resolved` yet
- pages whose `last_reviewed` is more than 90 days old (pages with status `plan` are skipped)
- pages with status `unverified` or `partial`, with the number of claims still marked *unverified*
- known errors whose fix is still unverified
- experts due for re-scoring, with each tracked expert's digest yield (counted only over digests
  opened since the expert was last scored, so a new KB or a new expert isn't flagged before any
  digest could list them)
- sibling KBs on a different family format version, or whose `family.yaml` can't be read

When the check comes back clean it closes the open issue instead of leaving it for next month.
Work it by re-checking each item against a primary source or a real run, then updating the page's
text, `last_reviewed` and `status`. Run it locally with `python3 scripts/kb/freshness.py --family`.

## Staying aligned with the family

[family.yaml](family.yaml) lists every KB in the family, this one included (`self: true`): its
repo, KB path, role, focus, what it's the source of truth for (`owns`) and the family format version.
2ndbrain is the format's reference (see [where the family format comes from](#where-the-family-format-comes-from)).
A sibling without a `repo` isn't linked yet. `build.py` turns the file into the
"Related knowledge bases" table in the [KB README](README.md#related-knowledge-bases) and a section
in `llms.txt`. The schema and the family code in `scripts/kb/` are the same in every KB.

- **Watch each other.** Each set-up sibling gets two `github_commits` sources in
  [sources.toml](sources.toml): one with `path` set to its decisions folder, and one with `path` set
  to its KB folder. `validate.py` fails if either is missing for a sibling with a `repo`. A private sibling can't be read with
  the built-in token; its sources stay in and start working once the repo is public.
- **Stay in your lane** ([decision 0012](decisions/0012-family-format-project-lanes.md)). Each
  row can name its `claude_project` and, on this KB's own row, the work it never does
  (`not_here`, with the owning project, `keywords` and `files` globs). An ask in a `not_here` lane is
  referred to the owner, not built. `prior_art.py` prints the owner first when a query matches a
  lane's keywords; `validate.py` fails on a tracked file matching a lane's `files`; the freshness
  check flags rows that disagree between two KBs and topics both claim to own.
- **Link instead of copying.** When a fact belongs to a sibling's topic, link to their page. When we
  learn something they need, open an issue or PR on their repo with the evidence. If two KBs
  disagree, the one closer to the topic is the source of truth, and the other links to it.
- **Share the format, not the content.** The schemas, scripts, checks, workflows and guardrails stay
  the same in every KB. To change them, write a proposed decision titled "Family format: ..." in
  one KB, open the same change in the others, and bump `format_version` in every `family.yaml` once
  all of them have merged. The freshness check flags a sibling whose version differs.
- **Cross-project decisions.** A decision that affects more than one project is recorded in each
  affected KB, and each copy says "Also recorded in ..." with links.

## Where the family format comes from

- **2ndbrain is the template and the format reference.** The public template repo
  [nickprignano/2ndbrain](https://github.com/nickprignano/2ndbrain) owns the family knowledge base
  format, its scripts and its schemas (the `reference` row in [family.yaml](family.yaml)). The KB
  tooling here is adapted from it under Apache-2.0 ([scripts/kb/NOTICE](../../scripts/kb/NOTICE)),
  and this KB watches its decisions and KB folders in [sources.toml](sources.toml).
- **The lanes extension is local.** The `claude_project`, `builds_in` and `not_here` fields and
  their checks ([decision 0012](decisions/0012-family-format-project-lanes.md)) are this KB's own
  extension of the format, kept when the scripts are re-ported from 2ndbrain.
- **nerdio-hcl is related, not family.** It is a separate project. Its row stays so the lanes can
  refer Terraform, Packer, HCL and Nerdio asks to it and its prior art can be linked, but it is not
  the format source and the AVD repos never depend on it.
- **avd-ops is the front door.** [avd-ops](https://avd-ops.dev/)
  ([avd-ops/avd-ops](https://github.com/avd-ops/avd-ops)) is the brand in front of every
  public AVD repo and holds the onboarding and user-facing docs; this KB keeps the facts, gotchas
  and decisions behind them. Each AVD repo's README says so in one line under its title.

## Upstream: link out, check against, give back

This KB is not a second copy of Microsoft Learn or a product's docs
([decision 0011](decisions/0011-family-format-upstream-sources.md)). The upstream set is Microsoft
Learn plus the repos watched in [sources.toml](sources.toml).

- **Link out.** A topic page links the upstream page each fact builds on and adds only what
  upstream doesn't say. Upstream wins on what a product is documented to do; a real run wins on
  what it did.
- **Check against it.** The weekly digest reports upstream changes from `sources.toml`; when one
  touches a page, re-check the page and update `last_reviewed`. A page is `verified` only when its
  claims about documented behavior link the source they were checked against. Proposed for format
  v2: an `upstream:` front matter list that the freshness check compares with each source's own
  last-changed date.
- **Give back.** When a run shows a gap or a docs error, add an entry to
  [microsoft/upstream.yaml](microsoft/upstream.yaml), draft it in
  [microsoft/drafts/](microsoft/drafts/README.md), and have a person review and file it. No agent
  posts outside the connected repos, and nothing from an estate goes upstream.

## How this fits the rest of the brain

The brain has two knowledge layers, and they're kept apart on purpose:

- **`docs/knowledge/` (this KB)** is written for people and agents: topic pages, known errors,
  upstream asks, experts and decisions, in the family format. Python checks it.
- **[`knowledge/`](../../knowledge/README.md)** is the engine's data: the app catalog, versioned
  rules, sizing calibration and engagement records, in JSON. `scripts/Test-Knowledge.ps1` checks it,
  and other repos read it at a pinned commit (contract C6 in [contracts.md](../contracts.md)).

`scripts/Find-BrainKnowledge.ps1` searches both, plus the connected repos, and cites a commit for
each hit. The brain's leak guard (`scripts/Test-KbLeaks.ps1`) also scans this KB for GUIDs, UNC
paths, machine names and denylisted customer names, which `validate.py` doesn't check.

## Checks on every change (`kb-validate`)

[`.github/workflows/kb-validate.yml`](../../.github/workflows/kb-validate.yml) runs on pull
requests that touch the KB. It runs `validate.py` (front matter and YAML against the
[schemas](schema/page.schema.json), MADR sections, duplicate ids, KB paths the data references,
links and anchors, email and public-IP patterns, and the family checks), checks the generated
tables and `llms.txt` are up to date (`build.py --check`), runs the KB scripts' unit tests, and runs
the brain's leak guard over this KB (`scripts/Test-KbLeaks.ps1`).
Secrets are caught by gitleaks in [`secrets.yml`](../../.github/workflows/secrets.yml), on every PR.
