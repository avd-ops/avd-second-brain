---
title: "FSLogix profiles"
summary: "FSLogix profile containers on Azure Files with Entra Kerberos: share setup, SMB settings, permissions and what breaks"
topic: fslogix
status: verified
last_reviewed: 2026-10-19
---

# FSLogix profiles

FSLogix profile containers on Azure Files with Entra Kerberos, for Entra ID-joined session hosts and cloud-only users. Each rule below came from a real run of [avd-landing-zone](https://github.com/nickprignano/avd-landing-zone) and links the lesson that holds the detail. The exact errors are in [known errors](../troubleshooting/README.md).

## SMB settings

- The SMB settings themselves (protocol versions, authentication methods, Kerberos ticket encryption, channel encryption) are documented in [SMB file shares in Azure Files](https://learn.microsoft.com/azure/storage/files/files-smb-protocol); setting up Entra Kerberos is in [Enable Microsoft Entra Kerberos authentication](https://learn.microsoft.com/azure/storage/files/storage-files-identity-auth-hybrid-identities-enable). What follows is what those pages don't say.
- Azure Files denies Entra Kerberos sessions when AES-256-GCM is the only SMB channel encryption: the ticket is valid but SMB session setup returns access denied. The Entra Kerberos page says you can pick whichever channel encryption fits (checked 2026-10-19); our run disagrees, and it's an [upstream ask](../microsoft/upstream-contributions.md#docs-and-packaging). Allow `AES-128-GCM;AES-256-GCM;`, keep CCM off and Kerberos only ([lesson 0028](https://github.com/nickprignano/avd-landing-zone/blob/master/docs/lessons/0028-smb-channel-encryption-entra-kerberos.md)). Fixed in avd-landing-zone PR #45 and checked with a real profile load on 2026-10-18.
- Before shipping a change to an SMB setting on an Entra Kerberos share, sign in as a real cloud-only user. When the ticket is good and session setup is denied, change the share's SMB settings one at a time before looking at identity ([lesson 0028](https://github.com/nickprignano/avd-landing-zone/blob/master/docs/lessons/0028-smb-channel-encryption-entra-kerberos.md)).

## Share permissions

- Set the profile share's root ACL through the Azure Files REST API with OAuth, from a session host ([avd-landing-zone decision 0005](https://github.com/nickprignano/avd-landing-zone/blob/master/docs/decisions/0005-ntfs-via-rest.md)).
- Those requests need `x-ms-date`, and the root of a new share has no ACL yet, so it returns no permission key. Treat a missing key as the default ACL that still needs setting ([lesson 0011](https://github.com/nickprignano/avd-landing-zone/blob/master/docs/lessons/0011-azure-files-rest.md)).
- Capture the full REST error (status, `x-ms-error-code`, body and which step) from the first version of any host-side call ([lesson 0011](https://github.com/nickprignano/avd-landing-zone/blob/master/docs/lessons/0011-azure-files-rest.md), [lesson 0012](https://github.com/nickprignano/avd-landing-zone/blob/master/docs/lessons/0012-diagnose-first.md)).
