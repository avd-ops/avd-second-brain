---
title: "Landing zone"
summary: "Bicep, networking, policy, quotas and resource providers for an AVD landing zone, and running it all from Cloud Shell"
topic: landing-zone
status: verified
last_reviewed: 2026-10-20
sources:
  - https://learn.microsoft.com/azure/well-architected/reliability/checklist
  - https://learn.microsoft.com/azure/well-architected/design-guides/implementing-recommendations
  - https://learn.microsoft.com/azure/cloud-adoption-framework/scenarios/azure-virtual-desktop/enterprise-scale-landing-zone
  - https://learn.microsoft.com/azure/virtual-desktop/azure-advisor-recommendations
  - https://learn.microsoft.com/security/benchmark/azure/baselines/azure-virtual-desktop-security-baseline
---

# Landing zone

How an AVD landing zone gets built and kept healthy with Azure-native tooling: Bicep and Azure Verified Modules, networking and private endpoints, vCPU quota, resource providers, and running every step from Azure Cloud Shell. Each rule below came out of a real run of [avd-landing-zone](https://github.com/nickprignano/avd-landing-zone) and links the lesson that holds the detail ([decision 0008](../decisions/0008-learned-knowledge-stays-where-it-happened.md)). The exact errors are in [known errors](../troubleshooting/README.md).

The landing zone's scope is Entra ID only, greenfield and private by default ([avd-landing-zone decision 0001](https://github.com/nickprignano/avd-landing-zone/blob/master/docs/decisions/0001-cloud-native-scope.md)).

## Quota and regions

- New subscriptions start with 0 vCPU quota for most VM families, separate from the regional limit. Check family and regional quota per region before deploying, and request small increases through `Microsoft.Quota` ([lesson 0013](https://github.com/nickprignano/avd-landing-zone/blob/master/docs/lessons/0013-vcpu-quota.md)).
- A quota check after deployment must not count the landing zone's own hosts twice: they are already in `used` ([lesson 0024](https://github.com/nickprignano/avd-landing-zone/blob/master/docs/lessons/0024-quota-counts-deployed-hosts.md)).
- Test in a region without availability zones (North Central US) as well as a zonal one. ARM leaves empty properties out, so a zone list can be missing rather than empty ([lesson 0001](https://github.com/nickprignano/avd-landing-zone/blob/master/docs/lessons/0001-nat-gateway-pip-zones.md), [lesson 0021](https://github.com/nickprignano/avd-landing-zone/blob/master/docs/lessons/0021-arm-omits-empty-properties.md)).
- Latency measured from Cloud Shell says nothing about users: measure from where they are, against endpoints verified to be regional ([lesson 0003](https://github.com/nickprignano/avd-landing-zone/blob/master/docs/lessons/0003-region-latency.md)).

## Resource providers

- `Get-AzResourceProvider -ProviderNamespace` returns one object per region. Read the provider through ARM REST when the cmdlet reshapes data ([lesson 0005](https://github.com/nickprignano/avd-landing-zone/blob/master/docs/lessons/0005-provider-per-region.md)).
- Register through the ARM `register` API, which returns at once, and show progress while waiting. EncryptionAtHost takes effect only after Microsoft.Compute is registered again ([lesson 0006](https://github.com/nickprignano/avd-landing-zone/blob/master/docs/lessons/0006-provider-registration.md)).

## Bicep and Azure Verified Modules

- An AVM module's nested defaults (zones, SKUs, locations) apply when the parent doesn't set them. Compile the template and walk the nested deployments before adopting a module ([lesson 0001](https://github.com/nickprignano/avd-landing-zone/blob/master/docs/lessons/0001-nat-gateway-pip-zones.md)).
- Don't assume where a module puts child resources. Private endpoints land in their target's resource group, so look them up by target ID ([lesson 0010](https://github.com/nickprignano/avd-landing-zone/blob/master/docs/lessons/0010-private-endpoint-rg.md)).
- `readEnvironmentVariable` returns an empty string, not its default, when the variable is set but empty. Guard optional variables with `empty(...)` ([lesson 0004](https://github.com/nickprignano/avd-landing-zone/blob/master/docs/lessons/0004-empty-env-var.md)).
- Keep `bicepconfig.json` strict and fix the cause rather than suppressing a rule ([lesson 0019](https://github.com/nickprignano/avd-landing-zone/blob/master/docs/lessons/0019-bicep-authoring.md)). For PSRule, suppress only with a reason and a narrow selector, and point it at an explicit Bicep binary ([lesson 0018](https://github.com/nickprignano/avd-landing-zone/blob/master/docs/lessons/0018-psrule.md)).
- Ignore build output where it's written, never `*.json` across the repo: a file Bicep loads at compile time must be committed ([lesson 0027](https://github.com/nickprignano/avd-landing-zone/blob/master/docs/lessons/0027-gitignore-json-data-files.md)).

## Scripts that run it

- Give operators self-contained command blocks for Cloud Shell, with no placeholders to fill in. Long operations must survive a disconnect and say how to check on them ([lesson 0015](https://github.com/nickprignano/avd-landing-zone/blob/master/docs/lessons/0015-cloud-shell-ergonomics.md)).
- Anything that can take more than a few seconds prints a line before it starts, and "fixed" means done, not started ([lesson 0006](https://github.com/nickprignano/avd-landing-zone/blob/master/docs/lessons/0006-provider-registration.md)).
- Every loop over remote calls ends on error, including non-terminating errors and empty results ([lesson 0008](https://github.com/nickprignano/avd-landing-zone/blob/master/docs/lessons/0008-non-terminating-loops.md)).
- Check each Az and Graph cmdlet call against its documented parameter sets, and keep mocks no more permissive than the real cmdlet ([lesson 0014](https://github.com/nickprignano/avd-landing-zone/blob/master/docs/lessons/0014-cmdlet-parameter-sets.md)). Emit items from functions instead of returning one array ([lesson 0009](https://github.com/nickprignano/avd-landing-zone/blob/master/docs/lessons/0009-array-unrolling.md)).
- Lint with the PSScriptAnalyzer version CI installs; use approved verbs and singular nouns ([lesson 0016](https://github.com/nickprignano/avd-landing-zone/blob/master/docs/lessons/0016-analyzer-version.md)). Offline tests provide every external tool they touch ([lesson 0020](https://github.com/nickprignano/avd-landing-zone/blob/master/docs/lessons/0020-hermetic-harness.md)).
- Never make a person remember a secret the platform can generate and reset, such as the break-glass password ([lesson 0002](https://github.com/nickprignano/avd-landing-zone/blob/master/docs/lessons/0002-break-glass-password.md)).

## Well-Architected review

The landing zone's own review is an opt-in preflight section that only warns ([avd-landing-zone decision 0009](https://github.com/nickprignano/avd-landing-zone/blob/master/build/decisions/0009-well-architected-review.md)); avd-swarm's proposed chat review in avd-buddy reads its `waf-*` results instead of repeating them and asks the operator only what reads can't show ([avd-swarm waf-review spec](https://github.com/nickprignano/avd-swarm/blob/main/docs/waf-review.md)). Checked on 2026-10-20:

- **Link the pillar checklists and the AVD product docs, not the CAF AVD scenario.** The Cloud Adoption Framework's enterprise-scale AVD article is deprecated and due to be removed on 2026-10-30; Microsoft points to the Architecture Center and the AVD product docs instead ([deprecation notice](https://learn.microsoft.com/azure/cloud-adoption-framework/scenarios/azure-virtual-desktop/enterprise-scale-landing-zone)). Links under `learn.microsoft.com/azure/well-architected/azure-virtual-desktop/` now redirect into the AVD product docs, so a link there can silently land on a different page.
- **The checklists have stable codes.** Each pillar's design review checklist numbers its items (Reliability RE:01 to RE:10, and SE, CO, OE, PE likewise), so a check can cite the code and the link ([Reliability checklist](https://learn.microsoft.com/azure/well-architected/reliability/checklist)).
- **Microsoft's assessment is a questionnaire.** The Azure Well-Architected Review (about 60 questions, with an Azure Virtual Desktop workload variant) adds Advisor recommendations for one subscription or resource group only, keeps milestones per Learn profile, and exports recommendations as CSV for a backlog ([completing an assessment](https://learn.microsoft.com/azure/well-architected/design-guides/implementing-recommendations)).
- **Advisor refreshes about twice a day**, so a fix shows up in its recommendations hours later; don't dismiss the recommendation by hand to make it go away ([AVD Advisor recommendations](https://learn.microsoft.com/azure/virtual-desktop/azure-advisor-recommendations)).
- **The AVD security baseline is on MCSB v1.0** and may be out of date; Defender for Cloud's regulatory compliance view tracks the current benchmark, so read posture there ([baseline](https://learn.microsoft.com/security/benchmark/azure/baselines/azure-virtual-desktop-security-baseline)).
