---
title: "FSLogix profiles"
summary: "FSLogix profile containers on Azure Files with Entra Kerberos: share setup, SMB settings, permissions and what breaks"
topic: fslogix
status: verified
last_reviewed: 2026-10-20
---

# FSLogix profiles

FSLogix profile containers on Azure Files with Entra Kerberos, for Entra ID-joined session hosts and cloud-only users. Each rule below came from a real run of [avd-landing-zone](https://github.com/avd-ops/avd-landing-zone) and links the lesson that holds the detail. The exact errors are in [known errors](../troubleshooting/README.md).

## SMB settings

- The SMB settings themselves (protocol versions, authentication methods, Kerberos ticket encryption, channel encryption) are documented in [SMB file shares in Azure Files](https://learn.microsoft.com/azure/storage/files/files-smb-protocol); setting up Entra Kerberos is in [Enable Microsoft Entra Kerberos authentication](https://learn.microsoft.com/azure/storage/files/storage-files-identity-auth-hybrid-identities-enable). What follows is what those pages don't say.
- Azure Files denies Entra Kerberos sessions when AES-256-GCM is the only SMB channel encryption: the ticket is valid but SMB session setup returns access denied. The Entra Kerberos page says you can pick whichever channel encryption fits (checked 2026-10-19); our run disagrees, and it's an [upstream ask](../microsoft/upstream-contributions.md#docs-and-packaging). Allow `AES-128-GCM;AES-256-GCM;`, keep CCM off and Kerberos only ([lesson 0028](https://github.com/avd-ops/avd-landing-zone/blob/master/docs/lessons/0028-smb-channel-encryption-entra-kerberos.md)). Fixed in avd-landing-zone PR #45 and checked with a real profile load on 2026-10-18.
- Before shipping a change to an SMB setting on an Entra Kerberos share, sign in as a real cloud-only user. When the ticket is good and session setup is denied, change the share's SMB settings one at a time before looking at identity ([lesson 0028](https://github.com/avd-ops/avd-landing-zone/blob/master/docs/lessons/0028-smb-channel-encryption-entra-kerberos.md)).

## Share permissions

- Set the profile share's root ACL through the Azure Files REST API with OAuth, from a session host ([avd-landing-zone decision 0005](https://github.com/avd-ops/avd-landing-zone/blob/master/docs/decisions/0005-ntfs-via-rest.md)).
- Those requests need `x-ms-date`, and the root of a new share has no ACL yet, so it returns no permission key. Treat a missing key as the default ACL that still needs setting ([lesson 0011](https://github.com/avd-ops/avd-landing-zone/blob/master/docs/lessons/0011-azure-files-rest.md)).
- Capture the full REST error (status, `x-ms-error-code`, body and which step) from the first version of any host-side call ([lesson 0011](https://github.com/avd-ops/avd-landing-zone/blob/master/docs/lessons/0011-azure-files-rest.md), [lesson 0012](https://github.com/avd-ops/avd-landing-zone/blob/master/docs/lessons/0012-diagnose-first.md)).

## Backup and recovery

Checked against Microsoft Learn on 2026-10-20 ([Azure Files backup support matrix](https://learn.microsoft.com/azure/backup/azure-file-share-support-matrix), [FSLogix BCDR options](https://learn.microsoft.com/fslogix/concepts-container-recovery-business-continuity)).

- Azure Backup's snapshot tier keeps recovery points as share snapshots, which go with the share: a permanently deleted share loses them. The vaulted tier is the offsite copy; it supports SSD (premium) shares, is available in North Central US with Cross Region Restore, and sends only the day's last scheduled snapshot to the vault.
- Azure Backup for Azure Files and storage account keys: two Microsoft pages differ. *Back up Azure Files* asks for key access **or** public network access disabled; the support matrix asks for key access on the vaulted tier. A backup refused for lack of keys fails with `UserErrorStorageKeyBasedAuthenticationNotPermitted`. The landing zone keeps keys off (its share is private-endpoint only) for the snapshot tier and turns them on only with `profileBackupTier = 'Vaulted'`; SMB stays Kerberos-only, so a key can't mount the share. The snapshot tier with keys off is *unverified* until a real run's backup status says so; the post-deployment preflight reports it as `profile-backup` ([recovery spec U1, section 6.1](https://github.com/avd-ops/avd-landing-zone/blob/master/build/specs/recovery-spec.md)).
- With Cloud Cache across two regions, list the local share first in each region's `CCDLocations`, and never let a user hold sessions in both pools: the profile lock fails the second sign-in.
- Microsoft's own advice is to keep business data out of the profile (OneDrive, SharePoint); after a failover, a profile can come back damaged.
