# Compatibility rules for vault/avd_second_brain.ps1, which stays Windows PowerShell 5.1-compatible
# (CLAUDE.md) as well as running in PowerShell 7 on Windows, macOS and Linux.
@{
  IncludeRules = @('PSUseCompatibleSyntax', 'PSUseCompatibleCommands', 'PSUseCompatibleTypes')
  Rules        = @{
    PSUseCompatibleSyntax   = @{ Enable = $true; TargetVersions = @('5.1', '7.0') }
    PSUseCompatibleCommands = @{
      Enable         = $true
      TargetProfiles = @('win-48_x64_10.0.17763.0_5.1.17763.316_x64_4.0.30319.42000_framework', 'ubuntu_x64_18.04_7.0.0_x64_3.1.2_core', 'win-8_x64_10.0.17763.0_7.0.0_x64_3.1.2_core')
    }
    PSUseCompatibleTypes    = @{
      Enable         = $true
      TargetProfiles = @('win-48_x64_10.0.17763.0_5.1.17763.316_x64_4.0.30319.42000_framework', 'ubuntu_x64_18.04_7.0.0_x64_3.1.2_core', 'win-8_x64_10.0.17763.0_7.0.0_x64_3.1.2_core')
    }
  }
}
