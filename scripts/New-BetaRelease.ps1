[CmdletBinding()]
param
(
    [Parameter(Mandatory)]
    [string]$CandidateVersion,
    [string]$Repository = $env:GITHUB_REPOSITORY,
    [string]$ProjectRoot = (Split-Path -Parent $PSScriptRoot)
)

$ErrorActionPreference = 'Stop'
if (-not $Repository -or -not $env:GH_TOKEN -or -not $env:GITHUB_API_URL)
{
    throw 'GITHUB_REPOSITORY, GH_TOKEN and GITHUB_API_URL are required.'
}
$project = & "$PSScriptRoot\Get-BuildProject.ps1" -ProjectRoot $ProjectRoot
if ($project.Prerelease)
{
    throw 'The tracked version must be the last stable release. Finish migrating the beta baseline before publishing previews.'
}
$sha = & git -C $ProjectRoot rev-parse HEAD
if ($LASTEXITCODE -ne 0) { throw 'Could not resolve the beta source commit.' }
$headers = @{ Authorization = "Bearer $env:GH_TOKEN"; Accept = 'application/vnd.github+json' }
$api = "$env:GITHUB_API_URL/repos/$Repository"
$main = Invoke-RestMethod -Uri "$api/git/ref/heads/main" -Headers $headers
if ($main.object.sha -cne $sha)
{
    throw 'Main changed while the beta version was being inferred. Rerun Publish beta.'
}
$version = $CandidateVersion
$candidate = & "$PSScriptRoot\Get-BuildProject.ps1" -ProjectRoot $ProjectRoot -Version $version
if ($candidate.Prerelease -or [version]$candidate.ModuleVersion -le [version]$project.ModuleVersion)
{
    throw "Candidate '$version' must be a stable version newer than '$($project.Version)'."
}
$tags = @(& git -C $ProjectRoot tag --list "v$version*")
if ($LASTEXITCODE -ne 0) { throw 'Could not read existing beta tags.' }
if ("v$version" -cin $tags) { throw "Stable version '$version' is already tagged. Merge releasable changes before publishing a beta." }
$numbers = @($tags | ForEach-Object {
    if ($_ -cmatch "^v$([regex]::Escape($version))-beta([0-9]{3,})$") { [int]$Matches[1] }
})
$next = if ($numbers.Count) { ($numbers | Measure-Object -Maximum).Maximum + 1 } else { 1 }
$betaVersion = "$version-beta$('{0:D3}' -f [int]$next)"
$tag = "v$betaVersion"
$notes = "Preview build $betaVersion from commit $sha. The complete changelog will be generated with the next stable release."
& gh release create $tag --repo $Repository --target $sha --prerelease --latest=false --title $tag --notes $notes
if ($LASTEXITCODE -ne 0) { throw "Could not create beta release '$tag'. See the GitHub CLI error above." }
Write-Host "Created $tag from $sha. The Release workflow will build, test and publish it."
