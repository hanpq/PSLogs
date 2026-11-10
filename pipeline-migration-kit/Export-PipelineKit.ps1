<#
.SYNOPSIS
    Assembles the pipeline migration kit from the live PSLogs files.

.DESCRIPTION
    Copies the instruction documents and every file listed in kit-files.psd1 into a
    self-contained folder. Copy the resulting folder to the root of the module
    repository that should be migrated and point an AI agent at AI-MIGRATION.md.

.EXAMPLE
    ./pipeline-migration-kit/Export-PipelineKit.ps1
#>
[CmdletBinding()]
param
(
    [Parameter()]
    [string]
    $OutputPath
)

$ErrorActionPreference = 'Stop'
$kitRoot = $PSScriptRoot
$projectRoot = Split-Path -Parent $kitRoot
if ([string]::IsNullOrWhiteSpace($OutputPath))
{
    $OutputPath = Join-Path $projectRoot 'output\pipeline-migration-kit'
}
$OutputPath = [System.IO.Path]::GetFullPath($OutputPath)
$separator = [System.IO.Path]::DirectorySeparatorChar
foreach ($protectedPath in @($kitRoot, $projectRoot))
{
    $protectedFullPath = [System.IO.Path]::GetFullPath($protectedPath).TrimEnd($separator)
    if ($OutputPath.TrimEnd($separator) -eq $protectedFullPath -or
        ($protectedPath -eq $kitRoot -and $OutputPath.StartsWith($protectedFullPath + $separator, [System.StringComparison]::OrdinalIgnoreCase)))
    {
        throw "OutputPath '$OutputPath' would overwrite the kit sources. Use the default or a folder outside pipeline-migration-kit."
    }
}

$inventory = Import-PowerShellDataFile -LiteralPath (Join-Path $kitRoot 'kit-files.psd1')
$trackedFiles = @(& git -C $projectRoot ls-files)
if ($LASTEXITCODE -ne 0)
{
    throw 'Could not list the files tracked by Git.'
}
foreach ($file in @($inventory.Copy) + @($inventory.Adapt))
{
    if ($file -cnotin $trackedFiles)
    {
        throw "Kit file '$file' is not tracked in this repository. Update kit-files.psd1."
    }
}

if (Test-Path -LiteralPath $OutputPath)
{
    Remove-Item -LiteralPath $OutputPath -Recurse -Force
}
New-Item -ItemType Directory -Path $OutputPath -Force | Out-Null

foreach ($document in @('README.md', 'AI-MIGRATION.md', 'MAINTAINER-SETUP.md', 'kit-files.psd1'))
{
    Copy-Item -LiteralPath (Join-Path $kitRoot $document) -Destination $OutputPath
}

foreach ($category in @('Copy', 'Adapt'))
{
    foreach ($file in $inventory[$category])
    {
        $destination = Join-Path (Join-Path $OutputPath $category.ToLowerInvariant()) $file
        New-Item -ItemType Directory -Path (Split-Path -Parent $destination) -Force | Out-Null
        Copy-Item -LiteralPath (Join-Path $projectRoot $file) -Destination $destination
    }
}

$commit = & git -C $projectRoot rev-parse HEAD
$changes = @(& git -C $projectRoot status --porcelain -- @($inventory.Copy) @($inventory.Adapt) 'pipeline-migration-kit')
$origin = & git -C $projectRoot remote get-url origin 2>$null
@(
    "Source repository: $origin"
    "Source commit: $commit"
    "Uncommitted kit changes: $($changes.Count -gt 0)"
    "Exported: $((Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ'))"
) | Set-Content -LiteralPath (Join-Path $OutputPath 'KIT-VERSION.txt') -Encoding utf8

if ($changes.Count -gt 0)
{
    Write-Warning 'The kit contains uncommitted changes. Commit them first if the kit should be reproducible.'
}
Write-Output "Pipeline migration kit exported to $OutputPath"
