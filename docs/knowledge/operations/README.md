---
title: "Operating an estate"
summary: "Day-2 operations: detections, playbooks, episodes, and the handoff to avd-swarm for anything that changes an estate"
topic: operations
status: partial
last_reviewed: 2026-10-18
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
