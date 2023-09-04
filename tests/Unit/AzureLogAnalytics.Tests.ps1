BeforeAll {

    $RootItem = Get-Item $PSScriptRoot
    while ($RootItem.GetDirectories().Name -notcontains 'source')
    {
        $RootItem = $RootItem.Parent
    }
    $ProjectPath = $RootItem.FullName
    $ModuleManifestFileInfo = Get-ChildItem $ProjectPath -Recurse -Filter '*.psd1' | Where-Object fullname -Like "*\output\$($RootItem.Name)\*"

    Remove-Module PSLogs -Force -ErrorAction SilentlyContinue

    Import-Module $ModuleManifestFileInfo.FullName -Force
}

AfterAll {
    Remove-Module PSLogs -Force
}

InModuleScope PSLogs {
    Describe -Tags Targets, TargetAzureLogAnalytics 'AzureLogAnalytics target' {
        It 'should be available in the module' {
            $Targets = Get-LoggingAvailableTarget
            $Targets.AzureLogAnalytics | Should -Not -BeNullOrEmpty
        }

        It 'should have two required parameters' {
            $Targets = Get-LoggingAvailableTarget
            $Targets.AzureLogAnalytics.ParamsRequired | Should -Be @('SharedKey', 'WorkspaceId')
        }

        It 'should call Invoke-WebRequest' {

            $TargetImplementationPath = '{0}\..\..\source\include\AzureLogAnalytics.ps1' -f $PSScriptRoot
            $Module = . $TargetImplementationPath

            Mock Invoke-WebRequest -Verifiable

            $Log = [hashtable] @{
                timestamp    = Get-Date -UFormat '%Y-%m-%dT%T%Z'
                timestamputc = '2020-02-24T22:35:23.000Z'
                level        = 'INFO'
                levelno      = 20
                lineno       = 1
                pathname     = 'c:\Scripts\Script.ps1'
                filename     = 'TestScript.ps1'
                caller       = 'TestScript.ps1'
                message      = 'Hello, Azure!'
                body         = $null
                execinfo     = $null
                pid          = $PID
            }

            $Configuration = @{
                WorkspaceId = '12345'
                SharedKey   = 'Q3Vyc2UgeW91ciBzdWRkZW4gYnV0IGluZXZpdGFibGUgYmV0cmF5YWwh'
                LogType     = 'TestLog'
            }

            { & $module.Logger $Log $Configuration } | Should -Not -Throw

            Assert-MockCalled -CommandName 'Invoke-WebRequest' -Times 1 -Exactly
        }
    }
}
