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
    @(Test-FactRegister -Register $script:register -SchemaByContract @{ C11 = $script:c11 }) | Should -BeNullOrEmpty
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
