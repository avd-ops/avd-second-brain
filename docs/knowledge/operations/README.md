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

## Backup and disaster recovery

Checked against Microsoft Learn on 2026-10-20; the landing zone's design for it is the [recovery spec](https://github.com/nickprignano/avd-landing-zone/pull/75) (*unverified:* spec only, no real run). Microsoft's implementation guide is [Multiregion BCDR for Azure Virtual Desktop](https://learn.microsoft.com/azure/architecture/example-scenario/azure-virtual-desktop/azure-virtual-desktop-multi-region-bcdr).

- AVD has no disaster recovery features of its own. Microsoft fails over the control plane; session hosts, profiles, apps, user data and identities are the operator's ([AVD BCDR concepts](https://learn.microsoft.com/azure/virtual-desktop/disaster-recovery-concepts)).
- Microsoft's RPO and RTO figures are estimates to validate by testing: active-passive pooled with FSLogix Cloud Cache is seconds to minutes of RPO and 15 to 60 minutes of RTO. Availability zones are high availability, not disaster recovery.
- Deallocated standby hosts, a fresh deployment and Site Recovery don't guarantee capacity in the recovery region; only running resources or on-demand capacity reservations do, and Azure reservations don't.
- Never use Site Recovery test failover on session hosts: the duplicate VM registers with the control plane and conflicts with the original. Test with a separate test group assigned to the standby pool instead.
- A session host that stays deallocated must start for a few hours at least every 90 days to refresh its control plane token.
- A Key Vault backup restores only into a vault in the same subscription and geography, so it can't carry secrets to a new subscription. Regenerate secrets on recovery instead of copying them.
- Only some Entra objects are soft deleted for 30 days (users, Microsoft 365 and cloud security groups, app registrations, service principals, administrative units, Conditional Access policies, named locations); the rest are hard deleted. Keep Conditional Access and similar configuration as JSON in git and redeploy the last known-good version ([Recover from deletions](https://learn.microsoft.com/entra/architecture/recover-from-deletions)).
