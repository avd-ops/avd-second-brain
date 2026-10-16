<#
.SYNOPSIS
  Checks out the connected repositories (sources/sources.json) so the brain can search their lessons and decisions.
  Personal project, not for production use. Provided as is, without warranty of any kind (MIT License, see LICENSE). Not affiliated with the author's employer, with Liquidware or with Microsoft.

.DESCRIPTION
  Shallow-clones (or updates) each source at its ref into .sources/<name> (git-ignored) and
  records the commit of each in .sources/lock.json. Find-BrainKnowledge.ps1 then searches them
  and cites each hit as <repo>@<commit>:<path>, so an answer points at the exact text it used.
  Read-only against GitHub: it only clones and fetches public repositories.

.EXAMPLE
  ./scripts/Sync-BrainSources.ps1
.EXAMPLE
  ./scripts/Sync-BrainSources.ps1 -Name avd-landing-zone
#>
#requires -Version 7.4
[CmdletBinding()]
param(
  [string[]] $Name,
  [string] $SourcesRoot = (Join-Path (Split-Path $PSScriptRoot -Parent) '.sources')
)

$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'AvdBrain.psm1') -Force

$sources = @(Get-BrainSource -Path (Join-Path (Split-Path $PSScriptRoot -Parent) 'sources/sources.json'))
if ($Name) { $sources = @($sources | Where-Object name -in $Name) }
New-Item -ItemType Directory -Path $SourcesRoot -Force | Out-Null

$lockFile = Join-Path $SourcesRoot 'lock.json'
$lock = [ordered]@{}
if (Test-Path -LiteralPath $lockFile) {
  foreach ($l in @((Get-Content -LiteralPath $lockFile -Raw | ConvertFrom-Json).sources)) { $lock[$l.name] = $l }
}

$failed = 0
foreach ($s in $sources) {
  $dir = Join-Path $SourcesRoot $s.name
  try {
    if (Test-Path -LiteralPath (Join-Path $dir '.git')) {
      git -C $dir fetch --quiet --depth 1 origin $s.ref
      if ($LASTEXITCODE) { throw "git fetch exited $LASTEXITCODE" }
      git -C $dir checkout --quiet --detach FETCH_HEAD
    }
    else {
      git clone --quiet --depth 1 --branch $s.ref $s.url $dir
    }
    if ($LASTEXITCODE) { throw "git exited $LASTEXITCODE" }
    $commit = (git -C $dir rev-parse HEAD).Trim()
    $lock[$s.name] = [ordered]@{ name = $s.name; ref = $s.ref; commit = $commit; syncedUtc = (Get-Date).ToUniversalTime().ToString('o') }
    Write-Host ("{0,-28} {1} @ {2}" -f $s.name, $s.ref, $commit.Substring(0, 7)) -ForegroundColor Green
  }
  catch {
    $failed++
    Write-Host ("{0,-28} FAILED: {1}" -f $s.name, $_.Exception.Message) -ForegroundColor Red
  }
}

[ordered]@{ sources = @($lock.Values) } | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $lockFile
if ($failed) { Write-Host "RESULT FAIL ($failed of $($sources.Count) sources)" -ForegroundColor Red; exit 1 }
Write-Host "RESULT PASS ($($sources.Count) sources in $SourcesRoot)" -ForegroundColor Green
