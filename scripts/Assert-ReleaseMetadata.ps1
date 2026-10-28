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
    $ProjectRoot
)

$ErrorActionPreference = 'Stop'
if ([string]::IsNullOrWhiteSpace($ProjectRoot))
{
    $ProjectRoot = Split-Path -Parent $PSScriptRoot
}

$project = & (Join-Path $PSScriptRoot 'Get-BuildProject.ps1') -ProjectRoot $ProjectRoot
if ($Tag -cne "v$($project.Version)")
{
    throw "Release tag '$Tag' does not match tracked version 'v$($project.Version)'."
}

$hasPrerelease = -not [string]::IsNullOrEmpty($project.Prerelease)
if ($IsPrerelease -ne $hasPrerelease)
{
    throw "The GitHub prerelease flag does not match version '$($project.Version)'."
}

$configuration = Get-Content -LiteralPath (Join-Path $ProjectRoot 'release-please-config.json') -Raw | ConvertFrom-Json
$configuredPrerelease = $configuration.packages.'.'.prerelease
if ($configuredPrerelease -isnot [bool])
{
    throw 'Release Please must explicitly configure a boolean prerelease mode for the root package.'
}
if ($configuredPrerelease -ne $hasPrerelease)
{
    throw "Release Please prerelease mode does not match version '$($project.Version)'. Review the release PR before publishing."
}

$project
