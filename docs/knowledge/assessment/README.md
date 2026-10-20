---
title: "Assessment and sizing"
summary: "How the AVD repos assess an estate and size host pools: the app catalog, workload tiers, sizing calibration and measured evidence"
topic: assessment
status: plan
last_reviewed: 2026-10-20
---

# Assessment and sizing

How an estate is assessed and sized before and after a migration: the app catalog, workload tiers, the quality gate, sizing calibration from measured evidence, and how the current-state and forensic facts feed it. The engine's data lives in [`knowledge/`](../../../knowledge/README.md) and its design in [knowledge-spec.md](../../knowledge-spec.md). Facts about Liquidware Stratusphere itself belong to the Liquidware knowledge base. 

## Where it lives today

- [The knowledge base spec](../../knowledge-spec.md): catalog, rules, calibration and the harvest
- [Contracts C4, C11 and C12](../../contracts.md): sizing evidence, current-state facts and forensic facts
- [avd-assess spec](../../assess-spec.md) (draft): the free baseline assessment, a method as data over C11 facts and intake

## Upstream sources for a baseline assessment

Checked 2026-10-20. Cite these by their own IDs and link them; don't restate them (decision [0011](../decisions/0011-family-format-upstream-sources.md)).

- [Azure/review-checklists](https://github.com/Azure/review-checklists) (MIT) has an AVD checklist at `checklists/avd_checklist.en.json`, with item GUIDs, pillars, severities, Learn links and Resource Graph queries for many items.
- The [Azure Proactive Resiliency Library v2](https://github.com/Azure/Azure-Proactive-Resiliency-Library-v2) (MIT) has AVD recommendations under `azure-resources/DesktopVirtualization/` (host pools, scaling plans, workspaces); the [WARA module](https://www.powershellgallery.com/packages/wara) runs it.
- Microsoft Assessments has an [Azure Virtual Desktop workload assessment](https://learn.microsoft.com/azure/well-architected/design-guides/implementing-recommendations#specialized-well-architected-reviews), a Well-Architected questionnaire, beside the [AVD workload guidance](https://learn.microsoft.com/azure/well-architected/azure-virtual-desktop/overview).
- None of them joins recommendations to a redacted fact snapshot or says which target-state decisions the evidence supports; that join is what the family adds.
