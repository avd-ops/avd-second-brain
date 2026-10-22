---
title: "Knowledge base"
summary: "What this knowledge base is, how it's organized, and how to add to it safely"
topic: overview
status: verified
last_reviewed: 2026-10-18
---

# Knowledge base

What we've learned delivering Azure Virtual Desktop across its lifecycle, from assessing an estate
to deploying and operating it with Azure-native tooling: research findings, gotchas, fixes with
versions, and the decisions behind them. It's written for people, tools and LLM agents alike, and
it's one of a family of knowledge bases that share one format.

This is a living document set. When something new is learned, add it to the topic page it
belongs to instead of starting a new file. Lessons from a real run stay in the repo where they
happened (avd-landing-zone's `docs/lessons/`, for example); the topic pages here summarize and
link them.

The engine's data (app catalog, rules, sizing calibration) is a separate layer in
[`knowledge/`](../../knowledge/README.md); see [curation.md](curation.md#how-this-fits-the-rest-of-the-brain).

## Index

<!-- BEGIN GENERATED: kb-index (from front matter; run scripts/kb/build.py) -->
| Page | What's in it | Status |
|---|---|---|
| [landing-zone/](landing-zone/README.md) | Bicep, networking, policy, quotas and resource providers for an AVD landing zone, and running it all from Cloud Shell | verified |
| [identity/](identity/README.md) | Entra ID joined hosts, Entra Kerberos, Microsoft Graph sign-in for operators, unattended read identities, and agent identities | partial |
| [fslogix/](fslogix/README.md) | FSLogix profile containers on Azure Files with Entra Kerberos: share setup, SMB settings, permissions and what breaks | verified |
| [images/](images/README.md) | Golden images for session hosts: Azure Image Builder, the Windows Desktop Optimization Tool, the gallery and promotion | partial |
| [assessment/](assessment/README.md) | How the AVD repos assess an estate and size host pools: the app catalog, workload tiers, sizing calibration and measured evidence | plan |
| [operations/](operations/README.md) | Day-2 operations: detections, playbooks, episodes, and the handoff to avd-swarm for anything that changes an estate | partial |
| [agents/](agents/README.md) | How the AVD repos use Claude: the brain's agents, avd-swarm's agents, model access and their identities | partial |
| [cost/](cost/README.md) | Estimating, pricing and capping AVD and sandbox spend: the retail price API, auto shutdown and run-cost evidence | partial |
| [microsoft/drafts/](microsoft/drafts/README.md) | Where an upstream issue, docs fix or pull request is drafted and reviewed before a person files it | plan |
| [microsoft/upstream-contributions.md](microsoft/upstream-contributions.md) | Gaps, API asks and doc fixes we could raise with Microsoft, with evidence | verified |
| [troubleshooting/](troubleshooting/README.md) | Errors hit deploying and running AVD: symptom, cause, fix and source | verified |
| [landing-zone/terraform-port-plan.md](landing-zone/terraform-port-plan.md) | Plan to port nerdio-hcl's approach to Terraform that deploys and operates AVD directly, with no Nerdio Manager in the path; awaits the owner's yes | plan |
| [roadmap.md](roadmap.md) | Settled: this KB is on the family format; open work is tracked outside the public repo | plan |
| [curation.md](curation.md) | How the KB stays current: the weekly digest, the prior-art check, the feedback loop, the freshness check and family alignment | verified |
| [experts.md](experts.md) | How we choose which AVD, FSLogix and Entra experts the KB follows: the method, the scores and the list | verified |
| [decisions/](decisions/README.md) | Decision records (MADR): what was decided and why |  |
<!-- END GENERATED: kb-index -->

## Related knowledge bases

<!-- BEGIN GENERATED: family (from family.yaml; run scripts/kb/build.py) -->
| Knowledge base | Role | Focus | Source of truth for |
|---|---|---|---|
| [2ndbrain](https://github.com/nickprignano/2ndbrain/tree/main/docs/knowledge) | reference | The template that owns the family knowledge base format | the family knowledge base format; its scripts and schemas |
| [avd-ops](https://github.com/avd-ops/avd-ops/tree/main/docs/knowledge) | member | The front door for the AVD repos: avd-ops.dev, onboarding and user docs | onboarding and user-facing docs for the AVD repos; the avd-ops.dev site and design system |
| [Nerdio HCL kit](https://github.com/nickprignano/nerdio-hcl/tree/main/docs/knowledge) | member | Related project, separate from avd-ops: Nerdio Manager on Azure Virtual Desktop, deployed with Terraform and Packer | Nerdio Manager; the nerdio/nme provider; this kit's Terraform and Packer |
| [Liquidware](https://github.com/nickprignano/avd-liquidware/tree/main/docs/knowledge) | member | Liquidware products on virtual desktops, starting with Stratusphere UX in Azure | Liquidware products; Stratusphere UX appliances; the Connector ID Key; the Stratusphere API; this repo's Bicep and PowerShell |
<!-- END GENERATED: family -->

When a fact belongs to a sibling's topic, link to their page instead of copying it. When we learn
something they need, open an issue or PR on their repo with the evidence. See
[curation.md](curation.md#staying-aligned-with-the-family).

### Not built here

Work in another project's lane is referred to that project, not built here, and its KB is read
before anything near it is researched here ([decision 0012](decisions/0012-family-format-project-lanes.md)).

<!-- BEGIN GENERATED: lanes (from family.yaml; run scripts/kb/build.py) -->
- Terraform, Packer, OpenTofu or any other HCL. The AVD repos use Bicep, PowerShell and native Azure, Entra and Microsoft 365 tooling only: [Nerdio HCL kit](https://github.com/nickprignano/nerdio-hcl/tree/main/docs/knowledge), the Nerdio Claude project
- Nerdio Manager, its provider and scripted actions: [Nerdio HCL kit](https://github.com/nickprignano/nerdio-hcl/tree/main/docs/knowledge), the Nerdio Claude project
- Liquidware products (ProfileUnity, FlexApp, Stratusphere, CommandCTRL). Their deployment tooling is built in avd-liquidware, never in avd-landing-zone; real-user assessments stay in the Liquidware project: [Liquidware](https://github.com/nickprignano/avd-liquidware/tree/main/docs/knowledge), the Liquidware Claude project
<!-- END GENERATED: lanes -->

## Before you build something

Every change follows the [guardrails](../guardrails.md): no leaks, no secrets in chat, pull
requests only, and license rules.

Run the prior-art check first (`python3 scripts/kb/prior_art.py "<topic>"`, see
[curation.md](curation.md#prior-art-check-kb-prior-art)). It searches this KB, the sibling KBs and
GitHub, so you don't spend time on problems someone has already solved.

## How to add to it

Two ways in, both reviewed before anything merges:

- **Without editing files:** open a **Knowledge base feedback** issue (what worked, broke, went
  out of date or is missing), a **Known error** issue, or a **Suggest an expert to follow** issue.
  When a maintainer labels it `kb-accepted`, a workflow turns it into a pull request. See
  [curation.md](curation.md#feedback-loop-kb-feedback).
- **With a pull request:**
  - **A fact or gotcha:** add a bullet to the matching topic page. Say what happened, the fix,
    and the versions it applies to. Mark anything you haven't confirmed as *unverified*.
  - **Link upstream, don't restate it.** Microsoft Learn, the product's own repo and vendor docs
    are the source of truth for what a product is documented to do. Link the page a fact builds
    on, and write only what it doesn't say: a gap, a contradiction from a real run, or how the
    pieces combine. When a run contradicts the docs, keep the finding, link both, and add an
    upstream ask ([decision 0011](decisions/0011-family-format-upstream-sources.md)).
  - **A known error or an upstream ask:** add an entry to
    [troubleshooting/known-errors.yaml](troubleshooting/known-errors.yaml) or
    [microsoft/upstream.yaml](microsoft/upstream.yaml), not to the Markdown table.
  - **A decision:** copy [decisions/template.md](decisions/template.md) to the next number. A
    decision stays `proposed` until the maintainer says yes. If a decision is reversed, write a new
    record and set the old one's status to `superseded by NNNN`. Refer to a sibling's decision as
    `<project> 0012`, with a link.
  - **A new topic:** only when it doesn't fit an existing page. Give it front matter like the
    other pages; the index above picks it up.
  - When you change or re-check a page, update `last_reviewed` in its front matter, and `status`
    if it changed.
  - Run `python3 scripts/kb/build.py` and `python3 scripts/kb/validate.py` before pushing (see
    [Format](#format) for setup). CI runs both.

## Format

The KB uses open, common formats so people, tools and LLM agents can all read it. The format is
shared by every KB in the family, and this KB follows family format version 1.

- **Page front matter (YAML)** on every page: `title` (the same as the H1), `summary`, `topic`,
  `status` (`verified`, `partial`, `unverified` or `plan`) and `last_reviewed`, validated against
  [schema/page.schema.json](schema/page.schema.json).
- **Decision records in [MADR 4](https://adr.github.io/madr/) format,** with `status`, `date` and
  `decision-makers` in front matter ([schema/decision.schema.json](schema/decision.schema.json)).
- **Structured YAML** for the [known errors](troubleshooting/known-errors.yaml),
  [upstream asks](microsoft/upstream.yaml), [field reports](field-reports.yaml),
  [experts](experts.yaml) and the [family](family.yaml), each with a JSON Schema in
  [schema/](schema/page.schema.json). The Markdown tables are generated from them.
- **[`llms.txt`](../../llms.txt)** at the repo root, the [llms.txt](https://llmstxt.org) index that
  tells LLMs and agents what's here. It's generated too.

Generated parts sit between `BEGIN GENERATED` / `END GENERATED` comments; edit the source, not
the output. The scripts need Python 3.11+ with PyYAML and jsonschema:

```bash
pip install --user -r scripts/kb/requirements.txt
python3 scripts/kb/build.py && python3 scripts/kb/validate.py
```

## Keep it public-safe

This repo is public, so nothing here may identify a real tenant, customer or estate. Before
committing, check that your change has none of the following:

- Tenant, subscription, object, client or resource IDs, or secrets of any kind
- Domain names, email addresses, hostnames, UNC paths or storage account names
- IP ranges from a real network (use RFC 5737 documentation ranges or `10.x` examples)
- Data from a customer's estate: inventories, user or machine names, line-of-business apps
- Employer, customer or tenant names

Use placeholders such as `<tenant-id>`, `<storage-account>`, `contoso.com` and `10.x`. Write lessons
as general advice, not as a story about a specific estate. Published identifiers that are the same
for everyone, such as built-in role IDs and first-party app IDs, are fine. CI enforces what it can:
`validate.py`, the brain's leak guard and gitleaks.

### If something private is already public

A removal PR fixes the current files, not what GitHub keeps. Checked 2026-10-21 in a sweep of the
five public AVD repos:

- Old commits stay reachable after a removal PR, and after a history rewrite too: through pull
  request refs, cached commit views by SHA, forks and clones. Only GitHub Support can purge the PR
  refs and cached views, after the rewrite is force-pushed, and only when rotating a secret can't
  cover the risk ([removing sensitive data](https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/removing-sensitive-data-from-a-repository)).
  So a rewrite is worth its cost only for a real secret or a customer's data, and a secret is
  rotated first either way.
- Editing a PR description, issue or comment leaves the old text in its edit history, which anyone
  who can read the repo can open. The author or anyone with write access deletes the revision from
  the "edited" menu ([tracking changes in a comment](https://docs.github.com/en/communities/moderating-comments-and-conversations/tracking-changes-in-a-comment)).
- Look beyond the default branch: every branch and `refs/pull/*`, PR and issue bodies and comments,
  commit author emails, and pages generated from a sibling repo (such as the brain's wiki), which
  keep a copy until they are regenerated.
