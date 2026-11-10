[CmdletBinding()]
param
(
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
    throw 'Main changed while the stable candidate was being refreshed. Rerun Publish beta.'
}
$owner = $Repository.Split('/')[0]
$pulls = @(Invoke-RestMethod -Uri "$api/pulls?state=open&base=main&head=$owner`:release-please--branches--main&per_page=100" -Headers $headers | ForEach-Object { $_ })
$candidates = @($pulls | Where-Object { $_.head.repo.full_name -ceq $Repository })
if ($candidates.Count -ne 1)
{
    throw 'Expected one open stable Release Please PR. Merge releasable Conventional Commits and rerun Publish beta.'
}
$pr = $candidates[0]
$file = Invoke-RestMethod -Uri "$api/contents/.release-please-manifest.json?ref=$($pr.head.sha)" -Headers $headers
if ($file.encoding -ne 'base64') { throw 'Expected a base64 stable release manifest.' }
$version = ([Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($file.content)) | ConvertFrom-Json).'.'
$candidate = & "$PSScriptRoot\Get-BuildProject.ps1" -ProjectRoot $ProjectRoot -Version $version
if ($candidate.Prerelease -or [version]$candidate.ModuleVersion -le [version]$project.ModuleVersion)
{
    throw "Candidate '$version' must be a stable version newer than '$($project.Version)'."
}
$tags = @(& git -C $ProjectRoot tag --list "v$version*")
if ($LASTEXITCODE -ne 0) { throw 'Could not read existing beta tags.' }
if ("v$version" -cin $tags) { throw "Stable version '$version' is already tagged. Refresh the stable release PR before publishing a beta." }
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
