BeforeAll {
    $ProjectPath = (Resolve-Path "$PSScriptRoot\..\..").Path
    . "$ProjectPath\source\Private\Format-Pattern.ps1"

    $Logging = @{ Level = 'DEBUG'; Format = '[%{level}] %{message}' }
    $Target = . "$ProjectPath\source\include\OutputDebugString.ps1"

    # Add-Type assemblies survive module removal, so isolate mocked initialization from earlier runs.
    $TestNativeTypeName = 'OutputDebugStringNativeMethods_' + [guid]::NewGuid().ToString('N')
    $Target.Logger = [scriptblock]::Create(
        $Target.Logger.ToString().Replace('OutputDebugStringNativeMethods', $TestNativeTypeName)
    )

    Add-Type -TypeDefinition @'
namespace PSLogs.Tests
{
    public static class DebugOutputRecorder
    {
        public static string Message;
        public static void OutputDebugString(string message)
        {
            Message = message;
        }
    }
}
'@
}

Describe -Tags Targets, TargetOutputDebugString 'OutputDebugString target' {
    BeforeEach {
        $OriginalEdition = $PSVersionTable.PSEdition
        $OriginalIsWindows = Get-Variable -Name IsWindows -ErrorAction Ignore |
            Select-Object Name, Value
        $Configuration = @{}
        foreach ($Key in $Target.Configuration.Keys)
        {
            $Configuration[$Key] = $Target.Configuration[$Key].Default
        }
        $Log = @{ Level = 'INFO'; Message = 'Hello, debugger!' }
        [PSLogs.Tests.DebugOutputRecorder]::Message = $null

        Mock Add-Type { [PSLogs.Tests.DebugOutputRecorder] }
    }

    AfterEach {
        $PSVersionTable.PSEdition = $OriginalEdition
        if ($null -ne $OriginalIsWindows)
        {
            Set-Variable -Name IsWindows -Value $OriginalIsWindows.Value -Force
        }
        else
        {
            Remove-Variable -Name IsWindows -Force -ErrorAction Ignore
        }
    }

    It 'has no required configuration and uses the module defaults' {
        $Target.Name | Should -Be 'OutputDebugString'
        $Target.Configuration.Values.Required | Should -Not -Contain $true
        $Configuration.Level | Should -Be $Logging.Level
        $Configuration.Format | Should -Be $Logging.Format
        $Configuration.PrintException | Should -BeTrue
    }

    It 'silently returns on <Platform> without loading interop or formatting' -ForEach @(
        @{ Platform = 'Linux' }
        @{ Platform = 'macOS' }
    ) {
        Mock Format-Pattern { throw 'Formatting must not run on unsupported platforms' }

        $Result = & {
            $PSVersionTable.PSEdition = 'Core'
            New-Variable -Name IsWindows -Value $false -Force -Scope Local
            & $Target.Logger $Log $Configuration
        } *>&1

        $Result | Should -BeNullOrEmpty
        Should -Invoke Add-Type -Times 0 -Exactly
        Should -Invoke Format-Pattern -Times 0 -Exactly
        [PSLogs.Tests.DebugOutputRecorder]::Message | Should -BeNullOrEmpty
    }

    It 'formats Unicode messages on Windows without producing pipeline output' {
        $Log.Message = "Hello, $([char]0x4e16)$([char]0x754c)!"
        $Result = & {
            New-Variable -Name IsWindows -Value $true -Force -Scope Local
            & $Target.Logger $Log $Configuration
        }

        $Result | Should -BeNullOrEmpty
        [PSLogs.Tests.DebugOutputRecorder]::Message | Should -Be "[INFO] $($Log.Message)"
        Should -Invoke Add-Type -Times 1 -Exactly -ParameterFilter {
            $PassThru -and $ErrorAction -eq 'Stop' -and
            $TypeDefinition -match 'EntryPoint = "OutputDebugStringW"' -and
            $TypeDefinition -match 'CharSet = CharSet.Unicode'
        }
    }

    It 'supports Windows PowerShell without the IsWindows variable' {
        & {
            $PSVersionTable.PSEdition = 'Desktop'
            New-Variable -Name IsWindows -Value $false -Force -Scope Local
            & $Target.Logger $Log $Configuration
        }

        [PSLogs.Tests.DebugOutputRecorder]::Message | Should -Be '[INFO] Hello, debugger!'
    }

    It 'honors a custom format' {
        $Configuration.Format = '%{message}'
        & {
            New-Variable -Name IsWindows -Value $true -Force -Scope Local
            & $Target.Logger $Log $Configuration
        }

        [PSLogs.Tests.DebugOutputRecorder]::Message | Should -Be 'Hello, debugger!'
    }

    It 'appends exception details only when enabled' {
        $Log.ExecInfo = @{
            Exception = @{ Message = 'Example exception' }
            ScriptStackTrace = "First frame`r`nSecond frame"
        }
        & {
            New-Variable -Name IsWindows -Value $true -Force -Scope Local
            & $Target.Logger $Log $Configuration
        }

        [PSLogs.Tests.DebugOutputRecorder]::Message | Should -Be "[INFO] Hello, debugger!`nExample exception`n`tFirst frame`n`tSecond frame"

        $Configuration.PrintException = $false
        & {
            New-Variable -Name IsWindows -Value $true -Force -Scope Local
            & $Target.Logger $Log $Configuration
        }

        [PSLogs.Tests.DebugOutputRecorder]::Message | Should -Be '[INFO] Hello, debugger!'
    }

    It 'does not suppress interop initialization errors on Windows' {
        Mock Add-Type { throw 'Interop initialization failed' }

        {
            & {
                New-Variable -Name IsWindows -Value $true -Force -Scope Local
                & $Target.Logger $Log $Configuration
            }
        } | Should -Throw '*Interop initialization failed*'
    }
}

Describe -Tags Targets, TargetOutputDebugString 'OutputDebugString module integration' {
    BeforeAll {
        Remove-Module PSLogs -Force -ErrorAction SilentlyContinue
        $Manifest = Get-ChildItem "$ProjectPath\output\PSLogs" -Recurse -Filter PSLogs.psd1 |
            Select-Object -First 1
        Import-Module $Manifest.FullName -Force -ErrorAction Stop
    }

    AfterAll {
        Remove-Module PSLogs -Force -ErrorAction SilentlyContinue
    }

    It 'is discovered and can be enabled with default configuration' {
        $Targets = Get-LoggingAvailableTarget
        $Targets.OutputDebugString | Should -Not -BeNullOrEmpty
        $Targets.OutputDebugString.ParamsRequired | Should -BeNullOrEmpty
        Add-LoggingTarget -Type OutputDebugString
        (Get-LoggingTarget).OutputDebugString.Type | Should -Be 'OutputDebugString'
    }

    It 'writes through the consumer runspace and reuses the native type on Windows' -Skip:($env:OS -ne 'Windows_NT') {
        Add-LoggingTarget -Type OutputDebugString
        Write-Log -Level INFO -Message 'OutputDebugString integration test'
        Wait-Logging

        $Deadline = [datetime]::UtcNow.AddSeconds(10)
        while ($null -eq ('PSLogs.OutputDebugStringNativeMethods' -as [type]) -and [datetime]::UtcNow -lt $Deadline)
        {
            Start-Sleep -Milliseconds 20
        }
        $NativeType = 'PSLogs.OutputDebugStringNativeMethods' -as [type]
        $NativeType | Should -Not -BeNullOrEmpty
        $Import = $NativeType.GetMethod('OutputDebugString').GetCustomAttributes([System.Runtime.InteropServices.DllImportAttribute], $false)[0]
        $Import.EntryPoint | Should -Be 'OutputDebugStringW'
        $Import.CharSet | Should -Be ([System.Runtime.InteropServices.CharSet]::Unicode)
        $Import.ExactSpelling | Should -BeTrue

        Add-LoggingTarget -Type OutputDebugString -UniqueName SecondDebugger
        Write-Log -Level INFO -Message 'OutputDebugString repeated call'
        Wait-Logging
        Remove-Module PSLogs -Force -ErrorAction Stop
        ('PSLogs.OutputDebugStringNativeMethods' -as [type]) | Should -Be $NativeType
    }
}
