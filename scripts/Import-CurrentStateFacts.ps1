<#
.SYNOPSIS
  Checks a redacted current-state snapshot (contract C11, avd-current-state-facts/v1) and files it in the estate vault's facts store.
  Personal project, not for production use. Provided as is, without warranty of any kind (MIT License, see LICENSE). Not affiliated with the author's employer, with Liquidware or with Microsoft.

.DESCRIPTION
  avd-current-state's avd_current_state_facts.ps1 turns collector and validator packages into a
  snapshot with no names, IDs, IP addresses, tags or free text: counts, booleans, public Azure
  values and keyed pseudonyms. It is the fact layer the brain's agents read and a playbook
  proposal to avd-swarm cites (docs/contracts.md C11). The raw packages stay in the vault (C1).

  The snapshot must validate against contracts/schemas/current-state-facts.schema.json and pass
  the guard (scripts/AvdBrain.psm1, Get-BrainSensitiveText). Any error refuses it: fix the
  producer, never the snapshot.

  Without -Apply it only prints. -Apply copies the snapshot to
  <VaultPath>/facts/<estate>/<generatedUtc>.json. It refuses to write inside this repository,
  because a snapshot is still one estate's data and belongs in that estate's private vault.

.EXAMPLE
  ./scripts/Import-CurrentStateFacts.ps1 -FactsPath ./avd-current-state-facts-20261018T090000.json
.EXAMPLE
  ./scripts/Import-CurrentStateFacts.ps1 -FactsPath ./avd-current-state-facts-20261018T090000.json -VaultPath ../avd-brain -Apply
#>
#requires -Version 7.4
[CmdletBinding()]
param(
  [Parameter(Mandatory)] [string] $FactsPath,
  [string] $VaultPath,
  [switch] $Apply
)

$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'AvdBrain.psm1') -Force

$repo = Split-Path $PSScriptRoot -Parent
$r = Test-CurrentStateFacts -File $FactsPath -SchemaFile (Join-Path $repo 'contracts/schemas/current-state-facts.schema.json')
foreach ($f in $r.Findings) {
  $color = if ($f.Severity -eq 'Error') { 'Red' } else { 'Yellow' }
  Write-Host ("{0,-7} {1,-26} {2}  {3}" -f $f.Severity.ToUpper(), $f.Check, $f.Path, $f.Message) -ForegroundColor $color
}
if (@($r.Findings | Where-Object Severity -eq 'Error').Count) {
  Write-Host 'Refused: not a clean avd-current-state-facts/v1 snapshot.' -ForegroundColor Red
  exit 1
}

$doc = $r.Document
$utc = ([datetime]$doc.generatedUtc).ToUniversalTime()
Write-Host "Estate $($doc.estate), generated $($utc.ToString('yyyy-MM-dd HH:mm')) UTC by $($doc.producer.name) $($doc.producer.version)"
foreach ($sub in @($doc.subscriptions)) {
  $hosts = (@($sub.hostPools) | ForEach-Object { $_.sessionHosts.total } | Measure-Object -Sum).Sum
  Write-Host ("  {0}  collected {1}  {2} host pool(s), {3} session host(s), {4} VM(s)" -f $sub.id, ([datetime]$sub.collectedUtc).ToUniversalTime().ToString('yyyy-MM-dd'), @($sub.hostPools).Count, [int]$hosts, $sub.virtualMachines.total)
}
foreach ($v in @($doc.validations)) {
  Write-Host ("  {0}  {1,-15} {2}  {3} check(s)" -f $v.subscription, $v.mode, $v.verdict, @($v.checks).Count)
}
if (-not $Apply) { return }

if (-not $VaultPath) { Write-Host 'Refusing -Apply: pass -VaultPath, the estate vault the snapshot belongs to.' -ForegroundColor Red; exit 1 }
$vault = (Resolve-Path -LiteralPath $VaultPath).Path
$repoFull = (Resolve-Path -LiteralPath $repo).Path
if ($vault -eq $repoFull -or $vault.StartsWith($repoFull + [IO.Path]::DirectorySeparatorChar)) {
  Write-Host "Refusing -Apply: '$vault' is inside avd-second-brain. Facts belong in the estate's private vault." -ForegroundColor Red
  exit 1
}
$dir = Join-Path $vault (Join-Path 'facts' $doc.estate)
New-Item -ItemType Directory -Force -Path $dir | Out-Null
$target = Join-Path $dir ($utc.ToString("yyyyMMdd'T'HHmmss'Z'") + '.json')
Copy-Item -LiteralPath $FactsPath -Destination $target -Force
Write-Host "Filed as $target"
