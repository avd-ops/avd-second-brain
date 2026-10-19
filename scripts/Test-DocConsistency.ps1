<#
.SYNOPSIS
  Checks that a repo's docs agree with its code and with the brain's facts of record (docs consistency, D1 to D11).
  Personal project, not for production use. Provided as is, without warranty of any kind (MIT License, see LICENSE). Not affiliated with the author's employer, with Liquidware or with Microsoft.

.DESCRIPTION
  Runs the checks in docs/docs-spec.md section 6 on one repo (this one by default), or with -All on this
  repo and every connected repo ./scripts/Sync-BrainSources.ps1 checked out: links and paths (D1),
  entry points (D2), parameters (D3), contracts (D4), paired decisions (D5), the changelog (D6),
  connection tables (D7), terms (D8), knowledge citations (D9), generated text (D10) and the
  privacy of generated text (D11). Nothing runs a script or calls a model; scripts are parsed.
  One line per finding, then RESULT PASS or RESULT FAIL. During the rollout (docs-spec section 12) only
  D11 fails the run; -Enforce makes every error fail it. -JsonPath writes the findings as
  avd-doc-findings/v1 (docs/contracts.md C13) for avd-swarm's Scribe. A repo accepts a finding
  by its key, with a reason, in docs/accepted-findings.json; D11 can't be accepted.

.EXAMPLE
  ./scripts/Test-DocConsistency.ps1
.EXAMPLE
  ./scripts/Test-DocConsistency.ps1 -RepoPath ../avd-swarm -RepoName avd-swarm
.EXAMPLE
  ./scripts/Sync-BrainSources.ps1 -AllowMissing; ./scripts/Test-DocConsistency.ps1 -All -JsonPath ./doc-findings.json
#>
#requires -Version 7.4
[CmdletBinding()]
param(
  # The repo to check; this one by default.
  [string] $RepoPath = (Split-Path $PSScriptRoot -Parent),
  # Its name as sources/sources.json has it; the folder name by default.
  [string] $RepoName,
  # A checkout of avd-second-brain, for the facts of record.
  [string] $BrainPath = (Split-Path $PSScriptRoot -Parent),
  # Check this repo and every connected repo checked out under -SourcesRoot (the nightly sweep).
  [switch] $All,
  # Where Sync-BrainSources.ps1 checked out the connected repos.
  [string] $SourcesRoot = (Join-Path (Split-Path $PSScriptRoot -Parent) '.sources'),
  # Write the findings to this file as avd-doc-findings/v1 (contract C13).
  [string] $JsonPath,
  # The files a pull request changes, for the changelog check (D6).
  [string[]] $ChangedFile = @(),
  # The pull request's body, for its "Changelog:" line (D6).
  [string] $PullRequestBody,
  # Fail on any error, not only on D11.
  [switch] $Enforce
)

$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'AvdBrain.psm1') -Force

$fact = Get-DocFact -BrainPath $BrainPath
$brainRoot = (Resolve-Path -LiteralPath $BrainPath).Path
if (-not $RepoName) { $RepoName = Split-Path (Resolve-Path -LiteralPath $RepoPath).Path -Leaf }
$target = Get-DocRepo -Path $RepoPath -Name $RepoName
$brain = if ($target.Root -eq $brainRoot) { $target } else { Get-DocRepo -Path $brainRoot -Name 'avd-second-brain' }
$connected = @(if (Test-Path -LiteralPath $SourcesRoot) { Get-DocSourceRepo -SourcesRoot $SourcesRoot -Source $fact.Sources | Where-Object Name -ne $RepoName })
$repos = @($target) + @(if ($brain -ne $target) { $brain }) + $connected
if ($All) { Write-Host "Checking $($repos.Count) repos: $(@($repos.Name) -join ', ')" }
else { Write-Host "Checking $RepoName (context: $(@($repos | Select-Object -Skip 1 | ForEach-Object Name) -join ', '))" }

# The handbook is checked only when the connected repos are checked out at the commits it was built from.
$wiki = $null
$wikiLock = Join-Path $brainRoot 'wiki/lock.json'
if (($All -or $target -eq $brain) -and (Test-Path -LiteralPath $wikiLock)) {
  $pinned = Get-DocPinnedRepo -LockPath $wikiLock -Repo $connected
  if ($null -ne $pinned) { $wiki = Get-DocWiki -Brain $brain -Source $fact.Sources -Repo $pinned }
  else { Write-Host 'Handbook (wiki/) not checked: the connected repos are not checked out at wiki/lock.json (./scripts/Sync-BrainSources.ps1 -LockPath ./wiki/lock.json -AllowMissing).' -ForegroundColor DarkGray }
}

$findings = @(Test-DocConsistency -Repo $repos -Fact $fact -ChangedFile $ChangedFile -PullRequestBody $PullRequestBody -Wiki $wiki -All:$All)
foreach ($f in $findings) {
  $color = if ($f.severity -eq 'error') { 'Red' } else { 'Yellow' }
  $at = if ($f.line) { "$($f.path):$($f.line)" } else { $f.path }
  $how = if ($f.generated) { ' (regenerate)' } else { '' }
  Write-Host ("{0,-7} {1} {2}  {3}: {4}. {5}{6}  [{7}]" -f $f.severity.ToUpperInvariant(), $f.id, $f.repo, $at, $f.says, $f.truth, $how, $f.key) -ForegroundColor $color
}
if ($JsonPath) {
  $json = Get-DocFindingDocument -Finding $findings -Repo $(if ($All) { $repos } else { @($target) }) | ConvertTo-Json -Depth 6
  # D11 covers the findings file too: it quotes the repos' text, so it must be as clean as they are.
  $leaks = @(Get-BrainSensitiveText -Text ($json -replace '\\\\', '\') -Path $JsonPath)
  if ($leaks.Count) {
    foreach ($l in $leaks) { Write-Host "ERROR   D11 $($l.Path)  $($l.Check): $($l.Message)" -ForegroundColor Red }
    Write-Host 'RESULT FAIL (the findings file would quote what looks like tenant or customer data; not written)' -ForegroundColor Red
    exit 1
  }
  Set-Content -LiteralPath $JsonPath -Value $json
  Write-Host "Findings written to $JsonPath (avd-doc-findings/v1)"
}

$errors = @($findings | Where-Object severity -eq 'error')
$warnings = @($findings | Where-Object severity -eq 'warning').Count
$private = @($errors | Where-Object check -eq 'D11').Count
if ($private -or ($Enforce -and $errors.Count)) {
  Write-Host "RESULT FAIL ($($errors.Count) errors, $warnings warnings)" -ForegroundColor Red
  exit 1
}
$note = if ($errors.Count) { '; errors are reported, not enforced, during the rollout' } else { '' }
Write-Host "RESULT PASS ($($errors.Count) errors, $warnings warnings$note)" -ForegroundColor Green
