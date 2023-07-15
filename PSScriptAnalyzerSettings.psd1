# Use the PowerShell extension setting `powershell.scriptAnalysis.settingsPath` to get the current workspace
# to use this PSScriptAnalyzerSettings.psd1 file to configure code analysis in Visual Studio Code.
# This setting is configured in the workspace's `.vscode\settings.json`.
#
# For more information on PSScriptAnalyzer settings see:
# https://github.com/PowerShell/PSScriptAnalyzer/blob/master/README.md#settings-support-in-scriptanalyzer
#
# You can see the predefined PSScriptAnalyzer settings here:
# https://github.com/PowerShell/PSScriptAnalyzer/tree/master/Engine/Settings
@{
  # Only diagnostic records of the specified severity will be generated.
  # Uncomment the following line if you only want Errors and Warnings but
  # not Information diagnostic records.
  Severity = @('Error', 'Warning', 'Information')

  # Analyze **only** the following rules. Use IncludeRules when you want
  # to invoke only a small subset of the default rules.
  # IncludeRules = @('PSAvoidDefaultValueSwitchParameter',
  #                  'PSMisleadingBacktick',
  #                  'PSMissingModuleManifestField',
  #                  'PSReservedCmdletChar',
  #                  'PSReservedParams',
  #                  'PSShouldProcess',
  #                  'PSUseApprovedVerbs',
  #                  'PSAvoidUsingCmdletAliases',
  #                  'PSUseDeclaredVarsMoreThanAssignments')

  # Do not analyze the following rules. Use ExcludeRules when you have
  # commented out the IncludeRules settings above and want to include all
  # the default rules except for those you exclude below.
  # Note: if a rule is in both IncludeRules and ExcludeRules, the rule
  # will be excluded.
  ExcludeRules = @('PSAvoidUsingWMICmdlet')

  # You can use rule configuration to configure rules that support it:
  Rules = @{
    PSAvoidSemicolonsAsLineTerminators = @{
      Enable = $true
    }
    PSUseCompatibleCmdlets = @{
      compatibility = @('desktop-5.1.22621.1778-windows.json')
    }
    PSUseCompatibleCommands = @{
      Enable = $true
      TargetProfile = @('win-4_x64_10.0.17763.0_6.2.4_x64_3.1.2_core')
    }
    PSUseCompatibleSyntax = @{
      Enable = $true
      TargetVersions = @(
        '6.0'
      )
    }
    PSUseCompatibleTypes = @{
      Enable = $true
      TargetProfiles = @(
        'win-4_x64_10.0.17763.0_6.2.4_x64_3.1.2_core'
      )
    }
    PSUseConsistentIndentation = @{
      Enable = $true
      IndentationSize = 2
      PipelineIndentation = 'IncreaseIndentationForFirstPipeline'
      Kind = 'space'
    }
    PSUseCorrectCasing = @{
      Enable = $true
    }
  }
}