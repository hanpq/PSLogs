BeforeAll {

    $RootItem = Get-Item $PSScriptRoot
    while ($RootItem.GetDirectories().Name -notcontains 'source')
    {
        $RootItem = $RootItem.Parent
    }
    $ProjectPath = $RootItem.FullName
    $ModuleManifestFileInfo = Get-ChildItem $ProjectPath -Recurse -Filter '*.psd1' | Where-Object fullname -Like "*$([IO.Path]::DirectorySeparatorChar)output$([IO.Path]::DirectorySeparatorChar)$($RootItem.Name)$([IO.Path]::DirectorySeparatorChar)*"

    Remove-Module PSLogs -Force -ErrorAction SilentlyContinue

    Import-Module $ModuleManifestFileInfo.FullName -Force
}

AfterAll {
    Remove-Module PSLogs -Force -ErrorAction SilentlyContinue
}

Describe -Skip:($true) -Tags Targets, TargetTeams 'Teams target' {
    It 'should be available in the module' {
        $Targets = Get-LoggingAvailableTarget
        $Targets.Teams | Should -Not -BeNullOrEmpty
    }

    It 'should have two required parameters' {
        $Targets = Get-LoggingAvailableTarget
        $Targets.Teams.ParamsRequired | Should -Be @('WebHook')
    }

    It 'should call Invoke-RestMethod' {
        Mock Invoke-RestMethod -Verifiable

        $TargetImplementationPath = '{0}\..\..\source\include\Teams.ps1' -f $PSScriptRoot
        $Module = . $TargetImplementationPath

        $Message = [hashtable] @{
            level   = 'ERROR'
            levelno = 40
            message = 'Hello, Teams!'
        }

        $Configuration = @{
            WebHook = 'https://office.microsoft.com'
            Details = $true
            Colors  = $Module.Configuration.Colors.Default
        }

        & $Module.Logger $Message $Configuration

        Assert-MockCalled -CommandName 'Invoke-RestMethod' -Times 1 -Exactly
    }
}
