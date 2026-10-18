#requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }
# Offline tests for the connections between the source repos and the brain (docs/architecture.md):
# avd-current-state packages -> vault -> harvest proposal, shared runbooks -> vault,
# avd-sizing-evidence/v1 -> calibration observations, and search across connected repos.

BeforeAll {
  $script:root = Split-Path $PSScriptRoot -Parent
  Import-Module (Join-Path $script:root 'scripts/AvdBrain.psm1') -Force
  $script:vaultScript = Join-Path $script:root 'vault/avd_second_brain.ps1'
  $script:calRule = Get-Content (Join-Path $script:root 'knowledge/rules/calibration.json') -Raw | ConvertFrom-Json

  function Write-TestJson { param($Path, $Data) New-Item -ItemType Directory -Force (Split-Path $Path) | Out-Null; $Data | ConvertTo-Json -Depth 8 | Set-Content $Path }

  # Minimal avd-current-state packages: one collector run and one validator run, same subscription.
  function New-TestPackages {
    param([string] $Dir)
    $sub = @{ SubscriptionName = 'sub-test'; SubscriptionId = '00000000-0000-0000-0000-000000000001' }
    $inv = Join-Path $Dir 'avd-current-state-20261001T090000'
    Write-TestJson "$inv/manifest.json" @{ PackageName = 'avd-current-state-20261001T090000'; GeneratedUtc = '2026-10-01T09:00:00Z'
      SubscriptionDetails = @(@{ SubscriptionName = $sub.SubscriptionName; SubscriptionId = $sub.SubscriptionId; Status = 'Collected' }) }
    Write-TestJson "$inv/sub-test/avd-host-pools.json" @(@{ Name = 'hp-finance'; HostPoolType = 'Pooled'; MaxSessionLimit = 12 }, @{ Name = 'hp-dev'; HostPoolType = 'Personal'; MaxSessionLimit = 1 })
    Write-TestJson "$inv/sub-test/avd-session-hosts.json" @(1..12 | ForEach-Object { @{ HostPool = 'hp-finance'; Status = 'Available'; AllowNewSession = 'True' } })
    Write-TestJson "$inv/sub-test/virtual-machines.json" @((1..12 | ForEach-Object { @{ VMSize = 'Standard_E8as_v5'; PowerState = 'VM running' } }) + @(@{ VMSize = 'Standard_D4s_v5'; PowerState = 'VM running' }))
    $val = Join-Path $Dir 'avd-validation-20261002T090000'
    Write-TestJson "$val/manifest.json" @{ PackageName = 'avd-validation-20261002T090000'; GeneratedUtc = '2026-10-02T09:00:00Z'; Verdict = 'FAIL'; Mode = 'PostDeployment'
      SubscriptionId = $sub.SubscriptionId; SubscriptionName = $sub.SubscriptionName; Counts = @{ Fail = 1; Warn = 1; Pass = 1 } }
    Write-TestJson "$val/validation-results.json" @(
      @{ Phase = 'Post'; Category = 'Session hosts'; Check = 'Registration token'; Status = 'FAIL'; Scope = 'hp-finance'; Detail = 'Expired' }
      @{ Phase = 'Post'; Category = 'Session hosts'; Check = 'Registration token'; Status = 'FAIL'; Scope = 'hp-dev'; Detail = 'Expired' }
      @{ Phase = 'Post'; Category = 'Monitoring'; Check = 'Log retention'; Status = 'WARN'; Scope = 'law-1'; Detail = '30 days' }
      @{ Phase = 'Post'; Category = 'Host pool'; Check = 'Drain mode'; Status = 'PASS'; Scope = 'hp-finance'; Detail = '' }
    )
  }

  function Get-TestEvidence {
    param([hashtable] $HostPool = @{})
    $hp = @{ tier = 'medium'; vmSize = 'Standard_E8as_v5'; maxSessionLimit = 14; hosts = 10; predictedSessionsPerHost = 14
      peakSessionsPerHost = 10; p95CpuPercent = 50; p95MemoryPercent = 80 }
    foreach ($k in $HostPool.Keys) { $hp[$k] = $HostPool[$k] }
    [pscustomobject]@{ schema = 'avd-sizing-evidence/v1'; source = 'landing-zone-brain'; engagement = 'eng-2026-11-a7f3'; wave = 2
      period = [pscustomobject]@{ start = '2027-01-01'; end = '2027-01-31' }; hostPools = @([pscustomobject]$hp) }
  }
}

Describe 'avd-current-state -> vault -> knowledge' {
  BeforeAll {
    $script:packages = Join-Path $TestDrive 'packages'
    New-TestPackages $script:packages
    $script:vault = Join-Path $TestDrive 'vault'
    $script:knowledge = Join-Path $TestDrive 'knowledge'
    New-Item -ItemType Directory -Force (Join-Path $script:knowledge 'runbooks') | Out-Null
    Set-Content (Join-Path $script:knowledge 'runbooks/renew-registration-token.md') "---`ntype: runbook`nstatus: verified`nresolves-checks: [`"Registration token`"]`n---`n`n# Renew the registration token`n"
    & $script:vaultScript -BrainPath $script:vault -Init -KnowledgePath $script:knowledge 6>$null | Out-Null
    & $script:vaultScript -BrainPath $script:vault -PackagePath $script:packages -KnowledgePath $script:knowledge 6>$null | Out-Null
    $script:harvest = Get-VaultHarvest -VaultPath $script:vault
  }
  It 'ingests both packages into the vault' {
    @(Get-ChildItem (Join-Path $script:vault 'environments') -Recurse -Filter *.json).Count | Should -Be 2
  }
  It 'seeds the vault with the shared runbooks at -Init and links them from findings' {
    Join-Path $script:vault 'runbooks/renew-registration-token.md' | Should -Exist
    Get-Content (Join-Path $script:vault 'environments/*/findings.md') -Raw | Should -Match 'renew-registration-token'
  }
  It 'never overwrites a runbook the vault already has' {
    $local = Join-Path $script:vault 'runbooks/renew-registration-token.md'
    $shared = Get-Content $local -Raw
    Set-Content $local 'local edit'
    & $script:vaultScript -BrainPath $script:vault -Init -KnowledgePath $script:knowledge 6>$null | Out-Null
    Get-Content $local -Raw | Should -Match 'local edit'
    Set-Content $local $shared -NoNewline
  }
  It 'proposes a generalized estate' {
    $e = $script:harvest.Estate
    $e.sessionHostsBucket | Should -Be '11-50'
    $e.hostPools | Should -Be 2
    $e.hostPoolTypes['Pooled'] | Should -Be 1
    $e.vmFamilies['E'] | Should -Be 12
    $e.vmFamilies['D'] | Should -Be 1
  }
  It 'counts each failing check once per environment, worst status first, without scopes' {
    $c = @($script:harvest.RecurringChecks)
    $c[0].Check | Should -Be 'Registration token'
    $c[0].Environments | Should -Be 1
    $c[0].Worst | Should -Be 'FAIL'
    $c.Check | Should -Contain 'Log retention'
    $c.Check | Should -Not -Contain 'Drain mode'
  }
  It 'carries no names, scopes or subscription IDs' {
    $text = $script:harvest | ConvertTo-Json -Depth 6
    $text | Should -Not -Match 'hp-finance|hp-dev|sub-test|law-1|00000000-0000-0000-0000-000000000001'
  }
  It 'lists verified runbooks and flags sensitive text in candidates' {
    Set-Content (Join-Path $script:vault 'lessons/token.md') "# Token expired`nHost pool on 10.20.30.40 lost its token."
    $h = Get-VaultHarvest -VaultPath $script:vault
    ($h.Candidates | Where-Object Path -eq 'lessons/token.md').SensitiveLines | Should -Be 1
    ($h.Candidates | Where-Object Kind -eq 'runbook').Path | Should -Be 'runbooks/renew-registration-token.md'
  }
}

Describe 'avd-sizing-evidence/v1 -> calibration' {
  It 'extrapolates to the target utilization from the binding resource' {
    $o = (ConvertFrom-SizingEvidence -Evidence (Get-TestEvidence) -CalibrationRule $script:calRule -TargetUtilization 0.8).Observation
    $o.measuredSessionsPerHost | Should -Be 10
    $o.boundBy | Should -Be 'memory'
    $o.vmFamily | Should -Be 'E'
    $o.wave | Should -Be 2
    $o.measuredOn | Should -Be '2027-01-31'
  }
  It 'binds on CPU when CPU is higher' {
    $o = (ConvertFrom-SizingEvidence -Evidence (Get-TestEvidence @{ p95CpuPercent = 64; p95MemoryPercent = 40 }) -CalibrationRule $script:calRule -TargetUtilization 0.8).Observation
    $o.boundBy | Should -Be 'cpu'
    $o.measuredSessionsPerHost | Should -Be 12.5
  }
  It 'falls back to the max session limit when there is no prediction' {
    $ev = Get-TestEvidence
    $ev.hostPools[0].PSObject.Properties.Remove('predictedSessionsPerHost')
    (ConvertFrom-SizingEvidence -Evidence $ev -CalibrationRule $script:calRule -TargetUtilization 0.8).Observation.predictedSessionsPerHost | Should -Be 14
  }
  It 'skips <Why>' -ForEach @(
    @{ Why = 'a host pool without a tier'; Change = @{ tier = $null }; Reason = 'no tier' }
    @{ Why = 'a lightly loaded host pool'; Change = @{ p95CpuPercent = 20; p95MemoryPercent = 30 }; Reason = 'too far' }
    @{ Why = 'too few sessions to be evidence'; Change = @{ peakSessionsPerHost = 2 }; Reason = 'below 3' }
  ) {
    $r = ConvertFrom-SizingEvidence -Evidence (Get-TestEvidence $Change) -CalibrationRule $script:calRule -TargetUtilization 0.8
    $r.Observation | Should -BeNullOrEmpty
    $r.Skipped | Should -Match $Reason
  }
  It 'skips a pool with no engagement (an estate the factory did not design)' {
    $ev = Get-TestEvidence
    $ev.PSObject.Properties.Remove('engagement')
    (ConvertFrom-SizingEvidence -Evidence $ev -CalibrationRule $script:calRule -TargetUtilization 0.8).Skipped | Should -Match 'no engagement'
  }
  It 'produces observations the calibration schema and guard accept' {
    $dir = Join-Path $TestDrive 'org'
    Copy-Item -Recurse (Join-Path $script:root 'knowledge') $dir
    $cfg = Get-Content "$dir/knowledge.json" -Raw | ConvertFrom-Json; $cfg.scope = 'organization'; $cfg | ConvertTo-Json | Set-Content "$dir/knowledge.json"
    @{ id = 'eng-2026-11-a7f3'; period = @{ start = '2026-11' }; status = 'migrating'
      estate = @{ usersBucket = '500-2k'; currentPlatforms = @('citrix'); sources = @('stratusphere-export') }; harvest = @{ done = $false } } |
      ConvertTo-Json -Depth 5 | Set-Content "$dir/engagements/eng-2026-11-a7f3.json"
    $o = (ConvertFrom-SizingEvidence -Evidence (Get-TestEvidence) -CalibrationRule $script:calRule -TargetUtilization 0.8).Observation
    @{ observations = @($o) } | ConvertTo-Json -Depth 5 | Set-Content "$dir/calibration/sizing.json"
    @(Test-BrainKnowledge -Path $dir | Where-Object Severity -eq 'Error') | Should -BeNullOrEmpty
  }
  It 'the contract has no field for names' {
    $schema = Get-Content (Join-Path $script:root 'contracts/schemas/sizing-evidence.schema.json') -Raw
    $ev = Get-TestEvidence @{ name = 'hp-finance' }
    Test-Json -Json ($ev | ConvertTo-Json -Depth 5) -Schema $schema -ErrorAction SilentlyContinue | Should -BeFalse
    Test-Json -Json (Get-TestEvidence | ConvertTo-Json -Depth 5) -Schema $schema | Should -BeTrue
  }
}

Describe 'Connected repositories' {
  It 'sources.json matches its schema and names the connected repos' {
    $file = Join-Path $script:root 'sources/sources.json'
    Test-Json -Json (Get-Content $file -Raw) -SchemaFile (Join-Path $script:root 'sources/sources.schema.json') | Should -BeTrue
    (Get-BrainSource -Path $file).name | Should -Be @('avd-readiness-stratusphere', 'avd-current-state', 'avd-landing-zone', 'avd-swarm')
  }
  It 'searches a checked-out source and cites it with its commit' {
    $sr = Join-Path $TestDrive 'sources'
    New-Item -ItemType Directory -Force "$sr/avd-landing-zone/docs/lessons" | Out-Null
    Set-Content "$sr/avd-landing-zone/docs/lessons/0099-zebra.md" "# Zebra lesson`nThe zebracorn quota."
    @{ sources = @(@{ name = 'avd-landing-zone'; commit = 'abcdef0123456789' }) } | ConvertTo-Json -Depth 3 | Set-Content "$sr/lock.json"
    $hit = @(Search-BrainKnowledge -Path (Join-Path $script:root 'knowledge') -Query 'zebracorn' -SourcesRoot $sr)[0]
    $hit.Ref | Should -Be 'avd-landing-zone@abcdef0:docs/lessons/0099-zebra.md'
    $hit.Kind | Should -Be 'lesson'
  }
  It 'searches a vault and cites it as vault:' {
    $v = Join-Path $TestDrive 'v2'
    New-Item -ItemType Directory -Force "$v/runbooks" | Out-Null
    Set-Content "$v/runbooks/okapi.md" '# Okapi runbook'
    (Search-BrainKnowledge -Path (Join-Path $script:root 'knowledge') -Query 'okapi' -VaultPath $v)[0].Ref | Should -Be 'vault:runbooks/okapi.md'
  }
}

Describe 'Entry points' {
  It '<_> carries the project notice' -ForEach @(
    'scripts/Sync-BrainSources.ps1', 'scripts/Get-VaultHarvest.ps1', 'scripts/Import-SizingEvidence.ps1', 'vault/avd_second_brain.ps1'
  ) {
    Get-Content (Join-Path $script:root $_) -Raw | Should -Match 'Personal project, not for production use'
  }
}
