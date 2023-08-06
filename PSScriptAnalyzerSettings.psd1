@{
  IncludeDefaultRules = $true
  ExcludeRules = @("PSAvoidUsingEmptyCatchBlock", "PSAvoidUsingWMICmdlet", "PSUseShouldProcessForStateChangingFunctions")
  Rules = @{
    PSUseCorrectCasing = @{   # confirmed working
      Enable = $true
    }
    PSAvoidSemicolonsAsLineTerminators = @{
      Enable = $true
    }
    PSUseCompatibleCmdlets = @{
      compatibility = @('desktop-5.1.14393.206-windows')
    }
  }
}
