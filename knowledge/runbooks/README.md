# Shared runbooks

Runbooks that hold for any AVD estate, harvested from customer vaults once a person has taken out everything specific to one customer. They use the vault's runbook front matter (`vault/template/_templates/runbook.md`), including `resolves-checks` with avd-current-state validator check names.

`vault/avd_second_brain.ps1 -Init` copies them into a new or existing vault (never over a file the vault already has), so every customer vault starts with the organization's fixes and links them from matching findings.

None yet: the first verified runbook from a real vault starts this list (`scripts/Get-VaultHarvest.ps1` lists the candidates).
