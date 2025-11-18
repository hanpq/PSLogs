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

InModuleScope 'PSLogs' {

    Describe 'File target' -Tags Targets, TargetFile {
        AfterEach {
            (Get-LoggingTarget).GetEnumerator() | Select-Object -expand value | Select-Object -expand displayname | ForEach-Object {
                Remove-LoggingTarget -DisplayName $PSItem
            }
        }
        Context 'Old syntax (using Name parameter)' {
            It 'should resolve relative paths' {

                Add-LoggingTarget -Name File -Configuration @{
                    Path = '..\Test.log'
                }

                $a = Get-LoggingTarget
                $a.Values.Path.Contains('..') | Should -BeFalse
            }
        }
    }
}

Describe 'New syntax for multiple targets' {
    Context 'New syntax (using Type and DisplayName parameters)' {
        It 'Should be possible to add multiple File targets with different DisplayNames' {

            Add-LoggingTarget -Type File -DisplayName 'AllLogs' -Configuration @{
                Path   = "$TestDrive\all_logs.log"
                Level  = 'DEBUG'
                Format = '%{level:-7} | %{message}'
            }

            Add-LoggingTarget -Type File -DisplayName 'ErrorsOnly' -Configuration @{
                Path   = "$TestDrive\errors_only.log"
                Level  = 'ERROR'
                Format = '%{level:-7} | %{message}'
            }

            $a = Get-LoggingTarget
            $a.Keys | Should -Contain 'AllLogs'
            $a.Keys | Should -Contain 'ErrorsOnly'

            Write-Log -Level INFO -Message 'This goes to AllLogs only'
            Write-Log -Level ERROR -Message 'This goes to all targets'

            Wait-Logging

            $allLogsContent = Get-Content "$TestDrive\all_logs.log"
            $allLogsContent | Should -Contain 'INFO    | This goes to AllLogs only'
            $allLogsContent | Should -Contain 'ERROR   | This goes to all targets'

            $errorsOnlyContent = Get-Content "$TestDrive\errors_only.log"
            $errorsOnlyContent | Should -Contain 'ERROR   | This goes to all targets'
        }
    }

}
