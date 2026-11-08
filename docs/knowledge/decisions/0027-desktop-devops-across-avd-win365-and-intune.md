---
status: accepted
date: 2026-11-02
decision-makers: [owner]
---

# 0027. Desktop DevOps across AVD, Windows 365, and Microsoft Intune

## Context and Problem Statement

Enterprise virtual desktop estates operate across three converged Microsoft surfaces: Azure Virtual Desktop (AVD) in Azure Resource Manager, Windows 365 Cloud PCs in Microsoft Graph (`deviceManagement/virtualEndpoint`), and Microsoft Intune endpoint management (`deviceManagement/*`). Previously, the brain's contracts, knowledge base, and guidance focused on AVD host pools and session hosts, while Windows 365 Cloud PCs and Intune policy-as-code across platforms were only partially modeled. The owner set the goal for `avd-ops`, `avd-swarm`, and `avd-second-brain` as **Desktop DevOps across AVD, Windows 365, and Intune** ([avd-ops 0012](https://github.com/avd-ops/avd-ops/blob/main/docs/knowledge/decisions/0012-desktop-devops-for-avd-win365-and-intune.md)). How should `avd-second-brain` extend its contracts, workload placement reasoning, and knowledge base without crossing repository boundaries?

## Considered Options

- Extend `avd-second-brain` (`C9`, `C10`, `C11`, `C15`, `C19` pins, workload placement guidance, and Intune policy-as-code / Cloud PC operations knowledge) while keeping Windows 365 inside `avd-intune` and `avd-current-state`
- Create a separate Windows 365 brain or sixth control-plane repository
- Keep the brain scoped to AVD ARM resources only

## Decision Outcome

Chosen option: "Extend `avd-second-brain` while keeping Windows 365 inside `avd-intune` and `avd-current-state`", because Windows 365 is native to Microsoft Intune (`deviceManagement/virtualEndpoint`), and unifying AVD, Windows 365, and Intune under one estate brain lets operators reason about workload placement, policy drift, licensing economics, and recovery across both desktop models with zero write credentials in the brain.

1. **Unified foundation contracts (`C11`, `C15`, `C19`).** Pin `avd-assess` contracts carrying 17 new C11 facts (`c11.entra.skuWin365Available`, Intune platform assignment filter facts, and `c11.intune.win365.*` Cloud PC facts) and 2 new C19 intake facts (`avdScope`, `win365Scope`).
2. **Surface-aware playbook proposals (`C9`) and outcomes (`C10`).** Extend `C9` and `C10` with `targetSurface` (`avd | win365 | intune | entra | m365 | power-platform`), `desktopDevOpsAction`, and `dataLossGuard` (`restorePointVerified`, `restorePointAgeHours`, `discardLastCopyApproved`) so destructive actions on session hosts or Cloud PCs enforce [decision 0016](0016-never-delete-the-last-copy.md).
3. **Workload placement and TCO reasoning.** The brain compares concurrency ratio, utilization hours per month, GPU/peripheral requirements, and administrative overhead to recommend AVD Pooled, AVD Personal (with Start VM on Connect), Windows 365 Enterprise, or Windows 365 Frontline per persona (`uc-01` through `uc-07`).
4. **Intune policy-as-code and platform assignment filters.** Every Intune baseline and Settings Catalog profile uses explicit platform assignment filters (`avd-multisession`, `avd-personal`, `win365-cloudpc`, `physical-desktop`) rather than unfiltered "All Devices" assignments. Live tenant drift against `avd-intune` manifests produces a Git PR proposal rather than an unreviewed portal write.

### Consequences

- Good, because one estate brain reasons over AVD session hosts, Windows 365 Cloud PCs, and Intune policy posture from one pseudonymous fact stream (`C11`).
- Good, because `dataLossGuard` extends [decision 0016](0016-never-delete-the-last-copy.md) to Cloud PC reprovisioning and session-host replacement.
- Bad, because foundation contract pins and downstream collectors (`avd-current-state`, `avd-intune`, `avd-entra`, `avd-swarm`) must move together across four phases.

## More Information

- Also recorded in: [avd-ops 0012](https://github.com/avd-ops/avd-ops/blob/main/docs/knowledge/decisions/0012-desktop-devops-for-avd-win365-and-intune.md) and [docs/desktop-devops-spec.md](https://github.com/avd-ops/avd-ops/blob/main/docs/desktop-devops-spec.md).
- Pair: `avd-swarm` specialist agents (`hosts-and-cloudpcs`, `intune-policy`, `cost-and-licensing`), governance gate (`gate/avd_gate/evidence.py`, `gate/avd_gate/apply.py`, `templates/workflows/approve.yml`), and `avd-assess` checks (`asm-intune-assignment-filters-separate-platforms`, `asm-win365-*`).
- Microsoft Learn: [Windows 365 Cloud PC lifecycle](https://learn.microsoft.com/en-us/windows-365/enterprise/device-management-overview), [Assignment filters in Microsoft Intune](https://learn.microsoft.com/en-us/intune/intune-service/fundamentals/filters), [cloudPC Graph resource](https://learn.microsoft.com/en-us/graph/api/resources/cloudpc?view=graph-rest-1.0).

