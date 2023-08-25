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

InModuleScope $ProjectName {

    Describe -Tags Targets, TargetConsole 'Console target' {
        # Give time to the runspace to init the targets
        Start-Sleep -Milliseconds 100

        It 'should be available in the module' {
            $Targets = Get-LoggingAvailableTarget
            $Targets.Console | Should -Not -BeNullOrEmpty
        }

        It "shouldn't have required parameters" {
            $Targets = Get-LoggingAvailableTarget
            $Targets.Console.ParamsRequired | Should -BeNullOrEmpty
        }
    }
}
