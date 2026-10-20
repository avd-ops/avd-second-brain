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
- [avd-assess spec](../../assess-spec.md): a research index of AVD assessment methodology (collection, assessment, benchmarks, scoring), pinned references validated by our own observations. Roles: avd-landing-zone is how an estate is built and changed from here, avd-current-state is what is there now, avd-assess is what it should be and why
- [Contracts C19 to C21](../../contracts.md#c19-avd-intakev1): intake (`avd-intake/v1`), the method avd-assess publishes (`index.json` and `method.json`) and the report avd-current-state will write (`avd-assessment/v1`), with `Test-AssessMethod` and `Test-AssessmentReport`

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
- An offline spike (2026-10-20, ARI `main` at `4cc602c`, PowerShell 7.4) loaded only ARI's seven diagram scripts, without ImportExcel or Az, and drew from nine fake pseudonymized rows. It made no Azure calls. Pseudonyms kept every link (subnet to NIC to session host VM, peering state, a red "Broken Peering" for a VNet not in the rows) because only names changed and each ID kept its `/` segments; ARI reads IDs by position. What it showed:
  - The subscription page counts AVD host pools, but the network page doesn't place them. The AVD overlay belongs in ARI's subnet step (`Build-ARIDiagramSubnet`), labeling a subnet's VMs with their host pool.
  - Cell IDs and the date label change on every run, so diagrams can't be compared by diff.
  - A broken peering held by a spoke wasn't drawn; ARI drew the spoke only as the hub's peer. It showed when the hub held it.
  - The network step catches errors and drops them, so a bad row can yield a partial diagram silently. Check the output for every expected VNet.
  - ARI special-cases NICs named `aks-*` and `gwhost*`; pseudonyms lose those prefixes.
- A bake-off (2026-10-20, same ARI pin, fake estate extended with a `GatewaySubnet`, session hosts, an app group, a workspace and a broken peering held by the spoke) compared ARI plus a post-processor, a small Mermaid writer, Graphviz through PSGraph and Diagrammer.Core. ARI won on parity, and post-processing was enough for the rest; the spec is [avd-current-state `docs/diagram-spec.md`](https://github.com/nickprignano/avd-current-state/blob/main/docs/diagram-spec.md). What it showed:
  - ARI colors a VNet as a hub when it has a subnet named `GatewaySubnet`, so redaction must keep Azure's reserved subnet names.
  - ARI's output changes between runs for two reasons: random cell IDs, and one cache file per VNet under a random name, merged in name order. Sorting each page's cells by a key that ignores IDs, then renumbering and dropping the date, gave byte-identical output over three runs.
  - The AVD overlay works as a post-process: ARI's VM group object carries `VirtualMachine-NNN` attributes, so it can be relabeled with its host pool and given ARI's own AVD icon.
  - Installing ARI from the Gallery pulls about 98 MB (ImportExcel and six Az modules) that drawing doesn't use. The Gallery package's diagram scripts match the repo's at the same commit apart from line endings; its manifest's "All rights reserved" is the `Copyright` field, and its `LicenseUri` points to the repo's MIT license.
  - Mermaid renders on GitHub with no install and stays PowerShell 5.1-friendly, but matching ARI's breadth would mean rewriting about 6,000 lines, and subgraph styling was weak. Graphviz gave the best layout but needs its binary; PSGraph writes attributes in hashtable order, so its DOT text differs between runs even when the SVG doesn't. Diagrammer.Core ships Windows Graphviz binaries and its exporter hung on Linux.
