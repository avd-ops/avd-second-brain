---
title: "Operating an estate"
summary: "Day-2 operations: detections, playbooks, episodes, and the handoff to avd-swarm for anything that changes an estate"
topic: operations
status: partial
last_reviewed: 2026-10-20
---

# Operating an estate

Running an AVD estate after deployment: detections and signals, playbooks as tested procedure, episodes that become lessons, and the handoff to avd-swarm, which makes every change through a person's approval and one kill switch ([decision 0003](../decisions/0003-brain-thinks-swarm-acts.md)). The design is in the [operations spec](../../operations-spec.md) and its [red team](../../operations-redteam.md); avd-swarm's [governance](https://github.com/nickprignano/avd-swarm/blob/main/docs/governance.md) covers the gate, the observers and the kill switch. *Unverified:* the detections, playbooks and the swarm handoff are designed, not built.

The rules below came from real runs of [avd-landing-zone](https://github.com/nickprignano/avd-landing-zone); the exact errors are in [known errors](../troubleshooting/README.md).

## Diagnosing

- When a real run fails in an external API, first report everything the API returned. Change behavior only once the evidence names the cause ([lesson 0012](https://github.com/nickprignano/avd-landing-zone/blob/master/docs/lessons/0012-diagnose-first.md)).

## Redeploying

- Anything a deployment changes inside a VM (extensions, run commands) needs the VM running. With power management on, assume hosts are stopped: start them for the change, then put them back ([lesson 0026](https://github.com/nickprignano/avd-landing-zone/blob/master/docs/lessons/0026-redeploy-stopped-hosts.md)).

## Tearing down and deploying again

- Deleting a resource group only soft-deletes some of what's in it. A Log Analytics workspace comes back when one with the same name is created; delete it permanently or let the next deployment handle the recovered state ([lesson 0023](https://github.com/nickprignano/avd-landing-zone/blob/master/docs/lessons/0023-log-analytics-soft-delete.md)).
- A purge-protected Key Vault is recovered, not waited out, and recovery needs its original resource group. A safe, reversible remedy like this belongs in a `-Fix` action, not in advice ([lesson 0022](https://github.com/nickprignano/avd-landing-zone/blob/master/docs/lessons/0022-key-vault-recovery.md)).
- Delete a cleanup step's inputs only after the step that needs them has succeeded ([lesson 0029](https://github.com/nickprignano/avd-landing-zone/blob/master/docs/lessons/0029-device-cleanup-rerun.md)).

## Tracking risks, actions and decisions

*Proposed:* the brain keeps each estate's RAID log and action tracker beside its lifecycle record ([raid spec](../../raid-spec.md), [decision 0022](../decisions/0022-the-brain-keeps-the-raid-log.md)). Checked 2026-10-20:

- CAF Govern's risk register gives the fields to use as they are: ID, status, category, description, probability, impact, priority (impact weighted higher), strategy (mitigate, accept, avoid, transfer), enforcement, owner and closure date, reviewed on a schedule and after events ([Assess cloud risks](https://learn.microsoft.com/azure/cloud-adoption-framework/govern/assess-cloud-risks)).
- Azure Advisor separates a recommendation a person *marked* completed from one the system *verified*, and a verified one can't be reopened; postponed items come back on their own ([Manage recommendation state](https://learn.microsoft.com/azure/advisor/advisor-azure-state-management)). The tracker copies that split for actions.
- Well-Architected advises putting review recommendations into the workload's backlog with an owner and tracking them to resolution; WARP's DevOps scripts import them into Azure DevOps or GitHub ([implementing recommendations](https://learn.microsoft.com/azure/well-architected/design-guides/implementing-recommendations)). An estate's items stay in its private vault, so a ticket system can only be a view.
- No widely used open schema for RAID logs was found.

## Learning from real runs

What a real run did is worth keeping, and most of it is already kept by Azure. A run recorder and resume point for the landing zone is *proposed*, not built: [run recorder spec](https://github.com/nickprignano/avd-landing-zone/blob/master/build/specs/run-recorder-spec.md).

- Read the Activity Log after a run instead of exporting it: Azure keeps control-plane writes for 90 days at no charge, so a diagnostic setting is only needed for longer retention ([Activity log in Azure Monitor](https://learn.microsoft.com/azure/azure-monitor/fundamentals/activity-log)).
- Don't put a locked immutability policy on a sandbox's log store. A locked time-based retention policy can't be shortened or removed, and the storage account can't be deleted while a container holds a blob under it, so teardown fails until the policy expires. Unlocked policies don't protect from deletion ([container-level WORM policies](https://learn.microsoft.com/azure/storage/blobs/immutable-container-level-worm-policies)).
- Cloud Shell keeps files only in `clouddrive` and the `$HOME` image, and only when a storage account is mounted; an ephemeral session keeps nothing, and any session ends after 20 minutes without input. Where a run stands has to come from Azure (deployment history, resource groups), not from the shell ([Cloud Shell FAQ](https://learn.microsoft.com/azure/cloud-shell/faq-troubleshooting)). *Unverified in a real run:* that a subscription-scope deployment keeps running after the session ends.
- Graph activity logs need Entra ID P1 or P2; Entra audit and sign-in logs are available on Free ([Microsoft Entra licensing](https://learn.microsoft.com/entra/fundamentals/licensing#microsoft-entra-monitoring-and-health)).
