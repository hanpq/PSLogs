[CmdletBinding()]
param
(
    [Parameter(Mandatory)]
    [string]
    $Tag,

    [Parameter(Mandatory)]
    [bool]
    $IsPrerelease,

    [Parameter()]
    [string]
    $RefTag,

    [Parameter()]
    [string]
    $BuiltModulePath,

    [Parameter()]
    [string]
    $ProjectRoot
)

$ErrorActionPreference = 'Stop'
if ([string]::IsNullOrWhiteSpace($ProjectRoot))
{
    $ProjectRoot = Split-Path -Parent $PSScriptRoot
}

$project = & (Join-Path $PSScriptRoot 'Get-BuildProject.ps1') -ProjectRoot $ProjectRoot
if ($project.Prerelease)
{
    throw 'The tracked Release Please version must be stable; beta publishing must not update the stable baseline.'
}
if ($Tag -cnotmatch '^v\d+\.\d+\.\d+(?:-beta[0-9]{3,})?$')
{
    throw "Unsupported release tag '$Tag'. Expected vMajor.Minor.Patch with optional -betaNNN."
}
$tagProject = & (Join-Path $PSScriptRoot 'Get-BuildProject.ps1') -ProjectRoot $ProjectRoot -Version $Tag.Substring(1)
if ($tagProject.Prerelease)
{
    if ([version]$tagProject.ModuleVersion -le [version]$project.ModuleVersion)
    {
        throw "Beta version '$($tagProject.Version)' must be newer than the stable baseline '$($project.Version)'."
    }
}
elseif ($Tag -cne "v$($project.Version)")
{
    throw "Release tag '$Tag' does not match tracked version 'v$($project.Version)'."
}
if (-not [string]::IsNullOrWhiteSpace($RefTag) -and $Tag -cne $RefTag)
{
    throw "Release event tag '$Tag' does not match checked-out ref '$RefTag'."
}

$project = $tagProject
$hasPrerelease = -not [string]::IsNullOrEmpty($project.Prerelease)
if ($IsPrerelease -ne $hasPrerelease)
{
    throw "The GitHub prerelease flag does not match version '$($project.Version)'."
}

if (-not [string]::IsNullOrWhiteSpace($BuiltModulePath))
{
    $builtManifestPath = Join-Path $BuiltModulePath "$($project.Name).psd1"
    if (-not (Test-Path -LiteralPath $builtManifestPath -PathType Leaf))
    {
        throw "Built module manifest '$builtManifestPath' does not exist."
    }

    $builtManifest = Import-PowerShellDataFile -LiteralPath $builtManifestPath
    if ([string]$builtManifest.PrivateData.PSData.ReleaseNotes -and
        $builtManifest.PrivateData.PSData.ReleaseNotes.Length -gt 10600)
    {
        throw 'The built manifest ReleaseNotes exceeds the PSGallery limit of 10,600 characters.'
    }
    $builtVersion = [string]$builtManifest.ModuleVersion
    $builtPrerelease = [string]$builtManifest.PrivateData.PSData.Prerelease
    if ($builtVersion -cne $project.ModuleVersion -or $builtPrerelease -cne $project.Prerelease)
    {
        $builtFullVersion = if ($builtPrerelease) { "$builtVersion-$builtPrerelease" } else { $builtVersion }
        throw "Built module version '$builtFullVersion' does not match release version '$($project.Version)'."
    }
}

$project
