# Shared runbooks

Runbooks that hold for any AVD estate, harvested from adopter vaults once a person has taken out everything specific to one adopter. They use the vault's runbook front matter (`vault/template/_templates/runbook.md`), including `resolves-checks` with avd-current-state validator check names.

`vault/avd_second_brain.ps1 -Init` copies them into a new or existing vault (never over a file the vault already has), so every adopter vault starts with the organization's fixes and links them from matching findings.

| Runbook | Status | Validator checks resolved |
|---|---|---|
| [Rotate expired host pool registration token](rotate-registration-token.md) | `draft` | `Registration token`, `Session host registration` |
| [Recover an unhealthy or drained session host](recover-unhealthy-session-host.md) | `draft` | `Session host status`, `Agent heartbeat`, `Drain mode` |
| [Fix FSLogix profile storage auth and TLS posture](fix-fslogix-storage-auth.md) | `draft` | `Identity-based auth`, `SMB share RBAC`, `Minimum TLS version` |
| [Fix scaling plan assignment and AVD power management role](fix-scaling-plan-power-role.md) | `draft` | `Scaling plan`, `Power role sufficiency`, `AVD power management role` |

All entries above are initial `draft` templates mapped to `avd-current-state` check names; promote each to `verified` after confirming in a real run (`scripts/Get-VaultHarvest.ps1` lists verified vault candidates).
