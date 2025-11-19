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
            $targets = Get-LoggingTarget
            if ($targets) {
                $targets.GetEnumerator() | ForEach-Object {
                    if ($_.Value.DisplayName) {
                        Remove-LoggingTarget -DisplayName $_.Value.DisplayName
                    } else {
                        Remove-LoggingTarget -DisplayName $_.Key
                    }
                }
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

Describe 'Out of module scope tests' {
    AfterEach {
        $targets = Get-LoggingTarget
        if ($targets) {
            $targets.GetEnumerator() | ForEach-Object {
                if ($_.Value.DisplayName) {
                    Remove-LoggingTarget -DisplayName $_.Value.DisplayName
                } else {
                    Remove-LoggingTarget -DisplayName $_.Key
                }
            }
        }
        Get-ChildItem $TestDrive -Filter '*.log' | ForEach-Object {
            Remove-Item $PSItem.FullName -Force
        }
    }
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
            Start-Sleep -Seconds 1

            $allLogsContent = Get-Content "$TestDrive\all_logs.log"
            $allLogsContent | Should -Contain 'INFO    | This goes to AllLogs only'
            $allLogsContent | Should -Contain 'ERROR   | This goes to all targets'

            $errorsOnlyContent = Get-Content "$TestDrive\errors_only.log"
            $errorsOnlyContent | Should -Contain 'ERROR   | This goes to all targets'
        }
    }
    Context 'Tag functionality' {
        It 'Should work without tags' {
            Add-LoggingTarget -Name 'File' -Configuration @{
                Level  = 'DEBUG'
                Path   = "$TestDrive\logs.log"
                Format = '%{level:-7} | %{message}'
            }

            Write-Log -Level VERBOSE -Message 'Testmessage'

            Wait-Logging
            Start-Sleep -Seconds 1 # Ensure file write completion
            $LogsContent = Get-Content "$TestDrive\logs.log"
            $LogsContent | Should -Contain 'VERBOSE | Testmessage'
        }
        It 'Should work with tags' {
            Add-LoggingTarget -Type File -DisplayName 'Logs' -Configuration @{
                Level  = 'INFO'
                Path   = "$TestDrive\logs.log"
                Format = '%{level:-7} | %{message}'
                Tags   = @('Default')
            }

            Add-LoggingTarget -Type File -DisplayName 'Changes' -Configuration @{
                Level  = 'DEBUG'
                Path   = "$TestDrive\changes.log"
                Format = '%{level:-7} | %{message}'
                Tags   = @('Changes')
            }

            Add-LoggingTarget -Type File -Displayname 'Combined' -Configuration @{
                Level  = 'DEBUG'
                Path   = "$TestDrive\combined.log"
                Format = '%{level:-7} | %{message}'
                Tags   = @('Default', 'Changes', 'Database')
            }

            Write-Log -Level INFO -Message 'This is a standard message'
            Write-Log -Level INFO -Message 'This is also a standard message' -Tags @('Default')
            Write-Log -Level SUCCESS -Message 'This is a change message' -Tags @('Changes')
            Write-Log -Level ERROR -Message 'This is a change message' -Tags @('Changes')

            Wait-Logging

            Start-Sleep -Seconds 1 # Ensure file write completion

            $logsContent = Get-Content "$TestDrive\logs.log"
            $changesContent = Get-Content "$TestDrive\changes.log"
            $combinedContent = Get-Content "$TestDrive\combined.log"

            $logsContent | Should -Contain 'INFO    | This is a standard message'
            $logsContent | Should -Contain 'INFO    | This is also a standard message'

            $changesContent | Should -Contain 'SUCCESS | This is a change message'
            $changesContent | Should -Contain 'ERROR   | This is a change message'

            $combinedContent | Should -Contain 'INFO    | This is a standard message'
            $combinedContent | Should -Contain 'INFO    | This is also a standard message'
            $combinedContent | Should -Contain 'SUCCESS | This is a change message'
            $combinedContent | Should -Contain 'ERROR   | This is a change message'

        }
    }
}
