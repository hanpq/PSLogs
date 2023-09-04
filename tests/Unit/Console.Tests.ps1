BeforeAll {

    $RootItem = Get-Item $PSScriptRoot
    while ($RootItem.GetDirectories().Name -notcontains 'source')
    {
        $RootItem = $RootItem.Parent
    }
    $ProjectPath = $RootItem.FullName
    $ModuleManifestFileInfo = Get-ChildItem $ProjectPath -Recurse -Filter '*.psd1' | Where-Object fullname -Like "*\output\$($RootItem.Name)\*"

    Remove-Module $ModuleManifestFileInfo.BaseName -Force -ErrorAction SilentlyContinue

    Import-Module $ModuleManifestFileInfo.BaseName -Force
}

AfterAll {
    Remove-Module $ModuleManifestFileInfo.BaseName -Force
}

InModuleScope PSLogs {

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
