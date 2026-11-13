---
status: proposed
date: 2026-11-13
decision-makers: [owner]
---

# 0028. Position Terraform (avd-hcl) as the enterprise IaC option alongside Bicep

## Context and Problem Statement

The `avd-ops` family deploys native Azure Virtual Desktop with Bicep and PowerShell in `avd-landing-zone` and `avd-azure`, while `avd-hcl` (now public) implements native AVD with Terraform and Packer. For enterprise platform teams, Terraform is the stronger IaC option: it manages Azure alongside Entra ID, GitHub, DNS, monitoring, and multi-cloud or SaaS providers in a single dependency graph; tracks explicit state for deterministic `plan` diffs, clean resource deletion, and `moved` refactoring; and standardizes on HCL and mature policy-as-code tooling. However, `avd-second-brain`, `avd-ops`, and `avd-assess` either assumed Bicep was the only IaC path or omitted `avd-hcl` from the family inventory. How should the family position Terraform relative to Bicep?

## Considered Options

- Keep Bicep as the only documented IaC path and leave `avd-hcl` unreferenced across the family
- Position Terraform (`avd-hcl`) as the recommended enterprise IaC option alongside Bicep (`avd-landing-zone` / `avd-azure`), keeping each repo in its own toolchain lane
- Replace Bicep with Terraform inside `avd-landing-zone` and `avd-azure`

## Decision Outcome

Chosen option: "Position Terraform (`avd-hcl`) as the recommended enterprise IaC option alongside Bicep (`avd-landing-zone` / `avd-azure`), keeping each repo in its own toolchain lane", because enterprise estates benefit from Terraform's cross-provider orchestration, explicit state lifecycle, and `plan` fidelity without breaking the zero-state, Bicep-native `avd-landing-zone` and `avd-current-state` pair.

- **Enterprise recommendation:** Recommend Terraform (`avd-hcl`) when an organization wants multi-provider orchestration, explicit state and deletion tracking, `moved` refactoring, or already standardizes on HCL.
- **Zero-state Azure-native path:** Keep `avd-landing-zone` and `avd-azure` (Bicep + PowerShell) for Azure-only teams that want zero state-file management and Day-0 ARM API support.
- **Lane discipline:** Keep Bicep repos Bicep/PowerShell-only (`0012`); Terraform and Packer code stays in `avd-hcl`.
- **Family visibility:** Register `avd-hcl` in `avd-ops` (`repos.json` and `avd-ops.dev`), `avd-assess`, and sibling `AGENTS.md` family lists.

### Consequences

- Good, because enterprise teams evaluating `avd-ops` see a first-class Terraform + Packer path with clear selection criteria.
- Good, because existing Bicep templates, CI guards, and Cloud Shell workflows in `avd-landing-zone` and `avd-azure` remain untouched.
- Bad, because two IaC implementations (`avd-azure` in Bicep and `avd-hcl` in Terraform) must stay aligned on the same `avd-assess` standards and topology contracts.

## More Information

- Also recorded in `avd-ops` as decision 0014.
- Prior context: [avd-hcl decision 0001](https://github.com/avd-ops/avd-hcl/blob/main/docs/knowledge/decisions/0001-native-avd-with-the-hashicorp-stack.md) and [decision 0012](0012-family-format-project-lanes.md).
