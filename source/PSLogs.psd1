@{
    RootModule           = 'PSLogs.psm1'
    ModuleVersion        = '5.6.1'
    CompatiblePSEditions = @('Desktop', 'Core')
    PowerShellVersion    = '5.1'
    GUID                 = '13599ad2-2234-44f2-933f-ffbb2e8e64c6'
    Author               = 'Hannes Palmquist'
    CompanyName          = 'GetPS'
    Copyright            = '(c) Hannes Palmquist. All rights reserved.'
    Description          = 'Powershell Logging Module. Support multiple logging targets, including console, file, sqlite, winevent, gelf, slack etc.'
    NestedModules        = @()
    RequiredModules      = @()
    FunctionsToExport    = '*'
    CmdletsToExport      = '*'
    VariablesToExport    = '*'
    AliasesToExport      = '*'
    PrivateData          = @{
        PSData = @{
            LicenseUri               = 'https://github.com/hanpq/PSLogs/blob/main/LICENSE'
            RequireLicenseAcceptance = $false
            Prerelease               = ''
            Tags                     = @('PSEdition_Desktop', 'PSEdition_Core', 'Windows', 'Linux', 'MacOS')
            ProjectUri               = 'https://getps.dev/modules/PSLogs/getstarted'
            ReleaseNotes             = ''
        }
    }
}
