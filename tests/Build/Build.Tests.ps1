BeforeAll {
    $projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
    $buildScript = Join-Path $projectRoot 'build.ps1'
    $ast = [System.Management.Automation.Language.Parser]::ParseFile($buildScript, [ref]$null, [ref]$null)
    foreach ($functionName in @('Import-BuildModule', 'Invoke-ModuleTests', 'New-ModulePackage'))
    {
        $definition = $ast.Find({
            param($node)
            $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and
                $node.Name -eq $functionName
        }, $true)
        Set-Item -Path "Function:\$functionName" -Value $definition.Body.GetScriptBlock()
    }

    $DependencyManifest = Join-Path $projectRoot 'RequiredModules.psd1'
    $RequiredModulesDirectory = Join-Path $projectRoot 'output\RequiredModules'
    $OutputDirectory = Join-Path $TestDrive 'output'
    $TestResultsDirectory = Join-Path $OutputDirectory 'testResults'
    $ModuleName = 'ExampleModule'
}

Describe 'Module metadata discovery' {
    BeforeAll {
        $metadataScript = Join-Path $projectRoot 'scripts\Get-BuildProject.ps1'
        $fixtureRoot = Join-Path $TestDrive 'ExampleProject'
        $fixtureSource = Join-Path $fixtureRoot 'source'
        New-Item -ItemType Directory -Path $fixtureSource -Force | Out-Null
        Set-Content -LiteralPath (Join-Path $fixtureSource 'ExampleModule.psd1') -Value "@{ ModuleVersion = '1.2.3' }"
    }

    It 'uses the source manifest name rather than the repository name' {
        $project = & $metadataScript -ProjectRoot $fixtureRoot

        $project.Name | Should -Be 'ExampleModule'
        $project.Version | Should -Be '1.2.3'
        $project.SourceManifest | Should -Be (Join-Path $fixtureSource 'ExampleModule.psd1')
    }

    It 'rejects an ambiguous source directory' {
        Set-Content -LiteralPath (Join-Path $fixtureSource 'OtherModule.psd1') -Value "@{ ModuleVersion = '1.0.0' }"

        { & $metadataScript -ProjectRoot $fixtureRoot } |
            Should -Throw '*exactly one module manifest*'
    }
}

Describe 'Module packaging' {
    It 'creates a package for a differently named module' {
        $BuiltModuleDirectory = Join-Path $OutputDirectory $ModuleName
        $moduleDirectory = Join-Path $BuiltModuleDirectory '1.2.3'
        New-Item -ItemType Directory -Path $moduleDirectory -Force | Out-Null
        Set-Content -LiteralPath (Join-Path $moduleDirectory "$ModuleName.psd1") -Value "@{ ModuleVersion = '1.2.3' }"

        New-ModulePackage -ModuleVersion '1.2.3'

        $package = Join-Path $OutputDirectory 'ExampleModule.1.2.3.zip'
        Test-Path -LiteralPath $package | Should -BeTrue
        $archive = [System.IO.Compression.ZipFile]::OpenRead($package)
        try
        {
            $archive.Entries.FullName | Should -Contain 'ExampleModule.psd1'
        }
        finally
        {
            $archive.Dispose()
        }
    }
}

Describe 'Pinned build module imports' {
    It 'imports the pinned analyzer manifest beyond the helper scope' {
        Mock Import-Module {}

        Import-BuildModule -Name PSScriptAnalyzer

        Should -Invoke Import-Module -Times 1 -Exactly -ParameterFilter {
            $Name -eq (Join-Path $RequiredModulesDirectory 'PSScriptAnalyzer\1.24.0\PSScriptAnalyzer.psd1') -and
            $Global -and $ErrorAction -eq 'Stop'
        }
    }
}

Describe 'Build test runner' {
    BeforeEach {
        $originalModulePath = $env:PSModulePath
        Mock Write-Host {}
        Mock Import-BuildModule {}
        Mock Invoke-Pester {
            [pscustomobject]@{
                Result                = 'Passed'
                FailedCount           = 0
                FailedContainersCount = 0
            }
        }
    }

    AfterEach {
        $env:PSModulePath = $originalModulePath
    }

    It 'loads the analyzer and Pester explicitly before running tests' {
        Invoke-ModuleTests -ModuleVersion '1.2.3'

        Should -Invoke Import-BuildModule -Times 1 -Exactly -ParameterFilter { $Name -eq 'PSScriptAnalyzer' }
        Should -Invoke Import-BuildModule -Times 1 -Exactly -ParameterFilter { $Name -eq 'Pester' }
        Should -Invoke Invoke-Pester -Times 1 -Exactly -ParameterFilter {
            $Configuration.TestResult.OutputPath.Value -eq (Join-Path $TestResultsDirectory 'ExampleModule.Tests.xml')
        }
        Should -Invoke Write-Host -Times 1 -Exactly -ParameterFilter {
            $Object -like 'Pester tests passed.*'
        }
    }

    It 'does not start Pester when the analyzer cannot be imported' {
        Mock Import-BuildModule {
            throw 'Analyzer assembly conflict'
        } -ParameterFilter { $Name -eq 'PSScriptAnalyzer' }

        { Invoke-ModuleTests -ModuleVersion '1.2.3' } |
            Should -Throw '*Analyzer assembly conflict*'

        Should -Invoke Invoke-Pester -Times 0 -Exactly
    }

    It 'fails when discovery fails without any failed tests' {
        Mock Invoke-Pester {
            [pscustomobject]@{
                Result                = 'Failed'
                FailedCount           = 0
                FailedContainersCount = 1
            }
        }

        { Invoke-ModuleTests -ModuleVersion '1.2.3' } |
            Should -Throw '*failed tests: 0; failed containers: 1*'

        Should -Invoke Write-Host -Times 0 -Exactly -ParameterFilter {
            $Object -like 'Pester tests passed.*'
        }
    }

    It 'fails when a test fails' {
        Mock Invoke-Pester {
            [pscustomobject]@{
                Result                = 'Failed'
                FailedCount           = 1
                FailedContainersCount = 0
            }
        }

        { Invoke-ModuleTests -ModuleVersion '1.2.3' } |
            Should -Throw '*failed tests: 1; failed containers: 0*'
    }
}
