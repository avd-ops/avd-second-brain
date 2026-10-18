---
title: "Operating an estate"
summary: "Day-2 operations: detections, playbooks, episodes, and the handoff to avd-swarm for anything that changes an estate"
topic: operations
status: plan
last_reviewed: 2026-10-18
---

# Operating an estate

Running an AVD estate after deployment: detections and signals, playbooks as tested procedure, episodes that become lessons, and the handoff to avd-swarm, which makes every change through a person's approval and one kill switch. Nothing is written here yet.

## Where it lives today

- [Operations spec](../../operations-spec.md) and its [red team](../../operations-redteam.md)
- [avd-swarm governance](https://github.com/nickprignano/avd-swarm/blob/main/docs/governance.md): the gate, the observers and the kill switch
- [Surface the error before guessing a fix](https://github.com/nickprignano/avd-landing-zone/blob/master/docs/lessons/0012-diagnose-first.md) (avd-landing-zone lesson 0012)
- [A purge-protected vault is recovered, not waited out](https://github.com/nickprignano/avd-landing-zone/blob/master/docs/lessons/0022-key-vault-recovery.md) (avd-landing-zone lesson 0022)
- [Deleting a resource group only soft-deletes its Log Analytics workspace](https://github.com/nickprignano/avd-landing-zone/blob/master/docs/lessons/0023-log-analytics-soft-delete.md) (avd-landing-zone lesson 0023)
- [A redeploy needs the session hosts running](https://github.com/nickprignano/avd-landing-zone/blob/master/docs/lessons/0026-redeploy-stopped-hosts.md) (avd-landing-zone lesson 0026)
