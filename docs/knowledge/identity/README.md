---
title: "Identity and Entra"
summary: "Entra ID joined hosts, Entra Kerberos, Microsoft Graph sign-in for operators, and agent identities"
topic: identity
status: plan
last_reviewed: 2026-10-18
---

# Identity and Entra

Identity for AVD on Entra ID: Entra-joined session hosts, Entra Kerberos for profile storage, Microsoft Graph sign-in for the people and scripts that operate an estate, and the identities AI agents run under. Nothing is written here yet; what's known today is listed below.

## Where it lives today

- [Microsoft Graph sign-in in Cloud Shell](https://github.com/nickprignano/avd-landing-zone/blob/master/docs/lessons/0007-graph-sign-in.md) (avd-landing-zone lesson 0007)
- [Azure Files denies Entra Kerberos sessions when AES-256-GCM is the only channel encryption](https://github.com/nickprignano/avd-landing-zone/blob/master/docs/lessons/0028-smb-channel-encryption-entra-kerberos.md) (avd-landing-zone lesson 0028)
- [Microsoft Graph's service principal doesn't list every delegated permission it issues](https://github.com/nickprignano/avd-landing-zone/blob/master/docs/lessons/0030-graph-unlisted-delegated-scope.md) (avd-landing-zone lesson 0030)
- [One delegated Microsoft Graph sign-in per session](https://github.com/nickprignano/avd-landing-zone/blob/master/docs/decisions/0016-graph-operator-app.md) (avd-landing-zone decision 0016)
- [Agent identities](https://github.com/nickprignano/avd-swarm/blob/main/docs/identities.md) (avd-swarm)
