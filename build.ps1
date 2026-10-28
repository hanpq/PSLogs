[CmdletBinding()]
param
(
    [Parameter(Position = 0)]
    [ValidateSet('Verify', 'Build', 'Test', 'Package', 'Clean', 'InstallDependencies')]
    [string]
    $Task = 'Verify',

    [Parameter()]
    [string]
    $Version,

    [Parameter()]
    [string]
    $OutputDirectory
)

$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrWhiteSpace($OutputDirectory))
{
    $OutputDirectory = 'output'
}

if ([System.IO.Path]::IsPathRooted($OutputDirectory))
{
    $OutputDirectory = [System.IO.Path]::GetFullPath($OutputDirectory)
}
else
{
    $OutputDirectory = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot $OutputDirectory))
}
$RequiredModulesDirectory = Join-Path $OutputDirectory 'RequiredModules'
$BuiltModuleDirectory = Join-Path $OutputDirectory 'PSLogs'
$TestResultsDirectory = Join-Path $OutputDirectory 'testResults'
$SourceManifest = Join-Path $PSScriptRoot 'source\PSLogs.psd1'
$DependencyManifest = Join-Path $PSScriptRoot 'RequiredModules.psd1'

function Get-ModuleVersion
{
    if ($Version)
    {
        $moduleVersion = $Version
    }
    else
    {
        $moduleVersion = (Import-PowerShellDataFile -Path $SourceManifest).ModuleVersion
    }

    try
    {
        $null = [version]$moduleVersion
    }
    catch
    {
        throw "Module version '$moduleVersion' must be a numeric PowerShell module version."
    }

    return $moduleVersion
}

function Initialize-BuildDependencies
{
    param
    (
        [switch]
        $IncludeDocumentation
    )

    $dependencyGroups = Import-PowerShellDataFile -Path $DependencyManifest
    $dependencies = @{}

    foreach ($moduleName in $dependencyGroups.Build.Keys)
    {
        $dependencies[$moduleName] = $dependencyGroups.Build[$moduleName]
    }

    if ($IncludeDocumentation)
    {
        foreach ($groupName in @('Publish', 'Documentation'))
        {
            foreach ($moduleName in $dependencyGroups[$groupName].Keys)
            {
                $dependencies[$moduleName] = $dependencyGroups[$groupName][$moduleName]
            }
        }
    }

    New-Item -ItemType Directory -Path $RequiredModulesDirectory -Force | Out-Null
    $dependencyPaths = @()

    foreach ($moduleName in $dependencies.Keys)
    {
        $moduleVersion = $dependencies[$moduleName]
        $modulePath = Join-Path (Join-Path $RequiredModulesDirectory $moduleName) $moduleVersion

        if (Test-Path -LiteralPath $modulePath)
        {
            $dependencyPaths += $modulePath
            continue
        }

        Write-Host "Restoring $moduleName $moduleVersion from PSGallery"
        Save-Module -Name $moduleName -RequiredVersion $moduleVersion -Repository PSGallery -Path $RequiredModulesDirectory -Force -ErrorAction Stop
        if (-not (Test-Path -LiteralPath $modulePath))
        {
            throw "Dependency restore did not create the expected path '$modulePath'."
        }

        $dependencyPaths += $modulePath
    }

    if ($env:OS -eq 'Windows_NT')
    {
        foreach ($dependencyPath in $dependencyPaths)
        {
            Get-ChildItem -Path $dependencyPath -File -Recurse |
                Unblock-File -ErrorAction Stop
        }
    }

    $modulePaths = @($RequiredModulesDirectory) + @(
        $env:PSModulePath -split [System.IO.Path]::PathSeparator |
            Where-Object { $_ -and $_ -ne $RequiredModulesDirectory }
    )
    $env:PSModulePath = $modulePaths -join [System.IO.Path]::PathSeparator
}

function Import-BuildModule
{
    param
    (
        [Parameter(Mandatory)]
        [string]
        $Name
    )

    $dependencyGroups = Import-PowerShellDataFile -Path $DependencyManifest
    $moduleVersion = $dependencyGroups.Build[$Name]
    if (-not $moduleVersion)
    {
        $moduleVersion = $dependencyGroups.Publish[$Name]
    }

    Import-Module -Name $Name -RequiredVersion $moduleVersion -ErrorAction Stop
}

function Build-PSLogs
{
    param
    (
        [Parameter(Mandatory)]
        [string]
        $ModuleVersion
    )

    Import-BuildModule -Name ModuleBuilder

    if (Test-Path -LiteralPath $BuiltModuleDirectory)
    {
        Remove-Item -LiteralPath $BuiltModuleDirectory -Recurse -Force
    }

    $buildParameters = @{
        SourcePath               = $SourceManifest
        OutputDirectory          = $OutputDirectory
        Version                  = $ModuleVersion
        CopyPaths                = @('en-US', 'include')
        Encoding                 = 'UTF8'
        Prefix                   = 'prefix.ps1'
        Suffix                   = 'suffix.ps1'
        ErrorAction              = 'Stop'
    }

    Build-Module @buildParameters | Out-Host

    $modulePath = Join-Path (Join-Path $BuiltModuleDirectory $ModuleVersion) 'PSLogs.psd1'
    if (-not (Test-Path -LiteralPath $modulePath))
    {
        throw "ModuleBuilder did not create the expected module manifest: $modulePath"
    }

    $changelog = [System.IO.File]::ReadAllText((Join-Path $PSScriptRoot 'CHANGELOG.md'))
    $releaseTags = & git -C $PSScriptRoot tag --points-at HEAD
    if ($LASTEXITCODE -ne 0)
    {
        throw 'Could not read the Git tags for the current commit.'
    }

    if ($releaseTags -contains "v$ModuleVersion")
    {
        $versionPattern = '(?ms)^## \[' + [regex]::Escape($ModuleVersion) + '\][^\r\n]*\r?\n(?<notes>.*?)(?=^## \[|\z)'
        $releaseNotesMatch = [regex]::Match($changelog, $versionPattern)
    }
    else
    {
        $releaseNotesMatch = [regex]::Match($changelog, '(?ms)^## \[Unreleased\][^\r\n]*\r?\n(?<notes>.*?)(?=^## \[|\z)')
    }

    if (-not $releaseNotesMatch.Success)
    {
        throw "Could not find release notes for PSLogs $ModuleVersion in CHANGELOG.md."
    }

    Update-ModuleManifest -Path $modulePath -ReleaseNotes $releaseNotesMatch.Groups['notes'].Value.Trim() -ErrorAction Stop

    return (Split-Path -Parent $modulePath)
}

function Invoke-PSLogsTests
{
    param
    (
        [Parameter(Mandatory)]
        [string]
        $ModuleVersion
    )

    Import-BuildModule -Name Pester
    $env:PSModulePath = $OutputDirectory + [System.IO.Path]::PathSeparator + $env:PSModulePath

    New-Item -ItemType Directory -Path $TestResultsDirectory -Force | Out-Null

    $configuration = New-PesterConfiguration
    $configuration.Run.Path = Join-Path $PSScriptRoot 'tests'
    $configuration.Run.PassThru = $true
    $configuration.Output.Verbosity = 'Detailed'
    $configuration.TestResult.Enabled = $true
    $configuration.TestResult.OutputFormat = 'NUnitXml'
    $configuration.TestResult.OutputPath = Join-Path $TestResultsDirectory 'PSLogs.Tests.xml'
    $configuration.CodeCoverage.Enabled = $true
    $configuration.CodeCoverage.Path = @(
        (Join-Path $PSScriptRoot 'source\Private\*.ps1'),
        (Join-Path $PSScriptRoot 'source\Public\*.ps1')
    )
    $configuration.CodeCoverage.OutputFormat = 'JaCoCo'
    $configuration.CodeCoverage.OutputPath = Join-Path $TestResultsDirectory 'JaCoCo_coverage.xml'
    $configuration.CodeCoverage.CoveragePercentTarget = 1

    Write-Host "Testing PSLogs $ModuleVersion"
    $result = Invoke-Pester -Configuration $configuration

    if ($result.FailedCount -gt 0)
    {
        throw "$($result.FailedCount) Pester test(s) failed."
    }
}

function New-PSLogsPackage
{
    param
    (
        [Parameter(Mandatory)]
        [string]
        $ModuleVersion
    )

    $modulePath = Join-Path $BuiltModuleDirectory $ModuleVersion
    $packagePath = Join-Path $OutputDirectory "PSLogs.$ModuleVersion.zip"

    if (-not (Test-Path -LiteralPath (Join-Path $modulePath 'PSLogs.psd1')))
    {
        $modulePath = Build-PSLogs -ModuleVersion $ModuleVersion
    }

    if (Test-Path -LiteralPath $packagePath)
    {
        Remove-Item -LiteralPath $packagePath -Force
    }

    Compress-Archive -Path (Join-Path $modulePath '*') -DestinationPath $packagePath -CompressionLevel Optimal
    Write-Host "Created package: $packagePath"
}

switch ($Task)
{
    'Clean'
    {
        foreach ($path in @($BuiltModuleDirectory, $TestResultsDirectory))
        {
            if (Test-Path -LiteralPath $path)
            {
                Remove-Item -LiteralPath $path -Recurse -Force
            }
        }

        Get-ChildItem -Path $OutputDirectory -Filter 'PSLogs.*.zip' -File -ErrorAction SilentlyContinue |
            Remove-Item -Force
        break
    }

    'InstallDependencies'
    {
        Initialize-BuildDependencies -IncludeDocumentation
        break
    }

    default
    {
        Initialize-BuildDependencies
        $resolvedVersion = Get-ModuleVersion
        $builtModulePath = Build-PSLogs -ModuleVersion $resolvedVersion

        if ($Task -in @('Test', 'Verify'))
        {
            Invoke-PSLogsTests -ModuleVersion $resolvedVersion
        }

        if ($Task -eq 'Package')
        {
            New-PSLogsPackage -ModuleVersion $resolvedVersion
        }

        if ($Task -eq 'Verify')
        {
            Write-Host "Build and tests passed for PSLogs $resolvedVersion ($builtModulePath)"
        }
    }
}
