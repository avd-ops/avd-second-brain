<#
.SYNOPSIS
  Turns measured host pool utilization (contract avd-sizing-evidence/v1) into sizing calibration observations.
  Personal project, not for production use. Provided as is, without warranty of any kind (MIT License, see LICENSE). Not affiliated with the author's employer, with Liquidware or with Microsoft.

.DESCRIPTION
  The evidence comes from the factory's verify stage (avd-readiness-stratusphere) or from the
  landing zone's operations brain (avd-landing-zone), in the format of
  contracts/schemas/sizing-evidence.schema.json. Each host pool becomes one observation:
  predicted sessions per host against sessions per host extrapolated to the target utilization
  of knowledge/rules/workload-tiers.json. Host pools without an engagement or tier, or too
  lightly loaded to extrapolate (knowledge/rules/calibration.json), are listed and skipped.

  Without -Apply it only prints. -Apply appends the observations to
  knowledge/calibration/sizing.json and runs the guard; it refuses in a public knowledge base,
  where observations don't belong (docs/knowledge-spec.md §5).

.EXAMPLE
  ./scripts/Import-SizingEvidence.ps1 -EvidencePath ./sizing-evidence.json
.EXAMPLE
  ./scripts/Import-SizingEvidence.ps1 -EvidencePath ./sizing-evidence.json -KnowledgePath ../org-brain/knowledge -Apply
#>
#requires -Version 7.4
[CmdletBinding()]
param(
  # The evidence file (avd-sizing-evidence/v1).
  [Parameter(Mandatory)] [string] $EvidencePath,
  # The knowledge base whose rules it reads and whose calibration -Apply appends to.
  [string] $KnowledgePath = (Join-Path (Split-Path $PSScriptRoot -Parent) 'knowledge'),
  # Append the observations; without it the script only prints.
  [switch] $Apply
)

$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'AvdBrain.psm1') -Force

$schema = Join-Path (Split-Path $PSScriptRoot -Parent) 'contracts/schemas/sizing-evidence.schema.json'
$text = Get-Content -LiteralPath $EvidencePath -Raw
$errs = $null
if (-not (Test-Json -Json $text -SchemaFile $schema -ErrorAction SilentlyContinue -ErrorVariable errs)) {
  Write-Host "Not avd-sizing-evidence/v1: $((@($errs) | Select-Object -First 3 | ForEach-Object { $_.Exception.Message }) -join ' | ')" -ForegroundColor Red
  exit 1
}
$evidence = $text | ConvertFrom-Json
$calRule = Get-Content -LiteralPath (Join-Path $KnowledgePath 'rules/calibration.json') -Raw | ConvertFrom-Json
$tiers = Get-Content -LiteralPath (Join-Path $KnowledgePath 'rules/workload-tiers.json') -Raw | ConvertFrom-Json
$target = [double]$tiers.values.targetUtilization

$rows = @(ConvertFrom-SizingEvidence -Evidence $evidence -CalibrationRule $calRule -TargetUtilization $target)
foreach ($r in $rows) {
  if ($r.Skipped) { Write-Host ("SKIP  {0,-13} {1}" -f $r.At, $r.Skipped) -ForegroundColor Yellow; continue }
  $o = $r.Observation
  Write-Host ("OBS   {0,-13} {1} {2,-8} {3,-20} predicted {4,5}  measured {5,5}  bound by {6}" -f $r.At, $o.engagement, $o.tier, $o.vmSize, $o.predictedSessionsPerHost, $o.measuredSessionsPerHost, $o.boundBy)
}
$new = @($rows | Where-Object Observation | ForEach-Object Observation)
Write-Host "$($new.Count) observation(s), $(@($rows | Where-Object Skipped).Count) skipped. Target utilization $target (workload-tiers v$($tiers.version)), calibration v$($calRule.version)."
if (-not $Apply -or -not $new.Count) { return }

$scope = (Get-Content -LiteralPath (Join-Path $KnowledgePath 'knowledge.json') -Raw | ConvertFrom-Json).scope
if ($scope -ne 'organization') {
  Write-Host "Refusing -Apply: '$KnowledgePath' is the $scope knowledge base. Observations belong in an organization brain." -ForegroundColor Red
  exit 1
}
$calFile = Join-Path $KnowledgePath 'calibration/sizing.json'
$cal = Get-Content -LiteralPath $calFile -Raw | ConvertFrom-Json
$cal.observations = @(@($cal.observations) + $new)
$cal | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $calFile
Write-Host "Appended to $calFile. Checking the knowledge base:"
& (Join-Path $PSScriptRoot 'Test-Knowledge.ps1') -Path $KnowledgePath
