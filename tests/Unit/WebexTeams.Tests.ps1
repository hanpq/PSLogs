BeforeDiscovery {
    $RootItem = Get-Item $PSScriptRoot
    while ($RootItem.GetDirectories().Name -notcontains 'source')
    {
        $RootItem = $RootItem.Parent
    }
    $ProjectPath = $RootItem.FullName
    $ProjectName = (Get-ChildItem $ProjectPath\*\*.psd1 | Where-Object {
            ($_.Directory.Name -eq 'source') -and
            $(try
                {
                    Test-ModuleManifest $_.FullName -ErrorAction Stop
                }
                catch
                {
                    $false
                })
        }
    ).BaseName

    Import-Module $ProjectName -Force

}

Describe -Tags Targets, TargetWebexTeams 'WebexTeams target' {
    It 'should be available in the module' {
        $Targets = Get-LoggingAvailableTarget
        $Targets.WebexTeams | Should -Not -BeNullOrEmpty
    }

    It 'should have two required parameters' {
        $Targets = Get-LoggingAvailableTarget
        $Targets.WebexTeams.ParamsRequired | Should -Be @('BotToken', 'RoomID')
    }

    It 'should call Invoke-RestMethod' -Skip {
        Mock Invoke-RestMethod -Verifiable

        $TargetImplementationPath = '{0}\..\..\source\include\WebexTeams.ps1' -f $PSScriptRoot
        $Module = . $TargetImplementationPath

        $Log = [hashtable] @{
            level   = 'ERROR'
            levelno = 40
            message = 'Hello, WebexTeams!'
        }

        $Configuration = @{
            BotToken = 'SOMEINVALIDTOKEN'
            RoomID   = 'SOMEINVALIDROOMID'
            Icons    = @{}
        }

        & $Module.Logger $Log $Configuration

        Assert-MockCalled -CommandName 'Invoke-RestMethod' -Times 1 -Exactly
    }
}
