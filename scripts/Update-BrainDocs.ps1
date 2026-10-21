<#
.SYNOPSIS
  Regenerates the docs that come from the code: reference pages, README blocks, and the changelog.
  Personal project, not for production use. Provided as is, without warranty of any kind (MIT License, see LICENSE). Not affiliated with the author's employer, with Liquidware or with Microsoft.

.DESCRIPTION
  Writes what docs/docs-spec.md section 7 says is generated, and nothing else: a reference page per entry
  point and Bicep file (docs/reference/), the README's entry-points and connections blocks between
  their markers, and with -PullRequestPath the "Changelog:" lines of merged pull requests under
  CHANGELOG.md's Unreleased heading. The handbook it once built (wiki/) is retired (decision 0024):
  avd-ops holds the page for each repo. Text outside the markers is never touched. Before
  writing, it runs the privacy check (D11) on everything it would write and refuses on a finding.
  -Check writes nothing and exits 1 when anything is out of date.

.EXAMPLE
  ./scripts/Update-BrainDocs.ps1
.EXAMPLE
  ./scripts/Update-BrainDocs.ps1 -Check
.EXAMPLE
  ./scripts/Update-BrainDocs.ps1 -RepoPath ../avd-swarm -RepoName avd-swarm -PullRequestPath ./merged.json
#>
#requires -Version 7.4
[CmdletBinding()]
param(
  # The repo to regenerate; this one by default.
  [string] $RepoPath = (Split-Path $PSScriptRoot -Parent),
  # Its name as sources/sources.json has it; the folder name by default.
  [string] $RepoName,
  # A checkout of avd-second-brain, for sources/sources.json.
  [string] $BrainPath = (Split-Path $PSScriptRoot -Parent),
  # Merged pull requests as JSON (an array of objects with number and body) whose "Changelog:" lines go into CHANGELOG.md.
  [string] $PullRequestPath,
  # Write nothing; list what is out of date and exit 1 if anything is.
  [switch] $Check
)

$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'AvdBrain.psm1') -Force

$brainRoot = (Resolve-Path -LiteralPath $BrainPath).Path
if (-not $RepoName) { $RepoName = Split-Path (Resolve-Path -LiteralPath $RepoPath).Path -Leaf }
$repo = Get-DocRepo -Path $RepoPath -Name $RepoName
$sources = @(Get-BrainSource -Path (Join-Path $brainRoot 'sources/sources.json'))
$isBrain = $repo.Root -eq $brainRoot

$out = Get-DocOutput -Repo $repo -Source $(if ($isBrain) { $sources } else { @() })
$owned = @('docs/reference')
if ($PullRequestPath) {
  $file = Join-Path $repo.Root 'CHANGELOG.md'
  $current = if (Test-Path -LiteralPath $file) { Get-Content -LiteralPath $file -Raw } else { "# Changelog`n`nAll notable changes, in the format of [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).`n`n## Unreleased`n" }
  $prs = @(Get-Content -LiteralPath $PullRequestPath -Raw | ConvertFrom-Json)
  $new = Get-DocChangelog -Text $current -PullRequest $prs
  if ($new -ne $current) { $out['CHANGELOG.md'] = $new }
}

$private = @(Test-DocPrivate -Repo $repo -Output $out)
if ($private.Count) {
  foreach ($f in $private) { Write-Host "ERROR   D11 $($f.path):$($f.line)  $($f.says): $($f.truth)" -ForegroundColor Red }
  Write-Host 'RESULT FAIL (generated text would carry what looks like tenant or customer data; nothing written)' -ForegroundColor Red
  exit 1
}

$changed = @(foreach ($path in $out.Keys | Sort-Object) {
    $full = Join-Path $repo.Root $path
    $have = if (Test-Path -LiteralPath $full) { (Get-Content -LiteralPath $full -Raw) -replace "`r`n", "`n" } else { $null }
    if ($have -ne ($out[$path] -replace "`r`n", "`n")) { [pscustomobject]@{ Path = $path; Action = if ($null -eq $have) { 'create' } else { 'update' } } }
  })
$changed += @($repo.Files | Where-Object { $p = $_; @($owned | Where-Object { $p -like "$_/*" }).Count -and -not $out.ContainsKey($p) } |
    ForEach-Object { [pscustomobject]@{ Path = $_; Action = 'remove' } })

foreach ($c in $changed) {
  Write-Host ("{0,-7} {1}" -f $c.Action, $c.Path)
  if ($Check) { continue }
  $full = Join-Path $repo.Root $c.Path
  if ($c.Action -eq 'remove') { Remove-Item -LiteralPath $full; continue }
  New-Item -ItemType Directory -Path (Split-Path $full -Parent) -Force | Out-Null
  [IO.File]::WriteAllText($full, ($out[$c.Path] -replace "`r`n", "`n"))
}
if ($Check -and $changed.Count) {
  Write-Host "RESULT FAIL ($($changed.Count) generated files out of date: run ./scripts/Update-BrainDocs.ps1)" -ForegroundColor Red
  exit 1
}
$verb = if ($Check) { 'up to date' } else { "$($changed.Count) files written" }
Write-Host "RESULT PASS ($verb)" -ForegroundColor Green
