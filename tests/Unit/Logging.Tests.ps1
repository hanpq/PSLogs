BeforeDiscovery {
    $RootItem = Get-Item $PSScriptRoot
    while ($RootItem.GetDirectories().Name -notcontains 'source')
    {
        $RootItem = $RootItem.Parent
    }
    $ProjectPath = $RootItem.FullName
    $PSDFile = (Get-ChildItem $ProjectPath\*\*.psd1 | Where-Object {
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
    )

    $ProjectName = $PSDFile.BaseName

    Import-Module $ProjectName -Force

}

InModuleScope $ProjectName {
    Describe -Tags Build 'Internal Vars' {
        It 'sets up internal variables' {
            Test-Path Variable:Logging | Should -Be $true
            Test-Path Variable:Defaults | Should -Be $true
            Test-Path Variable:LevelNames | Should -Be $true
            Test-Path Variable:LoggingRunspace | Should -Be $true
            Test-Path Variable:LoggingEventQueue | Should -Be $true
        }
    }

    Describe -Tags Build 'Token replacement' {
        BeforeAll {
            $TimeStamp = Get-Date -UFormat '%Y-%m-%dT%T%Z'
            $Object = [PSCustomObject] @{
                message   = 'Test'
                timestamp = $TimeStamp
                level     = 'INFO'
            }
        }

        It 'should return a string with token replaced' {
            Format-Pattern -Pattern '%{message}' -Source $Object | Should -Be 'Test'
        }

        It 'should return a string with token replaced and padded' {
            Format-Pattern -Pattern '%{message:7}' -Source $Object | Should -Be '   Test'
            Format-Pattern -Pattern '%{message:-7}' -Source $Object | Should -Be 'Test   '
        }

        It 'should return a string with a timestamp, no formatter' {
            Format-Pattern -Pattern '%{timestamp}' -Source $Object | Should -Be $TimeStamp
        }

        It 'should return a string using a custom Unix format with token' {
            Format-Pattern -Pattern '%{timestamp:+%Y%m%d}' -Source $Object | Should -Be $(Get-Date $TimeStamp -UFormat '%Y%m%d')
        }

        It 'should return a string using a custom Unix format without token' {
            Format-Pattern -Pattern '%{+%Y%m%d}' -Source $Object | Should -Be $(Get-Date -UFormat '%Y%m%d')
        }

        It 'should return a string using a custom Unix format with a full day name, with token' {
            Format-Pattern -Pattern '%{timestamp:+%A, %B %d, %Y}' -Source $Object | Should -Be $(Get-Date $TimeStamp -UFormat '%A, %B %d, %Y')
        }

        It 'should return a string using a custom Unix format with a full day name, without token' {
            Format-Pattern -Pattern '%{+%A, %B %d, %Y}' -Source $Object | Should -Be $(Get-Date -UFormat '%A, %B %d, %Y')
        }

        It 'should return a string using a custom Unix format with token, with padding' {
            Format-Pattern -Pattern '%{timestamp:+%Y%m:12}' -Source $Object | Should -Be $('      {0}' -f (Get-Date $TimeStamp -UFormat '%Y%m'))
        }

        It 'should return a string using a custom Unix format without token, with padding' {
            Format-Pattern -Pattern '%{+%Y%m:12}' -Source $Object | Should -Be $('      {0}' -f (Get-Date -UFormat '%Y%m'))
        }

        It 'should return a string using a custom [DateTimeFormatInfo] string with token' {
            Format-Pattern -Pattern '%{timestamp:+yyyy/MM/dd HH:mm:ss.fff}' -Source $Object | Should -Be $(Get-Date $TimeStamp -Format 'yyyy/MM/dd HH:mm:ss.fff')
        }

        It 'should return a string using a custom [DateTimeFormatInfo] string without token' {
            Format-Pattern -Pattern '%{+yyyy/MM/dd HH}' -Source $Object | Should -Be $(Get-Date -Format 'yyyy/MM/dd HH')
        }

        It 'should return a string using a custom [DateTimeFormatInfo] string with token, with padding' {
            Format-Pattern -Pattern '%{timestamp:+HH:mm:ss.fff:15}' -Source $Object | Should -Be $('   {0}' -f (Get-Date $TimeStamp -Format 'HH:mm:ss.fff'))
        }

        It 'should return a string using a custom [DateTimeFormatInfo] string without token, with padding' {
            Format-Pattern -Pattern '%{+yyyy/MM/dd HH:15}' -Source $Object | Should -Be $('  {0}' -f (Get-Date -Format 'yyyy/MM/dd HH'))
        }
    }

    Describe -Tags Build 'Logging Levels' {
        It 'should return logging levels names' {
            Get-LevelsName | Should -Be @('DEBUG', 'ERROR', 'INFO', 'NOTSET', 'WARNING')
        }

        It 'should return loggin level name' {
            Get-LevelName -Level 10 | Should -Be 'DEBUG'
            { Get-LevelName -Level 'DEBUG' } | Should -Throw
        }

        It 'should return logging levels number' {
            Get-LevelNumber -Level 0 | Should -Be 0
            Get-LevelNumber -Level 'NOTSET' | Should -Be 0
        }

        It 'should throw on invalid level' {
            { Get-LevelNumber -Level 11 } | Should -Throw
            { Get-LevelNumber -Level 'LEVEL_UNKNOWN' } | Should -Throw
        }

        It 'should add a new logging level' {
            Add-LoggingLevel -Level 11 -LevelName 'Test'
            Get-LevelsName | Should -Be @('DEBUG', 'ERROR', 'INFO', 'NOTSET', 'TEST', 'WARNING')
        }

        It 'should change the level name if same level number' {
            Add-LoggingLevel -Level 11 -LevelName 'Foo'
            Get-LevelsName | Should -Be @('DEBUG', 'ERROR', 'FOO', 'INFO', 'NOTSET', 'WARNING')
        }

        It 'should change the level number if same level name' {
            Add-LoggingLevel -Level 21 -LevelName 'Foo'
            Get-LevelsName | Should -Be @('DEBUG', 'ERROR', 'FOO', 'INFO', 'NOTSET', 'WARNING')
            Get-LevelNumber -Level 'FOO' | Should -Be 21
        }

        It 'return the default logging level' {
            Get-LoggingDefaultLevel | Should -Be 'NOTSET'
        }

        It 'sets the default logging level' {
            Set-LoggingDefaultLevel -Level INFO
            Get-LoggingDefaultLevel | Should -Be 'INFO'
        }

        It 'change the logging level of available targets' {
            Add-LoggingTarget -Name Console
            (Get-LoggingTarget -Name Console).Level | Should -Be 'INFO'
        }
        It 'change the logging level of already configured targets' {
            Set-LoggingDefaultLevel -Level DEBUG
            (Get-LoggingTarget -Name Console).Level | Should -Be 'DEBUG'
        }

    }

    Describe -Tags Build 'Logging Targets' {
        BeforeAll {
            $TargetsPath = '{0}\..\..\source\include' -f $PSScriptRoot
            $Targets = Get-ChildItem -Path $TargetsPath -Filter '*.ps1'
        }

        It 'loads the logging targets' {
            $Logging.Targets.Count | Should -Be $Targets.Count
        }

        It 'returns the loaded logging targets' {
            $AvailableTargets = Get-LoggingAvailableTarget
            # not sure how to test System.Collections.Concurrent.ConcurrentDictionary[string, hashtable]
            # $AvailableTargets | Should Be []
            $AvailableTargets.Count | Should -Be $Targets.Count
        }

        It 'is case-insensitive' {
            $AvailableTargets = Get-LoggingAvailableTarget
            $AvailableTargets[$AvailableTargets.Keys[0].ToLower()] | Should -Not -BeNullOrEmpty
        }
    }

    Describe -Tags Build 'Logging Format' {
        It 'gets the default format' {
            Get-LoggingDefaultFormat | Should -Be $Defaults.Format
        }

        It 'sets the default logging format' {
            $NewFormat = '[%{level:-7}] %{message}'
            Get-LoggingDefaultFormat | Should -Be $Defaults.Format
            Set-LoggingDefaultFormat -Format $NewFormat
            Get-LoggingDefaultFormat | Should -Be $NewFormat
        }

        It 'change the logging format of already configured targets' {
            $NewFormat = '[%{level:-7}] %{message}'
            Add-LoggingTarget -Name Console
            Set-LoggingDefaultFormat -Format $NewFormat
            (Get-LoggingTarget -Name Console).Format | Should -Be $NewFormat
        }

        It 'change the default format of available targets' {
            $NewFormat = '[%{level:-7}] %{message}'
            Set-LoggingDefaultFormat -Format $NewFormat
            Add-LoggingTarget -Name Console
            (Get-LoggingTarget -Name Console).Format | Should -Be $NewFormat
        }
    }

    Describe -Tags Build 'Logging Caller Scope' {
        It 'should be the default value' {
            Get-LoggingCallerScope | Should -Be $Defaults.CallerScope
        }

        It 'should change the caller scope value' {
            $newScope = 3
            Get-LoggingCallerScope | Should -Be $Defaults.CallerScope
            Set-LoggingCallerScope -CallerScope $newScope
            Get-LoggingCallerScope | Should -Be $newScope
        }
    }

    Describe -Tags Build 'Dynamic Parameter' {
        It 'should contain the default levels' {
            $dynamicDictionary = New-LoggingDynamicParam -Name 'PesterTest' -Level

            [String[]] $allowedValues = $dynamicDictionary['PesterTest'].Attributes[1].ValidValues

            'ERROR' -in $allowedValues | Should -Be $true
            'DEBUG' -in $allowedValues | Should -Be $true
        }

        It 'should contain the default targets' {
            $dynamicDictionary = New-LoggingDynamicParam -Name 'PesterTest' -Target

            [String[]] $allowedValues = $dynamicDictionary['PesterTest'].Attributes[1].ValidValues

            'File' -in $allowedValues | Should -Be $true
            'Console' -in $allowedValues | Should -Be $true
        }
    }

    Describe -Tags Build 'Logging Producer-Consumer' {
        It 'should start logging manager after module import' {
            Test-Path Variable:LoggingEventQueue | Should -Be $true
            Test-Path Variable:LoggingRunspace | Should -Be $true
        }
    }
}

Describe -Tags Unit 'Performance load' {
    $ManifestPath = '{0}\..\..\source\pslogs.psd1' -f $PSScriptRoot

    BeforeEach {
        Remove-Module $ProjectName -Force -ErrorAction SilentlyContinue
        Import-Module $ProjectName -Force
        Start-Sleep -Seconds 1
    }

    It 'should be able to handle [light] load' -Skip:($true) {
        [int] $desiredCount = 100
        [string] $smallLog = [System.IO.Path]::GetTempFileName()

        Add-LoggingTarget -Name File -Configuration @{Path = $smallLog }

        for ([int] $lI = 0; $lI -lt $desiredCount; $lI++)
        {
            Write-Log -Level WARNING -Message 'Test: {0}' -Arguments $lI
        }

        Wait-Logging
        (Get-Content $smallLog).Count | Should -Be $desiredCount
    }

    It 'should be able to handle [medium] load' -Skip:($true) {
        [int] $desiredCount = 1000
        [string] $mediumLog = [System.IO.Path]::GetTempFileName()

        Add-LoggingTarget -Name File -Configuration @{Path = $mediumLog }

        for ([int] $lI = 0; $lI -lt $desiredCount; $lI++)
        {
            Write-Log -Level WARNING -Message 'Test: {0}' -Arguments $lI
        }

        Wait-Logging
        (Get-Content $mediumLog).Count | Should -Be $desiredCount
    }

    It 'should be able to handle [high] load' -Skip:($true) {
        [int] $desiredCount = 10000
        [string] $highLog = [System.IO.Path]::GetTempFileName()
        Add-LoggingTarget -Name File -Configuration @{Path = $highLog; Encoding = 'UTF8' }

        for ([int] $lI = 0; $lI -lt $desiredCount; $lI++)
        {
            Write-Log -Level WARNING -Message 'Test: {0}' -Arguments $lI
        }

        Wait-Logging
        (Get-Content $highLog).Count | Should -Be $desiredCount
    }
}
