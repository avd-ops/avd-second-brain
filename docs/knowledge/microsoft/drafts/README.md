---
title: "Upstream drafts"
summary: "Where an upstream issue, docs fix or pull request is drafted and reviewed before a person files it"
topic: microsoft
status: plan
last_reviewed: 2026-10-19
---

# Upstream drafts

Before an entry in [upstream.yaml](../upstream.yaml) is raised, its text is drafted here as
`<id>.md`, with the same `id` as the entry, and reviewed in a pull request like any other change.
The target can be Microsoft (a Learn page's feedback or its docs repo, a product repo such as
Azure/bicep-registry-modules) or another upstream, such as the Windows Desktop Optimization Tool.
A sibling KB in the family gets an issue or pull request on its own repo instead
([curation.md](../../curation.md#staying-aligned-with-the-family)).

## Rules

- **A person files it.** A draft is reviewed here, then a person files it upstream under their
  own account and records the link and `status: raised` in [upstream.yaml](../upstream.yaml). No
  agent files anything outside the connected repos
  ([decision 0011](../../decisions/0011-family-format-upstream-sources.md)).
- **Nothing from an estate.** Generic reproduction steps only: no tenant, subscription or resource
  IDs, domains, hostnames, user or machine names, secrets, or employer or customer names
  ([guardrails](../../../guardrails.md)). Use `<tenant-id>`, contoso.com and `10.x`.
- **Their rules, not ours.** Read the upstream's CONTRIBUTING file, license and CLA first, and
  write the draft in their template.
- **Evidence travels with it.** Link the public lesson or known error the ask came from, and say
  which upstream page or version it was checked against.
- **After it's filed,** keep the draft until upstream closes it, then delete it; the entry in
  `upstream.yaml` keeps the link and the outcome.

No drafts yet.
