---
title: "Landing zone"
summary: "Bicep, networking, policy, quotas and resource providers for an AVD landing zone, and running it all from Cloud Shell"
topic: landing-zone
status: plan
last_reviewed: 2026-10-18
---

# Landing zone

How an AVD landing zone gets built and kept healthy with Azure-native tooling: Bicep and Azure Verified Modules, networking and private endpoints, policy, vCPU quota, resource providers, and running every step from Azure Cloud Shell. Nothing is written here yet; what's known today lives in avd-landing-zone and is listed below.

## Where it lives today

- [AVM NAT Gateway public IP defaults to zones 1-3](https://github.com/nickprignano/avd-landing-zone/blob/master/docs/lessons/0001-nat-gateway-pip-zones.md) (avd-landing-zone lesson 0001)
- [`Get-AzResourceProvider -ProviderNamespace` returns one object per region](https://github.com/nickprignano/avd-landing-zone/blob/master/docs/lessons/0005-provider-per-region.md) (avd-landing-zone lesson 0005)
- [Provider registration: blocking cmdlets and EncryptionAtHost](https://github.com/nickprignano/avd-landing-zone/blob/master/docs/lessons/0006-provider-registration.md) (avd-landing-zone lesson 0006)
- [Private endpoints live in their target's resource group](https://github.com/nickprignano/avd-landing-zone/blob/master/docs/lessons/0010-private-endpoint-rg.md) (avd-landing-zone lesson 0010)
- [New subscriptions have no quota for most VM families](https://github.com/nickprignano/avd-landing-zone/blob/master/docs/lessons/0013-vcpu-quota.md) (avd-landing-zone lesson 0013)
- [Commands for Cloud Shell must stand alone](https://github.com/nickprignano/avd-landing-zone/blob/master/docs/lessons/0015-cloud-shell-ergonomics.md) (avd-landing-zone lesson 0015)
- [Bicep authoring traps](https://github.com/nickprignano/avd-landing-zone/blob/master/docs/lessons/0019-bicep-authoring.md) (avd-landing-zone lesson 0019)
- [ARM leaves out empty properties, and `@($null).Count` is 1](https://github.com/nickprignano/avd-landing-zone/blob/master/docs/lessons/0021-arm-omits-empty-properties.md) (avd-landing-zone lesson 0021)
- [A deployed host's vCPUs are already in "used"](https://github.com/nickprignano/avd-landing-zone/blob/master/docs/lessons/0024-quota-counts-deployed-hosts.md) (avd-landing-zone lesson 0024)
- [Entra ID-only, greenfield, private by default](https://github.com/nickprignano/avd-landing-zone/blob/master/docs/decisions/0001-cloud-native-scope.md) (avd-landing-zone decision 0001)
