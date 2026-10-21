---
status: proposed
date: 2026-10-21
decision-makers: [owner]
---

# 0025. An AVD-native Terraform kit lives in its own HCL-lane repo, beside the landing zone

## Context and Problem Statement

The owner wants the approach of [nerdio-hcl](https://github.com/nickprignano/nerdio-hcl)
(chat-first phases, one parameter schema, keyless gated pipeline, read-only readiness, Cloud Shell
first) ported to Terraform that deploys and operates Azure Virtual Desktop directly, with no
Nerdio Manager in the path. The family's lanes ([0012](0012-family-format-project-lanes.md))
forbid HCL in every AVD repo, and avd-landing-zone already deploys AVD in Bicep. Where does an
AVD-native Terraform kit live, and how does it relate to the landing zone?

## Considered Options

- A new public sibling repo in the HCL lane, reading the same contracts as the landing zone
- Amend 0012 to allow HCL in one named AVD repo, as a parallel option to the Bicep landing zone
- A parameter schema shared by the landing zone and the kit
- Don't build it; point Terraform users at existing open-source modules

## Decision Outcome

Proposed: "A new public sibling repo in the HCL lane", because it keeps every AVD repo free of
HCL and every guard unchanged, and it keeps avd-landing-zone and avd-current-state a
self-contained pair that never depends on the kit. The kit reads the target-state manifest (C14)
with its own capability list, and avd-current-state can check what it builds, read-only. Name,
owner account and the Claude project that builds it are open. The plan, with what maps, what is
redesigned, what is new and the phased order, is
[landing-zone/terraform-port-plan.md](../landing-zone/terraform-port-plan.md).

### Consequences

- Good, because no lane file, guard or AVD repo changes to make room for HCL.
- Good, because the landing zone's lessons carry over as tests in the kit, by link.
- Bad, because two engines describe the same estate shape, so a design change in one is a
  question for the other.
- Bad, because family.yaml in each KB needs a row and a lane for the new repo.
- Neutral, because Terraform users with Nerdio keep using nerdio-hcl; the new kit has no Nerdio
  dependency.

## More Information

Status stays proposed until the owner answers the plan's open questions 1 and 2. If the owner
chooses to amend 0012 instead, this record is rewritten to that option before it is accepted.
Source read: nerdio-hcl at commit `75f59bc`, Apache-2.0; any reused file keeps its header and a
NOTICE line.
