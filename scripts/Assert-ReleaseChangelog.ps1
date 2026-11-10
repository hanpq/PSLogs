[CmdletBinding()]
param
(
    [string]$ProjectRoot = (Split-Path -Parent $PSScriptRoot),
    [switch]$ReleasePullRequest
)

$ErrorActionPreference = 'Stop'
$project = & "$PSScriptRoot\Get-BuildProject.ps1" -ProjectRoot $ProjectRoot
$changelog = Get-Content -LiteralPath (Join-Path $ProjectRoot 'CHANGELOG.md') -Raw
$latest = & "$PSScriptRoot\Get-LatestReleaseTag.ps1" -ProjectRoot $ProjectRoot
$sections = [regex]::Matches($changelog.Replace("`r`n", "`n"), '(?ms)^## \[?(?<version>\d+\.\d+\.\d+(?:-[A-Za-z][A-Za-z0-9]*)?)\]?[^\n]*\n.*?(?=^## |\z)')
if (-not $sections.Count) { throw 'No version sections were found in CHANGELOG.md.' }
if ($ReleasePullRequest -and $sections[0].Groups['version'].Value -cne $project.Version)
{
    throw "The first changelog release must match the release PR version '$($project.Version)'."
}
foreach ($section in $sections)
{
    $version = $section.Groups['version'].Value
    $candidate = $ReleasePullRequest -and $section.Index -eq $sections[0].Index -and $version -ceq $project.Version
    if ((& "$PSScriptRoot\Compare-ReleaseVersion.ps1" -Left $version -Right $latest.Substring(1)) -gt 0 -and -not $candidate)
    {
        throw "Unpublished changelog section '$version' is newer than latest tag '$latest'. Remove the stale section or finish its release before preparing another release."
    }
}

$top = $sections[0]
$version = $top.Groups['version'].Value
if ($version -match '-')
{
    $stableVersion = ($version -split '-')[0]
    $stableSection = $top.Value.Replace($version, $stableVersion)
    $candidateChangelog = $stableSection + "`n`n" + $changelog
}
else
{
    $stableVersion = $version
    $stableSection = $top.Value
    $candidateChangelog = $changelog
}
$body = ":robot: I have created a release *beep* *boop*`n---`n`n$($stableSection.Trim())`n`n---`nThis PR was generated with [Release Please]"
$null = & "$PSScriptRoot\Get-StableReleaseNotes.ps1" -Changelog $candidateChangelog -PullRequestBody $body -Version $stableVersion
Write-Host "Changelog release boundaries and stable notes validated against $latest."
