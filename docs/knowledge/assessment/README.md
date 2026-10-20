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
- [avd-assess spec](../../assess-spec.md) (draft): a research index of AVD assessment methodology (collection, assessment, benchmarks, scoring), pinned references validated by our own observations

## Upstream sources for a baseline assessment

Checked 2026-10-20. Cite these by their own IDs and link them; don't restate them (decision [0011](../decisions/0011-family-format-upstream-sources.md)).

- [Azure/review-checklists](https://github.com/Azure/review-checklists) (MIT) has an AVD checklist at `checklists/avd_checklist.en.json`, with a short ID (`A01.01`), pillar, severity and Learn link per item but no Resource Graph query, so the evidence for each item has to be mapped; cite the short ID, not the GUID.
- The [Azure Proactive Resiliency Library v2](https://github.com/Azure/Azure-Proactive-Resiliency-Library-v2) (MIT) has AVD recommendations under `azure-resources/DesktopVirtualization/` (host pools, scaling plans, workspaces); the [WARA module](https://github.com/Azure/Well-Architected-Reliability-Assessment) runs it (Reliability only; `Start-WARACollector -AVD` writes JSON).
- Microsoft Assessments has an [Azure Virtual Desktop workload assessment](https://learn.microsoft.com/azure/well-architected/design-guides/implementing-recommendations#specialized-well-architected-reviews), a Well-Architected questionnaire. Links under `well-architected/azure-virtual-desktop/` now redirect into the AVD product docs.
- Windows desktop optimization: the [Windows Desktop Optimization Tool](https://github.com/The-Virtual-Desktop-Team/Windows-Desktop-Optimization-Tool) (WDOT, MIT) supersedes VDOT, which has no license; Learn's [Optimizing Windows configuration for VDI desktops](https://learn.microsoft.com/windows-server/remote/remote-desktop-services/remote-desktop-services-vdi-optimize-configuration) explains the settings. The landing zone's image build pins WDOT with a reviewed profile.
- None of them joins recommendations to a redacted fact snapshot or says which target-state decisions the evidence supports; that join is what the family adds.

## Diagrams from what is deployed

Checked 2026-10-20 for avd-current-state. Every ready-made generator draws real resource names, so none of its output can be shared under the redaction rules as is. ARI is the one to build on, because its diagram code reads only the rows it is given.

- [Azure Resource Inventory](https://github.com/microsoft/ARI) (MIT in the repo) writes a draw.io diagram with one tab per subscription, hub and spoke VNets colored by role, and broken peerings highlighted. Its diagram functions (`Modules/Public/PublicFunctions/Diagram/`) make no Azure calls; they draw from the Resource Graph rows passed in. So it can be wrapped: redact the rows (the same pseudonym for a name or ID everywhere, so links survive), then draw. It has no AVD awareness (no host pools), and it draws with random cell IDs, so two runs never diff cleanly. An AVD overlay and stable IDs are worth offering upstream; redaction stays ours. Its module needs PowerShell 7 and lists ImportExcel and several Az modules as required, even just to draw.
- [AzViz](https://github.com/PrateekKumarSingh/AzViz) (MIT) draws resource groups, VNets and subnets through Graphviz, which must be installed as a binary.
- Microsoft's [azure-resource-visualizer](https://github.com/microsoft/azure-skills/tree/main/skills/azure-resource-visualizer) agent skill (MIT) has an agent draw Mermaid from Resource Graph. Its list of edges (peering, subnet assignment, private endpoints, NSGs) is useful, but a model choosing the relationships isn't repeatable evidence.
- [Network Watcher topology](https://learn.microsoft.com/azure/network-watcher/network-insights-topology) is a portal map built from Resource Graph, with SVG download. Changes can take up to 30 hours to show.
- No AVD-specific diagram generator was found.
- The gap for a redacted diagram is data, not drawing. The C11 snapshot holds counts, not connections, and pseudonyms exist only for subscriptions, host pools and storage. The collector doesn't read VNet peerings or which subnet a session host's NIC is on. Saving Resource Graph rows gives ARI what it needs. [Mermaid](https://github.com/mermaid-js/mermaid) (MIT) is the fallback if ARI's draw.io output can't be styled well enough.
