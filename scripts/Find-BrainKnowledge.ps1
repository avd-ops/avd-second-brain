<#
.SYNOPSIS
  Asks the second brain: search its knowledge and the connected repos, resolve an inventory app name, or show the sizing calibration.
  Personal project, not for production use. Provided as is, without warranty of any kind (MIT License, see LICENSE). Not affiliated with the author's employer, with Liquidware or with Microsoft.

.DESCRIPTION
  -Query searches the app catalog, the engine rules, the shared runbooks and docs here, the
  connected repos' lessons and decisions once ./scripts/Sync-BrainSources.ps1 has checked them out,
  and, with -VaultPath, a customer vault's decisions, runbooks and lessons. Each hit prints with
  the path to cite. -App resolves one raw inventory name (as Stratusphere
  reports it) to a catalog entry, or says it is unknown and belongs on the app test plan.
  -Calibration prints the sizing calibration factors per tier and VM family, computed from the
  observations with the rule in knowledge/rules/calibration.json.

.EXAMPLE
  ./scripts/Find-BrainKnowledge.ps1 -Query 'teams media optimization'
.EXAMPLE
  ./scripts/Find-BrainKnowledge.ps1 -App 'Microsoft Teams (work or school) 25198.1112.3855.4568'
.EXAMPLE
  ./scripts/Find-BrainKnowledge.ps1 'fslogix kerberos' -VaultPath ../contoso-avd-brain
.EXAMPLE
  ./scripts/Find-BrainKnowledge.ps1 -Calibration
#>
#requires -Version 7.4
[CmdletBinding(DefaultParameterSetName = 'Query')]
param(
  # What to search for.
  [Parameter(Mandatory, ParameterSetName = 'Query', Position = 0)] [string] $Query,
  # Raw inventory app names to resolve against the app catalog.
  [Parameter(Mandatory, ParameterSetName = 'App')] [string[]] $App,
  # Print the sizing calibration factors.
  [Parameter(Mandatory, ParameterSetName = 'Calibration')] [switch] $Calibration,
  # How many hits to print.
  [Parameter(ParameterSetName = 'Query')] [int] $Top = 10,
  # A customer vault to search as well.
  [Parameter(ParameterSetName = 'Query')] [string] $VaultPath,
  # Where Sync-BrainSources.ps1 checked out the connected repos.
  [Parameter(ParameterSetName = 'Query')] [string] $SourcesRoot = (Join-Path (Split-Path $PSScriptRoot -Parent) '.sources'),
  # The knowledge base.
  [string] $Path = (Join-Path (Split-Path $PSScriptRoot -Parent) 'knowledge')
)

$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'AvdBrain.psm1') -Force

$mode = if ($Calibration) { 'Calibration' } else { $PSCmdlet.ParameterSetName }
switch ($mode) {
  'Query' {
    $hits = @(Search-BrainKnowledge -Path $Path -Query $Query -Top $Top -VaultPath $VaultPath -SourcesRoot $SourcesRoot)
    if (-not $hits.Count) { Write-Host "Nothing in the brain matches '$Query'."; return }
    foreach ($h in $hits) {
      Write-Host ("[{0}] {1}" -f $h.Kind, $h.Ref) -ForegroundColor Cyan
      Write-Host "  $($h.Title)"
      if ($h.Snippet) { Write-Host "  $($h.Snippet)" -ForegroundColor DarkGray }
    }
  }
  'App' {
    $catalog = Get-Content -LiteralPath (Join-Path $Path 'catalog/apps.json') -Raw | ConvertFrom-Json
    foreach ($name in $App) {
      $r = Resolve-BrainApp -Name $name -Catalog $catalog
      if ($r) {
        Write-Host "$name" -ForegroundColor Cyan
        Write-Host "  $($r.Product): multi-session $($r.MultiSession), delivery $($r.Delivery)  ($($r.Citation), pattern '$($r.Pattern)')"
      }
      else {
        Write-Host "$name" -ForegroundColor Yellow
        Write-Host '  Not in the catalog: normalize it and put it on the app test plan.'
      }
    }
  }
  'Calibration' {
    $obs = @((Get-Content -LiteralPath (Join-Path $Path 'calibration/sizing.json') -Raw | ConvertFrom-Json).observations)
    $rule = Get-Content -LiteralPath (Join-Path $Path 'rules/calibration.json') -Raw | ConvertFrom-Json
    $rows = @(Get-SizingCalibration -Observation $obs -Rule $rule)
    if (-not $rows.Count) {
      Write-Host "No calibration observations yet: sizing uses the prior in knowledge/rules/workload-tiers.json (factor 1.0)."
      return
    }
    $rows | Format-Table Tier, VmFamily, Observations, MedianRatio, MinRatio, MaxRatio, Applied, Clamped, Factor -AutoSize | Out-String | Write-Host
    Write-Host "Rule: $($rows[0].Rule). Factors apply from $($rule.values.minObservations) observations."
  }
}
