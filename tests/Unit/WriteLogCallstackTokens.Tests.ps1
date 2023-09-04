
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

    $moduleManifestPath = $ModuleManifestFileInfo.FullName
}

AfterAll {
    Remove-Module PSLogs -Force -ErrorAction SilentlyContinue
}

# These tests verify that Write-Log determines the correct values for the tokens whose values are taken from
# the callstack: 'pathname', 'filename', 'lineno', and 'caller'.
#
# Since Write-Log doesn't produce output directly, we use the File target to generate files containing these
# tokens and then inspect the files to verify that they have the expected contents.
#
# If we call Write-Log directly from within a Pester test, we can't predict exactly what the callstack will be,
# since it will include some of our code and some of Pester's code. This makes it impossible to predict which
# values Write-Log will use for the tokens.
#
# In order to create an environment where we can predict the contents of the callstack, we need to create scripts
# that call Write-Log and then run those scripts using the PowerShell executable. In that environment, we can
# predict the contents of the callstack and therefore what the values of the tokens should be.
#
# Accordingly, these tests use Pester to create scripts that call Write-Log, and then run those scripts using
# the PowerShell executable, instead of calling Write-Log from directly within the tests. These tests will run
# relatively slowly as a result of this.
Describe 'CallerScope' {
    BeforeAll {
        # Set to $true to enable output of additional debugging information for this test code.
        $debugTests = $false

        $logPath = Join-Path -Path $TestDrive -ChildPath 'log.txt'

        $scriptName = 'script.ps1'
        $scriptPath = Join-Path -Path $TestDrive -ChildPath $scriptName

        $moduleManifestPath = (Get-ChildItem "$ProjectPath\output\" -Filter 'PSLogs.psd1' -Recurse).FullName

        $codeLineImportModule = "Import-Module -Name '$moduleManifestPath';"
        $codeLineSetCallerScope = 'Set-LoggingCallerScope -CallerScope {0};'
        $codeLineAddTarget = ("Add-LoggingTarget -Name 'File' -Configuration @{ Path = '$logPath'; " +
            "Format = '[%{pathname}] [%{filename}] [%{lineno}] [%{caller}]' };")
        $codeLineWriteLog = "Write-Log -Message 'Test Message';"
        $codeLineWaitForFile = "while (-not (Test-Path -Path '$logpath')) {};"
        $codeLineRemoveModule = 'Remove-Module -Name PSLogs;'

        $codeSetup = @(
            $codeLineImportModule
            $codeLineSetCallerScope
            $codeLineAddTarget
        )
        $codeCleanup = @(
            $codeLineWaitForFile
            $codeLineRemoveModule
        )

        function InvokePowerShellExe
        {
            param (
                [string]$Path = $scriptPath,
                [string]$Command
            )

            if ($PSBoundParameters.ContainsKey('Command'))
            {
                $run = "-Command `"$Command`""
            }
            else
            {
                $run = "-File `"$Path`""
            }

            if ($PSVersionTable.PSEdition -eq 'Desktop')
            {
                $powershell_exe = 'powershell.exe'
            }
            else
            {
                $powershell_exe = 'pwsh'
            }
            $powershell_exe = Join-Path -Path $PSHOME -ChildPath $powershell_exe

            $params = @{
                Wait         = $true
                PassThru     = $true
                NoNewWindow  = $true
                FilePath     = $powershell_exe
                ArgumentList = @('-NoLogo', '-NoProfile', '-NonInteractive', $run)
            }

            Start-Process @params
        }

        # Reads through an array of code lines to determine which one contains the line that calls
        # Set-LoggingCallerScope, then replaces the "{0}" on that line with the value of the $Scope
        # parameter and returns a new array containing the modified line.
        function InjectScopeInCode
        {
            param (
                [string[]]$Code,
                [int]$Scope
            )

            # Clone the array that contains the code so that we don't modify the
            # original when we inject the scope.
            $injectedCode = $Code.Clone()

            $scopeIndex = $injectedCode.IndexOf($codeLineSetCallerScope)
            if ($scopeIndex -eq -1)
            {
                throw "Could not determine where to inject scope [$Scope]."
            }
            $injectedCode[$scopeIndex] = $injectedCode[$scopeIndex] -f $Scope

            if ($debugTests)
            {
                Write-Host -ForegroundColor Magenta -Object 'Code with scope injected:'
                foreach ($line in $injectedCode)
                {
                    Write-Host -ForegroundColor Magenta -Object $line
                }
            }

            $injectedCode
        }

        function SetScriptFile
        {
            param (
                [string]$Path = $scriptPath,
                [string[]]$Code,
                [int]$Scope
            )

            $codeToWrite = $Code
            if ($PSBoundParameters.ContainsKey('Scope'))
            {
                $codeToWrite = InjectScopeInCode -Code $codeToWrite -Scope $Scope
            }

            Set-Content -Path $Path -Value $codeToWrite
        }

        function InvokeShould
        {
            param (
                [string]$ExpectedValue
            )

            if ($debugTests)
            {
                Write-Host -ForegroundColor Magenta -Object 'Contents of log file:'
                Write-Host -ForegroundColor Magenta -Object (Get-Content -Path $logPath)
            }

            $logPath | Should -FileContentMatch ([regex]::Escape($ExpectedValue))
        }
    }

    AfterEach {
        if (Test-Path -Path $logPath)
        {
            Remove-Item -Path $logPath
        }

        $testScope++
    }

    Context 'Tests that don''t use a wrapper' {
        BeforeAll {
            $codeWriteNoWrapper = $codeSetup + $codeLineWriteLog + $codeCleanup
            $lineNumWriteLog = $codeWriteNoWrapper.IndexOf($codeLineWriteLog) + 1
        }

        Context 'Write-Log called directly rather than from a script file' {

            It 'Scope 1' {
                $injectedCode = InjectScopeInCode -Scope 1 -Code $codeWriteNoWrapper
                $commands = $injectedCode -join '; '
                InvokePowerShellExe -Command $commands
                InvokeShould '[] [] [1] [<ScriptBlock>]'
            }
        }

        Context 'Script File -> Write-Log' {
            It 'Scope 1' {
                SetScriptFile -Code $codeWriteNoWrapper -Scope 1
                InvokePowerShellExe
                InvokeShould "[$scriptPath] [$scriptName] [$lineNumWriteLog] [$scriptName]"
            }
        }

        Context 'Caller Script File -> Script File -> Write-Log' {
            BeforeAll {

                $callerScriptName = 'caller.ps1'
                $callerScriptPath = Join-Path -Path $TestDrive -ChildPath $callerScriptName
                $callerScriptCode = @(
                    "& $scriptPath"
                )
                SetScriptFile -Path $callerScriptPath -Code $callerScriptCode
            }

            # This section is modified from the orginal module as it was tested with Pester 4.x. Before testscope was incremented in a highlevel AfterEach however variables defined in BeforeAll are read-only during the test and the increment was not persistant for the scope 2 test.
            It 'Scope 1 - Script File Calling Write-Log' {
                SetScriptFile -Code $codeWriteNoWrapper -Scope 1
                InvokePowerShellExe -Path $callerScriptPath
                InvokeShould "[$scriptPath] [$scriptName] [$lineNumWriteLog] [$scriptName]"
            }

            It 'Scope 2 - Caller Script File Calling Script File' {
                SetScriptFile -Code $codeWriteNoWrapper -Scope 2
                InvokePowerShellExe -Path $callerScriptPath
                InvokeShould "[$callerScriptPath] [$callerScriptName] [1] [$callerScriptName]"
            }

            AfterEach {
                if (Test-Path -Path $logPath)
                {
                    Remove-Item -Path $logPath
                }
            }
        }
    }

    Context 'Tests that do use a wrapper' {
        BeforeAll {
            $wrapperFunctionName = 'Wrapper'
            $codeLineCallWrapper = $wrapperFunctionName
            $codeLineCallWriteLogInWrapper = "function $wrapperFunctionName { $codeLineWriteLog }"
        }

        Context 'Script File -> Wrapper -> Write-Log' {

            # This section is modified from the orginal module as it was tested with Pester 4.x. Before testscope was incremented in a highlevel AfterEach however variables defined in BeforeAll are read-only during the test and the increment was not persistant for the scope 2 test.
            It 'Scope 1 - Wrapper Calling Write-Log' {
                $code =
                $codeSetup +
                $codeLineCallWriteLogInWrapper +
                $codeLineCallWrapper +
                $codeCleanup
                SetScriptFile -Code $code -Scope 1
                InvokePowerShellExe
                $lineNumWriteLogCall = $code.IndexOf($codeLineCallWriteLogInWrapper) + 1
                InvokeShould "[$scriptPath] [$scriptName] [$lineNumWriteLogCall] [$wrapperFunctionName]"
            }

            It 'Scope 2 - Script File Calling Wrapper' {
                $code =
                $codeSetup +
                $codeLineCallWriteLogInWrapper +
                $codeLineCallWrapper +
                $codeCleanup
                SetScriptFile -Code $code -Scope 2
                InvokePowerShellExe
                $lineNumWrapperCall = $code.IndexOf($codeLineCallWrapper) + 1
                InvokeShould "[$scriptPath] [$scriptName] [$lineNumWrapperCall] [$scriptName]"
            }

            AfterEach {
                if (Test-Path -Path $logPath)
                {
                    Remove-Item -Path $logPath
                }
            }

        }

        Context 'Script File -> Business Logic -> Wrapper -> Write-Log' {

            # This section is modified from the orginal module as it was tested with Pester 4.x. Before testscope was incremented in a highlevel AfterEach however variables defined in BeforeAll are read-only during the test and the increment was not persistant for the scope 2 test.
            It 'Scope 1 - Wrapper Calling Write-Log' {
                $businessLogicFunctionName = 'BusinessLogic'
                $codeLineCallBusinessLogicInScript = $businessLogicFunctionName
                $codeLineCallWrapperInBusinessLogic =
                "function $businessLogicFunctionName { $codeLineCallWrapper }"
                $code =
                $codeSetup +
                $codeLineCallWriteLogInWrapper +
                $codeLineCallWrapperInBusinessLogic +
                $codeLineCallBusinessLogicInScript +
                $codeCleanup
                SetScriptFile -Code $code -Scope 1
                InvokePowerShellExe
                $lineNumWriteLogCall = $code.IndexOf($codeLineCallWriteLogInWrapper) + 1
                InvokeShould "[$scriptPath] [$scriptName] [$lineNumWriteLogCall] [$wrapperFunctionName]"
            }

            It 'Scope 2 - Business Logic Calling Wrapper' {
                $businessLogicFunctionName = 'BusinessLogic'
                $codeLineCallBusinessLogicInScript = $businessLogicFunctionName
                $codeLineCallWrapperInBusinessLogic =
                "function $businessLogicFunctionName { $codeLineCallWrapper }"
                $code =
                $codeSetup +
                $codeLineCallWriteLogInWrapper +
                $codeLineCallWrapperInBusinessLogic +
                $codeLineCallBusinessLogicInScript +
                $codeCleanup
                SetScriptFile -Code $code -Scope 2
                InvokePowerShellExe
                $lineNumWrapperCall = $code.IndexOf($codeLineCallWrapperInBusinessLogic) + 1
                InvokeShould "[$scriptPath] [$scriptName] [$lineNumWrapperCall] [$businessLogicFunctionName]"
            }

            It 'Scope 3 - Script File Calling Business Logic' {
                $businessLogicFunctionName = 'BusinessLogic'
                $codeLineCallBusinessLogicInScript = $businessLogicFunctionName
                $codeLineCallWrapperInBusinessLogic =
                "function $businessLogicFunctionName { $codeLineCallWrapper }"
                $code =
                $codeSetup +
                $codeLineCallWriteLogInWrapper +
                $codeLineCallWrapperInBusinessLogic +
                $codeLineCallBusinessLogicInScript +
                $codeCleanup
                SetScriptFile -Code $code -Scope 3
                InvokePowerShellExe
                $lineNumBusinessLogicCall = $code.IndexOf($codeLineCallBusinessLogicInScript) + 1
                InvokeShould "[$scriptPath] [$scriptName] [$lineNumBusinessLogicCall] [$scriptName]"
            }
        }
    }
}
