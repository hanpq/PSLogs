[CmdletBinding()]
param
(
    [Parameter(Mandatory)]
    [ValidateSet('beta', 'stable')]
    [string]$Channel,

    [Parameter(Mandatory)]
    [string]$Version,

    [Parameter(Mandatory)]
    [string]$LatestVersion,

    [switch]$DispatchInput
)

$ErrorActionPreference = 'Stop'
$pattern = '^(?:0|[1-9][0-9]*)\.(?:0|[1-9][0-9]*)\.(?:0|[1-9][0-9]*)(?:-beta[0-9]{3,})?$'
if ($Version -cnotmatch $pattern -or $LatestVersion -cnotmatch $pattern)
{
    throw "Invalid release version '$Version' or latest version '$LatestVersion'. Expected Major.Minor.Patch with optional -betaNNN."
}
if ($DispatchInput -and $Channel -eq 'beta' -and $Version -notmatch '-')
{
    $Version += '-beta001'
}
if (($Channel -eq 'beta') -ne ($Version -match '-'))
{
    throw "Version '$Version' does not match the $Channel channel. Expected $(if ($Channel -eq 'beta') { 'Major.Minor.Patch-betaNNN (for example 3.3.7-betaNNN)' } else { 'Major.Minor.Patch without a prerelease suffix' })."
}

if ((& "$PSScriptRoot\Compare-ReleaseVersion.ps1" -Left $Version -Right $LatestVersion) -le 0)
{
    throw "Requested version '$Version' must be greater than latest tag 'v$LatestVersion'."
}
$Version
