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
    Describe 'Write-Log' -Tag 'Unit', 'Write-Log' {
        It 'Should be true' {
            $true | Should -Be $true
        }
    }
    Describe 'Wait-Logging' -Tag 'Unit', 'Wait-Logging' {
        It 'Should be true' {
            $true | Should -Be $true
        }
    }
    Describe 'Add-LoggingLevel' -Tag 'Unit', 'Add-LoggingLevel' {
        It 'Should be true' {
            $true | Should -Be $true
        }
    }
    Describe 'Add-LoggingTarget' -Tag 'Unit', 'Add-LoggingTarget' {
        It 'Should be true' {
            $true | Should -Be $true
        }
    }
    Describe 'Format-Pattern' -Tag 'Unit', 'Format-Pattern' {
        It 'Should be true' {
            $true | Should -Be $true
        }
    }
    Describe 'Get-LevelName' -Tag 'Unit', 'Get-LevelName' {
        It 'Should be true' {
            $true | Should -Be $true
        }
    }
    Describe 'Get-LevelNumber' -Tag 'Unit', 'Get-LevelNumber' {
        It 'Should be true' {
            $true | Should -Be $true
        }
    }
    Describe 'Get-LevelsName' -Tag 'Unit', 'Get-LevelsName' {
        It 'Should be true' {
            $true | Should -Be $true
        }
    }
    Describe 'Get-LoggingAvailableTarget' -Tag 'Unit', 'Get-LoggingAvailableTarget' {
        It 'Should be true' {
            $true | Should -Be $true
        }
    }
    Describe 'Get-LoggingCallerScope' -Tag 'Unit', 'Get-LoggingCallerScope' {
        It 'Should be true' {
            $true | Should -Be $true
        }
    }
    Describe 'Get-LoggingDefaultFormat' -Tag 'Unit', 'Get-LoggingDefaultFormat' {
        It 'Should be true' {
            $true | Should -Be $true
        }
    }
    Describe 'Get-LoggingDefaultLevel' -Tag 'Unit', 'Get-LoggingDefaultLevel' {
        It 'Should be true' {
            $true | Should -Be $true
        }
    }
    Describe 'Get-LoggingTarget' -Tag 'Unit', 'Get-LoggingTarget' {
        It 'Should be true' {
            $true | Should -Be $true
        }
    }
    Describe 'Initialize-LoggingTarget' -Tag 'Unit', 'Initialize-LoggingTarget' {
        It 'Should be true' {
            $true | Should -Be $true
        }
    }
    Describe 'Merge-DefaultConfig' -Tag 'Unit', 'Merge-DefaultConfig' {
        It 'Should be true' {
            $true | Should -Be $true
        }
    }
    Describe 'New-LoggingDynamicParam' -Tag 'Unit', 'New-LoggingDynamicParam' {
        It 'Should be true' {
            $true | Should -Be $true
        }
    }
    Describe 'Remove-LoggingTarget' -Tag 'Unit', 'Remove-LoggingTarget' {
        It 'Should be true' {
            $true | Should -Be $true
        }
    }
    Describe 'Set-LoggingCallerScope' -Tag 'Unit', 'Set-LoggingCallerScope' {
        It 'Should be true' {
            $true | Should -Be $true
        }
    }
    Describe 'Set-LoggingCustomTarget' -Tag 'Unit', 'Set-LoggingCustomTarget' {
        It 'Should be true' {
            $true | Should -Be $true
        }
    }
    Describe 'Set-LoggingDefaultFormat' -Tag 'Unit', 'Set-LoggingDefaultFormat' {
        It 'Should be true' {
            $true | Should -Be $true
        }
    }
    Describe 'Set-LoggingDefaultLevel' -Tag 'Unit', 'Set-LoggingDefaultLevel' {
        It 'Should be true' {
            $true | Should -Be $true
        }
    }
    Describe 'Set-LoggingVariables' -Tag 'Unit', 'Set-LoggingVariables' {
        It 'Should be true' {
            $true | Should -Be $true
        }
    }
    Describe 'Start-LoggingManager' -Tag 'Unit', 'Start-LoggingManager' {
        It 'Should be true' {
            $true | Should -Be $true
        }
    }
    Describe 'Stop-LoggingManager' -Tag 'Unit', 'Stop-LoggingManager' {
        It 'Should be true' {
            $true | Should -Be $true
        }
    }
}
