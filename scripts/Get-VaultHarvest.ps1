<#
.SYNOPSIS
  Proposes what a customer vault may contribute to the knowledge base: generalized estate facts, recurring findings, and runbook and lesson candidates.
  Personal project, not for production use. Provided as is, without warranty of any kind (MIT License, see LICENSE). Not affiliated with the author's employer, with Liquidware or with Microsoft.

.DESCRIPTION
  Reads a vault built by vault/avd_second_brain.ps1 from avd-current-state packages (the latest
  inventory and validation snapshot of each environment, verified runbooks, lessons) and prints
  only generalized facts: a session host bucket, host pool types, VM families, the validator
  checks still failing (names only, never scopes), and the runbooks and lessons worth sharing
  with how many lines of each look like customer data. Nothing is written: a person, or the
  harvest skill, turns the proposal into a PR (docs/architecture.md, flow 2).

.EXAMPLE
  ./scripts/Get-VaultHarvest.ps1 -VaultPath ../contoso-avd-brain
.EXAMPLE
  ./scripts/Get-VaultHarvest.ps1 -VaultPath ../contoso-avd-brain -Json > harvest.json
#>
#requires -Version 7.4
[CmdletBinding()]
param(
  [Parameter(Mandatory)] [string] $VaultPath,
  [switch] $Json
)

$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'AvdBrain.psm1') -Force

$h = Get-VaultHarvest -VaultPath $VaultPath
if ($Json) { $h | ConvertTo-Json -Depth 6; return }

$fmt = { param($map) if ($map.Count) { ($map.GetEnumerator() | Sort-Object Name | ForEach-Object { "$($_.Name) $($_.Value)" }) -join ', ' } else { '-' } }
Write-Host "Vault harvest proposal ($($h.Environments) environments). Generalized only; review before it leaves the customer." -ForegroundColor Cyan
Write-Host ''
Write-Host 'Estate (for the engagement record):'
Write-Host "  session hosts      $($h.Estate.sessionHostsBucket)"
Write-Host "  host pools         $($h.Estate.hostPools) ($(& $fmt $h.Estate.hostPoolTypes))"
Write-Host "  VM families        $(& $fmt $h.Estate.vmFamilies)"
Write-Host "  max session limits $(& $fmt $h.Estate.maxSessionLimits)  (configured, not measured: not calibration evidence)"
Write-Host ''
Write-Host 'Validator checks still failing (candidates for a shared runbook):'
if (-not $h.RecurringChecks.Count) { Write-Host '  none' }
foreach ($c in $h.RecurringChecks) { Write-Host ("  {0,-5} {1} / {2}  ({3} environments)" -f $c.Worst, $c.Category, $c.Check, $c.Environments) }
Write-Host ''
Write-Host 'Runbooks (verified) and lessons to consider sharing:'
if (-not $h.Candidates.Count) { Write-Host '  none' }
foreach ($c in $h.Candidates) {
  $flag = if ($c.SensitiveLines) { "  $($c.SensitiveLines) sensitive finding(s): generalize first" } else { '' }
  $color = if ($c.SensitiveLines) { 'Yellow' } else { 'Gray' }
  Write-Host ("  [{0}] {1}  {2}{3}" -f $c.Kind, $c.Path, $c.Title, $flag) -ForegroundColor $color
}
Write-Host ''
Write-Host 'Next: generalize what you keep, copy it into knowledge/ (runbooks/, an engagement record, lessons), run ./scripts/Test-Knowledge.ps1 and open a PR.'
