<#
.SYNOPSIS
  Checks out the connected repositories (sources/sources.json) so the brain can search their lessons and decisions.
  Personal project, not for production use. Provided as is, without warranty of any kind (MIT License, see LICENSE). Not affiliated with the author's employer, with Liquidware or with Microsoft.

.DESCRIPTION
  Shallow-clones (or updates) each source at its ref into .sources/<name> (git-ignored) and
  records the commit of each in .sources/lock.json. Find-BrainKnowledge.ps1 then searches them
  and cites each hit as <repo>@<commit>:<path>, so an answer points at the exact text it used.
  Read-only against GitHub: it only clones and fetches public repositories.
  -LockPath checks out the commits a lock file names instead (a saved .sources/lock.json, to repeat
  a search or a check exactly as it ran); a source with no commit there is skipped.

.EXAMPLE
  ./scripts/Sync-BrainSources.ps1
.EXAMPLE
  ./scripts/Sync-BrainSources.ps1 -Name avd-landing-zone
.EXAMPLE
  ./scripts/Sync-BrainSources.ps1 -LockPath ./saved-lock.json -AllowMissing
#>
#requires -Version 7.4
[CmdletBinding()]
param(
  # Only these sources (by name in sources/sources.json); all of them by default.
  [string[]] $Name,
  # Where the checkouts and lock.json go.
  [string] $SourcesRoot = (Join-Path (Split-Path $PSScriptRoot -Parent) '.sources'),
  # Check out the commits in this lock file instead of each source's ref.
  [string] $LockPath,
  # Report a source that can't be read (private or unreachable) and carry on; the result still passes.
  [switch] $AllowMissing
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

$pinned = @{}
if ($LockPath) {
  foreach ($l in @((Get-Content -LiteralPath $LockPath -Raw | ConvertFrom-Json).sources)) { $pinned[$l.name] = $l.commit }
}

$failed = 0; $missing = 0
foreach ($s in $sources) {
  $dir = Join-Path $SourcesRoot $s.name
  $want = $s.ref
  if ($LockPath) {
    $want = $pinned[$s.name]
    if (-not $want) { Write-Host ("{0,-28} skipped: no commit in {1}" -f $s.name, $LockPath) -ForegroundColor Yellow; continue }
  }
  try {
    if (-not (Test-Path -LiteralPath (Join-Path $dir '.git'))) {
      git init --quiet $dir
      git -C $dir remote add origin $s.url
    }
    $env:GIT_TERMINAL_PROMPT = '0'
    git -C $dir fetch --quiet --depth 1 origin $want 2>&1 | Out-Null
    if ($LASTEXITCODE) { throw "git fetch exited $LASTEXITCODE (private or unreachable?)" }
    git -C $dir checkout --quiet --detach FETCH_HEAD
    if ($LASTEXITCODE) { throw "git exited $LASTEXITCODE" }
    $commit = (git -C $dir rev-parse HEAD).Trim()
    $lock[$s.name] = [ordered]@{ name = $s.name; ref = $s.ref; commit = $commit; syncedUtc = (Get-Date).ToUniversalTime().ToString('o') }
    Write-Host ("{0,-28} {1} @ {2}" -f $s.name, $s.ref, $commit.Substring(0, 7)) -ForegroundColor Green
  }
  catch {
    if ($AllowMissing) {
      $missing++
      $lock.Remove($s.name)
      Write-Host ("{0,-28} not read: {1}" -f $s.name, $_.Exception.Message) -ForegroundColor Yellow
    }
    else {
      $failed++
      Write-Host ("{0,-28} FAILED: {1}" -f $s.name, $_.Exception.Message) -ForegroundColor Red
    }
  }
}

[ordered]@{ sources = @($lock.Values) } | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $lockFile
if ($failed) { Write-Host "RESULT FAIL ($failed of $($sources.Count) sources)" -ForegroundColor Red; exit 1 }
Write-Host "RESULT PASS ($($sources.Count - $missing) of $($sources.Count) sources in $SourcesRoot)" -ForegroundColor Green
