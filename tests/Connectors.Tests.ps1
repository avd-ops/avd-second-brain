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
  function Get-TestFacts {
    # A minimal avd-current-state-facts/v1 snapshot (contract C11), as avd_current_state_facts.ps1 writes it.
    [ordered]@{
      schema = 'avd-current-state-facts/v1'; estate = 'est-0a1b2c3d'; generatedUtc = '2026-10-18T09:00:00Z'
      producer = [ordered]@{ name = 'avd_current_state_facts.ps1'; version = '1.0.0' }
      sources = @([ordered]@{ kind = 'collector'; generatedUtc = '2026-10-18T08:00:00Z'; manifestSha256 = ('ab' * 32) })
      subscriptions = @([ordered]@{
          id = 'sub-1a2b3c4d'; collectedUtc = '2026-10-18T08:00:00Z'; regions = @('eastus2'); counts = [ordered]@{ avdHostPools = 1; virtualMachines = 4 }
          hostPools = @([ordered]@{ id = 'hp-2b3c4d5e'; region = 'eastus2'; type = 'Pooled'; loadBalancer = 'BreadthFirst'; maxSessionLimit = 12
              sessionHosts = [ordered]@{ total = 4; status = [ordered]@{ Available = 3; Unavailable = 1 }; staleHeartbeat = 1 }
              vmSizes = [ordered]@{ Standard_D4ads_v5 = 4 }; images = @([ordered]@{ publisher = 'custom'; hosts = 4 }) })
          virtualMachines = [ordered]@{ total = 4 }
          storageAccounts = @([ordered]@{ id = 'st-3c4d5e6f'; kind = 'FileStorage'; sku = 'Premium_LRS'; privateEndpoint = $true })
          network = [ordered]@{ virtualNetworks = 1 }; keyVaults = [ordered]@{ total = 0 }; logAnalytics = [ordered]@{ total = 1 }
          policy = [ordered]@{ assignments = 2 }; roleAssignments = [ordered]@{ roles = [ordered]@{ 'Desktop Virtualization User' = 1 } } })
      validations = @([ordered]@{ subscription = 'sub-1a2b3c4d'; mode = 'PostDeployment'; generatedUtc = '2026-10-18T08:30:00Z'; verdict = 'FAIL'
          checks = @([ordered]@{ phase = 'PostDeployment'; category = 'SessionHost'; check = 'Heartbeat freshness'; status = 'FAIL'; target = 'hp-2b3c4d5e' }) })
      redactedValues = 0
    }
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

Describe 'avd-current-state facts (C11) -> estate facts store' {
  BeforeAll {
    $script:factsSchema = Join-Path $script:root 'contracts/schemas/current-state-facts.schema.json'
    $script:importer = Join-Path $script:root 'scripts/Import-CurrentStateFacts.ps1'
    function Save-TestFacts { param($Data, [string] $Name = 'facts.json') $p = Join-Path $TestDrive $Name; $Data | ConvertTo-Json -Depth 12 | Set-Content $p; $p }
  }
  It 'accepts a clean snapshot' {
    $r = Test-CurrentStateFacts -File (Save-TestFacts (Get-TestFacts)) -SchemaFile $script:factsSchema
    $r.Findings | Should -BeNullOrEmpty
    $r.Document.subscriptions[0].hostPools[0].sessionHosts.total | Should -Be 4
  }
  It 'has no field for a name: <Why>' -ForEach @(
    @{ Why = 'a host pool name'; Change = { param($f) $f.subscriptions[0].hostPools[0]['name'] = 'hp-finance' } }
    @{ Why = 'a real resource ID as the pseudonym'; Change = { param($f) $f.subscriptions[0].id = '/subscriptions/x' } }
    @{ Why = 'a validator scope'; Change = { param($f) $f.validations[0].checks[0]['scope'] = 'hp-finance' } }
    @{ Why = 'free text in a check name'; Change = { param($f) $f.validations[0].checks[0].check = "Host on line`nbreak" } }
  ) {
    $f = Get-TestFacts
    & $Change $f
    $r = Test-CurrentStateFacts -File (Save-TestFacts $f) -SchemaFile $script:factsSchema
    @($r.Findings | Where-Object Check -eq 'schema').Count | Should -Be 1
  }
  It 'runs the guard over what the schema lets through' {
    $f = Get-TestFacts
    $f.validations[0].checks[0].check = 'Owner 0f1e2d3c-4b5a-4968-8778-695a4b3c2d1e'
    $r = Test-CurrentStateFacts -File (Save-TestFacts $f) -SchemaFile $script:factsSchema
    $r.Findings.Check | Should -Contain 'sensitive:guid'
  }
  It 'warns when a check points at something the snapshot does not describe' {
    $f = Get-TestFacts
    $f.validations[0].checks[0].target = 'hp-99999999'
    (Test-CurrentStateFacts -File (Save-TestFacts $f) -SchemaFile $script:factsSchema).Findings.Check | Should -Be 'facts:unknown-target'
  }
  It 'files a clean snapshot in the vault by estate and time, and refuses this repo' {
    $file = Save-TestFacts (Get-TestFacts)
    $vault = Join-Path $TestDrive 'facts-vault'
    New-Item -ItemType Directory -Force $vault | Out-Null
    & $script:importer -FactsPath $file -VaultPath $vault -Apply 6>$null
    Join-Path $vault 'facts/est-0a1b2c3d/20261018T090000Z.json' | Should -Exist
    pwsh -NoProfile -File $script:importer -FactsPath $file -VaultPath $script:root -Apply *>$null
    $LASTEXITCODE | Should -Be 1
  }
  It 'refuses a snapshot that fails the guard' {
    $f = Get-TestFacts
    $f.validations[0].checks[0].check = 'Share 10.20.30.40'
    pwsh -NoProfile -File $script:importer -FactsPath (Save-TestFacts $f 'leak.json') *>$null
    $LASTEXITCODE | Should -Be 1
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

Describe 'Foundation contracts vendored from avd-assess (decision 0021)' {
  BeforeAll {
    $script:contracts = Join-Path $script:root 'contracts'
    $script:pins = Get-Content (Join-Path $script:contracts 'FOUNDATION-PINS.json') -Raw | ConvertFrom-Json
  }

  It 'pins a commit of avd-assess' {
    $script:pins.source | Should -Be 'https://github.com/nickprignano/avd-assess'
    $script:pins.assessCommit | Should -Match '^[0-9a-f]{40}$'
  }

  It 'every foundation file is byte-identical to avd-assess at the pinned commit' {
    foreach ($p in $script:pins.files.PSObject.Properties) {
      $file = Join-Path $script:contracts $p.Name
      Test-Path -LiteralPath $file | Should -BeTrue -Because "$($p.Name) is pinned"
      (Get-FileHash -LiteralPath $file -Algorithm SHA256).Hash.ToLowerInvariant() | Should -Be $p.Value -Because "$($p.Name) is a copy; change it in avd-assess first"
    }
  }

  It 'covers the foundation contracts and none of the brain''s own' {
    $names = @($script:pins.files.PSObject.Properties.Name)
    foreach ($f in 'fact-register.json', 'schemas/current-state-facts.schema.json', 'schemas/intake.schema.json', 'schemas/assess-method.schema.json', 'schemas/assessment.schema.json', 'schemas/run-record.schema.json') {
      $names | Should -Contain $f
    }
    foreach ($f in 'schemas/target-state.schema.json', 'schemas/target-approval.schema.json', 'schemas/sizing-evidence.schema.json', 'schemas/doc-findings.schema.json') {
      $names | Should -Not -Contain $f -Because 'the brain keeps its own contracts'
    }
  }
}

Describe 'Fact register (C15) and target-state manifest (C14)' {
  BeforeAll {
    $script:contracts = Join-Path $script:root 'contracts'
    $script:register = Get-Content (Join-Path $script:contracts 'fact-register.json') -Raw | ConvertFrom-Json
    $script:c11 = Get-Content (Join-Path $script:contracts 'schemas/current-state-facts.schema.json') -Raw | ConvertFrom-Json
    $script:manifestSchema = Join-Path $script:contracts 'schemas/target-state.schema.json'
    $script:example = Join-Path $script:contracts 'examples/target-state.example.json'
    $script:rules = Join-Path $script:root 'knowledge/rules'
    function Write-Manifest {
      param([scriptblock] $Change)
      $m = Get-Content $script:example -Raw | ConvertFrom-Json
      & $Change $m
      $f = Join-Path $TestDrive "m-$([guid]::NewGuid().ToString('n').Substring(0, 6)).json"
      $m | ConvertTo-Json -Depth 12 | Set-Content $f
      $f
    }
    function Get-ManifestCheck { param([string] $File) @((Test-TargetState -File $File -SchemaFile $script:manifestSchema -Register $script:register -RulesPath $script:rules).Findings | ForEach-Object Check) }
  }

  It 'the register matches its schema and every built fact resolves in its contract' {
    Test-Json -Path (Join-Path $script:contracts 'fact-register.json') -SchemaFile (Join-Path $script:contracts 'schemas/fact-register.schema.json') | Should -BeTrue
    $c19 = Get-Content (Join-Path $script:contracts 'schemas/intake.schema.json') -Raw | ConvertFrom-Json
    @(Test-FactRegister -Register $script:register -SchemaByContract @{ C11 = $script:c11; C19 = $c19 }) | Should -BeNullOrEmpty
    @($script:register.facts | Where-Object { $_.tier -eq 'intake' -and ($_.status -ne 'built' -or $_.contract -ne 'C19') }) | Should -BeNullOrEmpty -Because 'C19 gives every intake fact its path'
  }
  It 'puts every C12 group measure, the hourly series and the app catalog in the group-behavior class' {
    $c12 = @($script:register.facts | Where-Object { $_.id -like 'c12.group.*' })
    $behavior = @($c12 | Where-Object { $_.id -notin 'c12.group.users', 'c12.group.concurrency.peak', 'c12.group.perHost.peakSessionsPerHost', 'c12.group.apps.unknown' })
    $behavior.Count | Should -BeGreaterThan 10
    foreach ($f in $behavior) { $f.privacy | Should -Be 'group-behavior' -Because "$($f.id) describes a group's behavior" }
    @($script:register.facts | Where-Object { $_.privacy -eq 'group-behavior' -and $_.id -notlike 'c12.group.*' }) | Should -BeNullOrEmpty
    foreach ($m in 'CpuPercentOfCore', 'MemoryMiB', 'DiskIops') { "c12.group.perUser.p50$m" | Should -BeIn $c12.id -Because 'groups under 20 get p50, not p95' }
  }
  It 'catches a built fact whose path the contract no longer has' {
    $r = $script:register | ConvertTo-Json -Depth 8 | ConvertFrom-Json
    ($r.facts | Where-Object id -eq 'c11.hostPool.type').path = '/subscriptions/*/hostPools/*/kind'
    (Test-FactRegister -Register $r -SchemaByContract @{ C11 = $script:c11 }).Check | Should -Contain 'register:path-not-in-schema'
  }
  It 'every decision has an Azure-tier or a forensic-tier source, and the upsell split holds' {
    $azure = @($script:register.decisions | Where-Object { 'azure' -in $_.decidableFrom }).id
    $azure | Should -Be @('region', 'network', 'hostPool.type', 'hostPool.appGroup', 'hostPool.power')
    foreach ($d in $script:register.decisions) {
      @($script:register.facts | Where-Object { $d.id -in $_.evidences -and $_.status -ne 'proposed' }).Count | Should -BeGreaterThan 0 -Because "$($d.id) needs a fact that can support it"
    }
  }
  It 'accepts the example manifest' {
    $r = Test-TargetState -File $script:example -SchemaFile $script:manifestSchema -Register $script:register -RulesPath $script:rules
    $r.Document | Should -Not -BeNullOrEmpty
    $r.Findings | Should -BeNullOrEmpty
  }
  It 'the example approval pins the example manifest byte for byte' {
    $a = Join-Path $script:contracts 'examples/target-approval.example.json'
    Test-Json -Path $a -SchemaFile (Join-Path $script:contracts 'schemas/target-approval.schema.json') | Should -BeTrue
    (Get-Content $a -Raw | ConvertFrom-Json).manifestSha256 | Should -Be (Get-FileHash $script:example -Algorithm SHA256).Hash.ToLowerInvariant()
  }
  It 'refuses <Why>' -ForEach @(
    @{ Why = 'a fact that is not registered'; Check = 'manifest:unknown-fact'; Change = { param($m) $m.region.evidence = @('c11.hostPool.colour@hp-ac5fc5e3') } }
    @{ Why = 'a fact that cannot support the decision'; Check = 'manifest:fact-cannot-support'; Change = { param($m) $m.hostPools[0].vmSize.evidence = @('c11.network.virtualNetworks') } }
    @{ Why = 'a host pool fact without its subject'; Check = 'manifest:missing-subject'; Change = { param($m) $m.region.evidence = @('c11.hostPool.region') } }
    @{ Why = 'a proposed Liquidware fact'; Check = 'manifest:proposed-fact'; Change = { param($m) $m.identity.evidence = @('liquidware.version@hp-ac5fc5e3') } }
    @{ Why = 'a rule that does not exist'; Check = 'manifest:unknown-rule'; Change = { param($m) $m.hostPools[0].hosts | Add-Member rule 'spare-hosts@v1' } }
    @{ Why = 'a rule version from the future'; Check = 'manifest:future-rule'; Change = { param($m) $m.hostPools[0].vmSize.rule = 'workload-tiers@v9' } }
    @{ Why = 'too few hosts for the peak'; Check = 'manifest:capacity'; Change = { param($m) $m.hostPools[0].hosts.value = 6 } }
    @{ Why = 'gaps for a renderer we own'; Check = 'manifest:gaps'; Change = { param($m) $m.target.gaps = @('hostPools/0/type.Personal') } }
    @{ Why = 'another register version'; Check = 'manifest:register-version'; Change = { param($m) $m.pins.factRegister = 2 } }
  ) {
    Get-ManifestCheck (Write-Manifest $Change) | Should -Contain $Check
  }
  It 'has no field for <Why>' -ForEach @(
    @{ Why = 'a subscription ID'; Change = { param($m) $m | Add-Member subscriptionId '00000000-0000-0000-0000-000000000001' } }
    @{ Why = 'a group name'; Change = { param($m) $m.hostPools[0] | Add-Member usersGroup 'AVD Users' } }
    @{ Why = 'an app by name'; Change = { param($m) $m.hostPools[0].apps.image = @('Contoso Ledger 7') } }
    @{ Why = 'a URL in a note'; Change = { param($m) $m.region | Add-Member note 'see https://contoso.example/x' } }
    @{ Why = 'an approval inside the manifest'; Change = { param($m) $m | Add-Member approval @{ state = 'approved' } } }
  ) {
    Get-ManifestCheck (Write-Manifest $Change) | Should -Be @('schema')
  }
  It 'keeps estate pseudonyms out of knowledge/' {
    $k = Join-Path $TestDrive 'kb'
    Copy-Item -Recurse (Join-Path $script:root 'knowledge') $k
    Set-Content (Join-Path $k 'runbooks/leak.md') '# Seen on hp-ac5fc5e3 last week'
    (Test-BrainKnowledge -Path $k).Check | Should -Contain 'sensitive:estate-pseudonym'
  }
}

Describe 'Connected repositories' {
  It 'sources.json matches its schema and names the connected repos' {
    $file = Join-Path $script:root 'sources/sources.json'
    Test-Json -Json (Get-Content $file -Raw) -SchemaFile (Join-Path $script:root 'sources/sources.schema.json') | Should -BeTrue
    (Get-BrainSource -Path $file).name | Should -Be @('avd-readiness-stratusphere', 'avd-liquidware', 'avd-current-state', 'avd-landing-zone', 'avd-swarm')
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
    'scripts/Sync-BrainSources.ps1', 'scripts/Get-VaultHarvest.ps1', 'scripts/Import-SizingEvidence.ps1', 'scripts/Import-CurrentStateFacts.ps1', 'vault/avd_second_brain.ps1',
    'scripts/Test-DocConsistency.ps1', 'scripts/Update-BrainDocs.ps1'
  ) {
    Get-Content (Join-Path $script:root $_) -Raw | Should -Match 'Personal project, not for production use'
  }
}

Describe 'C13 avd-doc-findings/v1' {
  BeforeAll {
    $script:c13 = Join-Path $script:root 'contracts/schemas/doc-findings.schema.json'
    function Get-TestFindingJson {
      param([scriptblock] $Change = {})
      $f = Get-DocFinding -Check D7 -Severity error -Repo 'avd-second-brain' -Path 'README.md' -Line 14 -Says 'the table lists 3 repos without avd-swarm' -Truth 'sources/sources.json connects avd-swarm' -Generated
      $f = [pscustomobject]([ordered]@{ id = 'D7-0001' } + [ordered]@{} + ($f.PSObject.Properties | ForEach-Object -Begin { $h = [ordered]@{} } -Process { $h[$_.Name] = $_.Value } -End { $h }))
      & $Change $f
      $repo = [pscustomobject]@{ Name = 'avd-second-brain'; Commit = 'd2415e6' }
      Get-DocFindingDocument -Finding @($f) -Repo @($repo) | ConvertTo-Json -Depth 6
    }
  }
  It 'what Test-DocConsistency.ps1 writes matches the schema' {
    Test-Json -Json (Get-TestFindingJson) -SchemaFile $script:c13 | Should -BeTrue
  }
  It 'refuses <name>' -ForEach @(
    @{ name = 'an unknown severity'; change = { param($f) $f.severity = 'info' } }
    @{ name = 'a judge finding marked as an error'; change = { param($f) $f.origin = 'judge' } }
    @{ name = 'a check that does not exist'; change = { param($f) $f.check = 'D12' } }
    @{ name = 'free text beyond says and truth'; change = { param($f) $f | Add-Member note 'anything' } }
  ) {
    Test-Json -Json (Get-TestFindingJson -Change $change) -SchemaFile $script:c13 -ErrorAction SilentlyContinue | Should -BeFalse
  }
  It 'contracts.md lists C13 as built, with this schema' {
    $c = @(Get-DocContract -Text (Get-Content (Join-Path $script:root 'docs/contracts.md') -Raw) | Where-Object Id -eq 'C13')[0]
    $c.Built | Should -BeTrue
    $c.Schemas | Should -Contain 'doc-findings.schema.json'
  }
}

Describe 'C17 avd-run-record/v1' {
  BeforeAll {
    $script:c17 = Join-Path $script:root 'contracts'
    $script:runSchema = Join-Path $script:c17 'schemas/run-record.schema.json'
    $script:journalSchema = Join-Path $script:c17 'schemas/run-journal.schema.json'
    $script:costSchema = Join-Path $script:c17 'schemas/run-cost.schema.json'
    $script:examples = Join-Path $script:c17 'examples/run-record'
    $script:useCases = @((Get-Content (Join-Path $script:c17 'run-use-cases.json') -Raw | ConvertFrom-Json).useCases.id)
  }
  It 'the example run, cost and every journal line match the schemas' {
    Test-Json -Path (Join-Path $script:examples 'run.example.json') -SchemaFile $script:runSchema | Should -BeTrue
    Test-Json -Path (Join-Path $script:examples 'cost.example.json') -SchemaFile $script:costSchema | Should -BeTrue
    foreach ($line in Get-Content (Join-Path $script:examples 'journal.example.jsonl')) {
      Test-Json -Json $line -SchemaFile $script:journalSchema | Should -BeTrue
    }
  }
  It 'every use case in the examples is registered' {
    $run = Get-Content (Join-Path $script:examples 'run.example.json') -Raw | ConvertFrom-Json
    $script:useCases | Should -Contain $run.useCase
    foreach ($k in $run.extensions.PSObject.Properties.Name) { if ($k -notlike 'x-*') { $script:useCases | Should -Contain $k } }
    foreach ($line in Get-Content (Join-Path $script:examples 'journal.example.jsonl')) {
      $e = $line | ConvertFrom-Json
      if ($e.event -like 'x.*') { $script:useCases | Should -Contain $e.useCase }
    }
  }
  It 'refuses a price on an estimate line that matched no single meter' {
    $c = Get-Content (Join-Path $script:examples 'cost.example.json') -Raw | ConvertFrom-Json
    $c.expected.lines[1].cost = 1.5
    Test-Json -Json ($c | ConvertTo-Json -Depth 8) -SchemaFile $script:costSchema -ErrorAction SilentlyContinue | Should -BeFalse
  }
  It 'refuses <name>' -ForEach @(
    @{ name = 'an unregistered core event'; line = '{"v":1,"event":"deploy.done","runId":"run-20261020-1652-k3p9","ts":"2026-10-20T16:52:00Z"}' }
    @{ name = 'an extension event without its use case'; line = '{"v":1,"event":"x.liquidware-tier.package","runId":"run-20261020-1652-k3p9","ts":"2026-10-20T16:52:00Z"}' }
    @{ name = 'a check without a status'; line = '{"v":1,"event":"check","runId":"run-20261020-1652-k3p9","ts":"2026-10-20T16:52:00Z","area":"a","check":"c"}' }
    @{ name = 'a run ID the portal would not generate'; line = '{"v":1,"event":"operator.note","runId":"my-run","ts":"2026-10-20T16:52:00Z","text":"x"}' }
  ) {
    Test-Json -Json $line -SchemaFile $script:journalSchema -ErrorAction SilentlyContinue | Should -BeFalse
  }
  It 'contracts.md lists C17 as built, with its three schemas' {
    $c = @(Get-DocContract -Text (Get-Content (Join-Path $script:root 'docs/contracts.md') -Raw) | Where-Object Id -eq 'C17')[0]
    $c.Built | Should -BeTrue
    foreach ($s in 'run-record.schema.json', 'run-journal.schema.json', 'run-cost.schema.json') { $c.Schemas | Should -Contain $s }
    $c.Formats | Should -Contain 'avd-run-record/v1'
  }
}

Describe 'C19 to C21: intake, the assessment method and its report' {
  BeforeAll {
    $script:schemas = Join-Path $script:root 'contracts/schemas'
    $script:ex = Join-Path $script:root 'contracts/examples/assess'
    $script:register = Get-Content (Join-Path $script:root 'contracts/fact-register.json') -Raw | ConvertFrom-Json
    $script:reportSchema = Join-Path $script:schemas 'assessment.schema.json'
    function Save-Changed {
      param([string] $Name, [scriptblock] $Change)
      $d = Get-Content (Join-Path $script:ex $Name) -Raw | ConvertFrom-Json
      & $Change $d
      $f = Join-Path $TestDrive "$([guid]::NewGuid().ToString('n').Substring(0, 6))-$Name"
      $d | ConvertTo-Json -Depth 12 | Set-Content $f
      $f
    }
    function Get-MethodCheck {
      param([string] $Index = (Join-Path $script:ex 'index.example.json'), [string] $Method = (Join-Path $script:ex 'method.example.json'))
      @((Test-AssessMethod -IndexFile $Index -MethodFile $Method -SchemaPath $script:schemas -Register $script:register).Findings | ForEach-Object Check)
    }
    function Get-ReportCheck {
      param([string] $File)
      $m = Get-Content (Join-Path $script:ex 'method.example.json') -Raw | ConvertFrom-Json
      @((Test-AssessmentReport -File $File -SchemaFile $script:reportSchema -Method $m -Register $script:register).Findings | ForEach-Object Check)
    }
  }

  It 'the intake example matches avd-intake/v1' {
    Test-Json -Path (Join-Path $script:ex 'intake.example.json') -SchemaFile (Join-Path $script:schemas 'intake.schema.json') | Should -BeTrue
  }
  It 'intake has no field for <Why>' -ForEach @(
    @{ Why = 'a domain name'; Change = { param($d) $d | Add-Member domain 'contoso.com' } }
    @{ Why = 'a free-text identity answer'; Change = { param($d) $d.identityConstraints = 'we use AD at head office' } }
    @{ Why = 'residency regions when residency is not required'; Change = { param($d) $d.residency.required = $false } }
    @{ Why = 'a hub given by name'; Change = { param($d) $d.existingHub = 'hub-vnet-prod' } }
  ) {
    $f = Save-Changed 'intake.example.json' $Change
    Test-Json -Path $f -SchemaFile (Join-Path $script:schemas 'intake.schema.json') -ErrorAction SilentlyContinue | Should -BeFalse
  }
  It 'accepts the example index and method' {
    Get-MethodCheck | Should -BeNullOrEmpty
  }
  It 'every decision in the register has one readiness row in the example method' {
    $m = Get-Content (Join-Path $script:ex 'method.example.json') -Raw | ConvertFrom-Json
    @($m.readiness.decision | Sort-Object) | Should -Be @($script:register.decisions.id | Sort-Object)
  }
  It 'refuses a method with <Why>' -ForEach @(
    @{ Why = 'a claim no reference has'; Check = 'method:unknown-claim'; Change = { param($m) $m.checks[0].claims = @('ref:review-checklists-avd#Z99.99') } }
    @{ Why = 'a gap that does not exist'; Check = 'method:unknown-claim'; Change = { param($m) $m.collection[0].claims = @('gap:telepathy') } }
    @{ Why = 'a fact that is not registered'; Check = 'method:unknown-fact'; Change = { param($m) $m.checks[1].facts = @('c11.storage.colour') } }
    @{ Why = 'a check on a fact not built yet'; Check = 'method:fact-not-citable'; Change = { param($m) $m.checks[1].facts = @('c12.group.users') } }
    @{ Why = 'a decision that does not exist'; Check = 'method:unknown-decision'; Change = { param($m) $m.checks[0].informs = @('hostPool.colour') } }
    @{ Why = 'a decision left without readiness'; Check = 'method:readiness-missing'; Change = { param($m) $m.readiness = @($m.readiness | Where-Object decision -ne 'region') } }
    @{ Why = 'sizing called decidable from Azure alone'; Check = 'method:readiness-register'; Change = { param($m) ($m.readiness | Where-Object decision -eq 'hostPool.vmSize').readiness = 'decidable' } }
    @{ Why = 'decidable with intake but no intake fact'; Check = 'method:readiness-facts'; Change = { param($m) ($m.readiness | Where-Object decision -eq 'hostPool.power').facts = @('c11.hostPool.startVmOnConnect') } }
    @{ Why = 'a readiness fact that cannot support the decision'; Check = 'method:fact-cannot-support'; Change = { param($m) ($m.readiness | Where-Object decision -eq 'hostPool.type').facts = @('c11.hostPool.type', 'c11.policy.assignments') } }
    @{ Why = 'an Azure fact said to come from intake'; Check = 'method:collection-source'; Change = { param($m) $m.collection[0].from = 'intake' } }
    @{ Why = 'the same check twice'; Check = 'method:duplicate-check'; Change = { param($m) $m.checks[1].id = $m.checks[0].id } }
    @{ Why = 'another register version'; Check = 'method:register-version'; Change = { param($m) $m.factRegister = 9 } }
    @{ Why = 'a code expression in a rule'; Check = 'schema'; Change = { param($m) $m.checks[0].rule.expect = @{ startVmOnConnect = @{ script = '$true' } } } }
    @{ Why = 'an overall score'; Check = 'schema'; Change = { param($m) $m.scoring.overall = $true } }
  ) {
    Get-MethodCheck -Method (Save-Changed 'method.example.json' $Change) | Should -Contain $Check
  }
  It 'refuses an index with <Why>' -ForEach @(
    @{ Why = 'an observation of a claim no reference has'; Check = 'index:unknown-claim'; Change = { param($x) $x.observations[0].claim = 'ref:avd-prerequisites#rtt-under-5' } }
    @{ Why = 'a pin that can move'; Check = 'schema'; Change = { param($x) $x.references[0].pin = 'https://github.com/MicrosoftDocs/windowsserverdocs/blob/main/x.md' } }
    @{ Why = 'a verdict without evidence'; Check = 'schema'; Change = { param($x) $x.observations[0].evidence = @() } }
    @{ Why = 'evidence that is not pinned'; Check = 'schema'; Change = { param($x) $x.observations[0].evidence = @('https://github.com/nickprignano/avd-landing-zone/blob/master/build/lessons/0003-region-latency.md') } }
    @{ Why = 'an email in our own words'; Check = 'sensitive:email-or-upn'; Change = { param($x) $x.observations[0].observed = 'Measured by ops at fabrikam.net, see admin@fabrikam.net' } }
  ) {
    Get-MethodCheck -Index (Save-Changed 'index.example.json' $Change) | Should -Contain $Check
  }
  It 'scores a pillar as passing weight over assessed weight, warn at half' {
    $m = Get-Content (Join-Path $script:ex 'method.example.json') -Raw | ConvertFrom-Json
    $s = @(Get-AssessScore -Method $m -Result @([pscustomobject]@{ check = 'asm-personal-start-vm-on-connect'; outcome = 'warn' }, [pscustomobject]@{ check = 'asm-profile-storage-private-endpoint'; outcome = 'unknown' }))
    ($s | Where-Object pillar -eq 'cost').score | Should -Be 0.5
    $sec = $s | Where-Object pillar -eq 'security'
    $sec.score | Should -BeNullOrEmpty
    $sec.coverage | Should -Be 0
  }
  It 'accepts the example report against the example method, hash included' {
    $m = Get-Content (Join-Path $script:ex 'method.example.json') -Raw | ConvertFrom-Json
    $sha = (Get-FileHash (Join-Path $script:ex 'method.example.json') -Algorithm SHA256).Hash.ToLowerInvariant()
    (Test-AssessmentReport -File (Join-Path $script:ex 'assessment.example.json') -SchemaFile $script:reportSchema -Method $m -MethodSha256 $sha -Register $script:register).Findings | Should -BeNullOrEmpty
  }
  It 'refuses a report with <Why>' -ForEach @(
    @{ Why = 'a check missing'; Check = 'report:missing-check'; Change = { param($r) $r.results = @($r.results[0]) } }
    @{ Why = 'a check the method does not have'; Check = 'report:unknown-check'; Change = { param($r) $r.results[1].check = 'asm-not-in-method' } }
    @{ Why = 'a fact the check does not use'; Check = 'report:fact-not-in-check'; Change = { param($r) $r.results[1].facts = @('c11.hostPool.type') } }
    @{ Why = 'an outcome better than its subjects'; Check = 'report:rollup'; Change = { param($r) $r.results[0].outcome = 'pass' } }
    @{ Why = 'a guessed outcome with no subjects'; Check = 'report:rollup'; Change = { param($r) $r.results[1].subjects = @() } }
    @{ Why = 'a score that does not recompute'; Check = 'report:score'; Change = { param($r) $r.pillars[0].score = 0.9 } }
    @{ Why = 'sizing marked supported'; Check = 'report:decision-status'; Change = { param($r) ($r.decisions | Where-Object decision -eq 'hostPool.vmSize').status = 'supported' } }
    @{ Why = 'region supported without intake'; Check = 'report:decision-status'; Change = { param($r) $r.inputs.intake = $null } }
    @{ Why = 'a decision missing'; Check = 'report:decision'; Change = { param($r) $r.decisions = @($r.decisions | Where-Object decision -ne 'network') } }
    @{ Why = 'another method version'; Check = 'report:method-version'; Change = { param($r) $r.method.version = 2 } }
    @{ Why = 'a host pool name as a subject'; Check = 'schema'; Change = { param($r) $r.results[0].subjects[0].id = 'hp-finance' } }
    @{ Why = 'free text'; Check = 'schema'; Change = { param($r) $r.results[0] | Add-Member note 'owner asked to keep it off' } }
  ) {
    Get-ReportCheck (Save-Changed 'assessment.example.json' $Change) | Should -Contain $Check
  }
  It 'contracts.md lists C19, C20 and C21 as built, with their schemas' {
    $all = @(Get-DocContract -Text (Get-Content (Join-Path $script:root 'docs/contracts.md') -Raw))
    $want = @{ C19 = @('intake.schema.json'); C20 = @('assess-index.schema.json', 'assess-method.schema.json'); C21 = @('assessment.schema.json') }
    foreach ($id in $want.Keys) {
      $c = @($all | Where-Object Id -eq $id)[0]
      $c.Built | Should -BeTrue -Because "$id has its schema and tests"
      foreach ($s in $want[$id]) { $c.Schemas | Should -Contain $s }
    }
  }
}

Describe 'C18 avd-lifecycle-record/v1' {
  BeforeAll {
    $script:c18 = Join-Path $script:root 'contracts'
    $script:lcSchema = Join-Path $script:c18 'schemas/lifecycle-record.schema.json'
    $script:lcExample = Join-Path $script:c18 'examples/lifecycle-record.example.json'
    $script:lcRegister = Get-Content (Join-Path $script:c18 'fact-register.json') -Raw | ConvertFrom-Json
    $script:lcRules = Join-Path $script:root 'knowledge/rules'
    function Write-Lifecycle {
      param([scriptblock] $Change)
      $m = Get-Content $script:lcExample -Raw | ConvertFrom-Json
      & $Change $m
      $f = Join-Path $TestDrive "lc-$([guid]::NewGuid().ToString('n').Substring(0, 6)).json"
      $m | ConvertTo-Json -Depth 12 | Set-Content $f
      $f
    }
    function Get-LifecycleFinding { param([string] $File) @((Test-LifecycleRecord -File $File -SchemaFile $script:lcSchema -Register $script:lcRegister -RulesPath $script:lcRules).Findings) }
  }

  It 'accepts the example record' {
    $r = Test-LifecycleRecord -File $script:lcExample -SchemaFile $script:lcSchema -Register $script:lcRegister -RulesPath $script:lcRules
    $r.Document | Should -Not -BeNullOrEmpty
    $r.Findings | Should -BeNullOrEmpty
  }
  It 'refuses <Why>' -ForEach @(
    @{ Why = 'a fact that is not registered'; Check = 'lifecycle:unknown-fact'; Change = { param($m) $m.decisions[0].evidence = @('c11.hostPool.colour@hp-5e6f7a8b') } }
    @{ Why = 'a host pool fact without its subject'; Check = 'lifecycle:missing-subject'; Change = { param($m) $m.decisions[0].watch = @('c12.group.rttMsP95') } }
    @{ Why = 'a proposed Liquidware fact'; Check = 'lifecycle:proposed-fact'; Change = { param($m) $m.decisions[3].evidence = @('liquidware.version@hp-5e6f7a8b') } }
    @{ Why = 'a rule that does not exist'; Check = 'lifecycle:unknown-rule'; Change = { param($m) $m.decisions[1].evidence = @('rule:spare-hosts@v1') } }
    @{ Why = 'a rule version from the future'; Check = 'lifecycle:future-rule'; Change = { param($m) $m.decisions[1].evidence = @('rule:workload-tiers@v9') } }
    @{ Why = 'a topic nobody knows'; Check = 'lifecycle:unknown-topic'; Change = { param($m) $m.decisions[3].topic = 'vibes' } }
    @{ Why = 'a use case the record does not have'; Check = 'lifecycle:unknown-use-case'; Change = { param($m) $m.events[0].useCases = @('uc-09') } }
    @{ Why = 'an event carrying out a decision that does not exist'; Check = 'lifecycle:unknown-decision'; Change = { param($m) $m.events[1].decisions = @('dec-0099') } }
    @{ Why = 'evidence pointing at an event that does not exist'; Check = 'lifecycle:unknown-event'; Change = { param($m) $m.events[3].evidence = @('evt-0042') } }
    @{ Why = 'a superseded decision still accepted'; Check = 'lifecycle:supersede-status'; Change = { param($m) $m.decisions[2].status = 'accepted' } }
    @{ Why = 'a decision superseded by nothing'; Check = 'lifecycle:superseded-by-nothing'; Change = { param($m) $m.decisions[1].status = 'superseded' } }
    @{ Why = 'a decision that supersedes a later one'; Check = 'lifecycle:supersede-order'; Change = { param($m) $m.decisions[5].date = '2026-11-01' } }
    @{ Why = 'a second birth'; Check = 'lifecycle:born'; Change = { param($m) $m.events[4].kind = 'born' } }
    @{ Why = 'an event before the birth'; Check = 'lifecycle:born'; Change = { param($m) $m.events[1].utc = '2026-12-01T00:00:00Z' } }
    @{ Why = 'a duplicate ID'; Check = 'lifecycle:duplicate-id'; Change = { param($m) $m.decisions[1].id = 'dec-0001' } }
    @{ Why = 'another register version'; Check = 'lifecycle:register-version'; Change = { param($m) $m.pins.factRegister = 2 } }
  ) {
    $f = @(Get-LifecycleFinding (Write-Lifecycle $Change))
    ($f | Where-Object Severity -eq 'Error').Check | Should -Contain $Check
  }
  It 'warns about <Why>' -ForEach @(
    @{ Why = 'a change no decision explains'; Check = 'lifecycle:unexplained-change'; Change = { param($m) $m.events[4].PSObject.Properties.Remove('decisions') } }
    @{ Why = 'drift no decision explains'; Check = 'lifecycle:unexplained-change'; Change = { param($m) $m.events[2].kind = 'drift' } }
    @{ Why = 'an accepted decision with no alternatives'; Check = 'lifecycle:no-alternatives'; Change = { param($m) $m.decisions[0].PSObject.Properties.Remove('alternatives') } }
    @{ Why = 'carrying out a rejected decision'; Check = 'lifecycle:rejected-decision-applied'; Change = { param($m) $m.decisions[3].status = 'rejected' } }
  ) {
    $f = @(Get-LifecycleFinding (Write-Lifecycle $Change))
    ($f | Where-Object Severity -eq 'Warning').Check | Should -Contain $Check
    ($f | Where-Object Severity -eq 'Error') | Should -BeNullOrEmpty
  }
  It 'has no field for <Why>' -ForEach @(
    @{ Why = 'a subscription ID'; Change = { param($m) $m | Add-Member subscriptionId '00000000-0000-0000-0000-000000000001' } }
    @{ Why = 'a person who decided'; Change = { param($m) $m.decisions[0].decidedBy = 'Sam Example' } }
    @{ Why = 'a user count instead of a bucket'; Change = { param($m) $m.useCases[0].users = 120 } }
    @{ Why = 'an app by name'; Change = { param($m) $m.useCases[0].apps = @('Contoso Ledger 7') } }
    @{ Why = 'a URL in a note'; Change = { param($m) $m.events[2].note = 'see https://contoso.example/x' } }
    @{ Why = 'a resource ID as a subject'; Change = { param($m) $m.events[0].subjects = @('/subscriptions/x/resourceGroups/rg-avd') } }
    @{ Why = 'free text as a reason'; Change = { param($m) $m.decisions[0].alternatives[0].whyNot = 'the customer did not like it' } }
  ) {
    @(Get-LifecycleFinding (Write-Lifecycle $Change)).Check | Should -Be @('schema')
  }
  It 'explains a host pool from its birth, following the design pool it was mapped from' {
    $doc = Get-Content $script:lcExample -Raw | ConvertFrom-Json
    $x = Get-LifecycleExplanation -Record $doc -Subject 'hp-5e6f7a8b'
    $x.Aliases | Should -Be @('tp-01')
    $x.UseCases.Id | Should -Be @('uc-01', 'uc-02')
    $x.InForce.Id | Should -Contain 'dec-0002'
    $x.InForce.Id | Should -Not -Contain 'dec-0003'
    ($x.InForce | Where-Object Id -eq 'dec-0006').Supersedes | Should -Be 'dec-0003'
    $x.History.Id | Should -Be @('evt-0001', 'evt-0003', 'evt-0005')
    $x.History[0].Utc | Should -Be '2026-12-07T15:20:00Z'
    ($x.History | Where-Object Id -eq 'evt-0005').Why.Id | Should -Be @('dec-0006')
    $x.Unexplained | Should -BeNullOrEmpty
    (Get-LifecycleExplanation -Record $doc -Subject 'hp-5e6f7a8b' -Topic 'hostPool.hosts').InForce.Id | Should -Be @('dec-0006')
  }
  It 'lists a change nothing explains' {
    $doc = Get-Content (Write-Lifecycle { param($m) $m.events[4].PSObject.Properties.Remove('decisions') }) -Raw | ConvertFrom-Json
    (Get-LifecycleExplanation -Record $doc -Subject 'hp-5e6f7a8b').Unexplained | Should -Be @('lifecycle:env-7d41c0e2#evt-0005')
  }
  It 'reopens a decision when a watched fact changes or its review date comes' {
    $doc = Get-Content $script:lcExample -Raw | ConvertFrom-Json
    $r = @(Get-LifecycleReview -Record $doc -Changed 'c12.group.concurrency.peak@hp-5e6f7a8b', 'c12.group.rttMsP95@hp-ac5fc5e3')
    $r.Decision | Should -Be @('dec-0006')
    $r[0].Reason | Should -Be 'watched-fact-changed'
    @(Get-LifecycleReview -Record $doc -AsOf '2027-05-15').Reason | Should -Be @('review-date')
    @(Get-LifecycleReview -Record $doc -AsOf '2027-05-14') | Should -BeNullOrEmpty
  }
  It 'starts a record from an approved manifest, one decision per register decision' {
    $m = Get-Content (Join-Path $script:c18 'examples/target-state.example.json') -Raw | ConvertFrom-Json
    $sha = (Get-FileHash (Join-Path $script:c18 'examples/target-state.example.json') -Algorithm SHA256).Hash.ToLowerInvariant()
    $d = @(ConvertFrom-TargetStateDecision -Manifest $m -ManifestSha256 $sha -Register $script:lcRegister -FirstNumber 7)
    $d.Count | Should -Be 10
    $d[0].id | Should -Be 'dec-0007'
    $d[0].date | Should -Be '2026-11-30'
    $vm = $d | Where-Object topic -eq 'hostPool.vmSize'
    $vm.subjects | Should -Be @('tp-01')
    $vm.decidedBy | Should -Be 'factory-rule'
    $vm.evidence | Should -Contain "manifest:$($sha.Substring(0, 12))#hostPool.vmSize"
    $vm.evidence | Should -Contain 'rule:workload-tiers@v1'
    $vm.alternatives[0].value | Should -Be 'Standard_D8as_v5' -Because 'a manifest carries what the design ruled out (Q5)'
    $f = Write-Lifecycle { param($r) $r.decisions = @($r.decisions) + @($d) }
    $found = @(Get-LifecycleFinding $f)
    ($found | Where-Object Severity -eq 'Error') | Should -BeNullOrEmpty
    @($found | Where-Object Check -eq 'lifecycle:no-alternatives').Count | Should -Be 9 -Because 'only the example vmSize decision lists what it ruled out; a person adds the rest'
  }
  It 'keeps environment pseudonyms out of knowledge/' {
    $k = Join-Path $TestDrive 'kb18'
    Copy-Item -Recurse (Join-Path $script:root 'knowledge') $k
    Set-Content (Join-Path $k 'runbooks/leak.md') '# Seen on env-7d41c0e2 last week'
    (Test-BrainKnowledge -Path $k).Check | Should -Contain 'sensitive:estate-pseudonym'
  }
  It 'contracts.md lists C18 as built, with its schema' {
    $c = @(Get-DocContract -Text (Get-Content (Join-Path $script:root 'docs/contracts.md') -Raw) | Where-Object Id -eq 'C18')[0]
    $c.Built | Should -BeTrue
    $c.Schemas | Should -Contain 'lifecycle-record.schema.json'
    $c.Formats | Should -Contain 'avd-lifecycle-record/v1'
  }
}
