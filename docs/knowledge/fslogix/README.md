---
title: "FSLogix profiles"
summary: "FSLogix profile containers on Azure Files with Entra Kerberos: share setup, SMB settings, permissions and what breaks"
topic: fslogix
status: plan
last_reviewed: 2026-10-18
---

# FSLogix profiles

FSLogix profile containers on Azure Files: the storage account and share, Entra Kerberos, SMB security settings, share and NTFS permissions, and the failures seen in real runs. Nothing is written here yet; what's known today is listed below.

## Where it lives today

- [Azure Files REST with OAuth: x-ms-date and the share root](https://github.com/nickprignano/avd-landing-zone/blob/master/docs/lessons/0011-azure-files-rest.md) (avd-landing-zone lesson 0011)
- [Azure Files denies Entra Kerberos sessions when AES-256-GCM is the only channel encryption](https://github.com/nickprignano/avd-landing-zone/blob/master/docs/lessons/0028-smb-channel-encryption-entra-kerberos.md) (avd-landing-zone lesson 0028)
- [Set the profile share root ACL through the Azure Files REST API from a session host](https://github.com/nickprignano/avd-landing-zone/blob/master/docs/decisions/0005-ntfs-via-rest.md) (avd-landing-zone decision 0005)
