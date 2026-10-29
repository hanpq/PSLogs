[CmdletBinding()]
param
(
    [Parameter()]
    [string]$Repository = $env:GITHUB_REPOSITORY,

    [Parameter()]
    [string]$ProjectRoot
)

$ErrorActionPreference = 'Stop'
if ([string]::IsNullOrWhiteSpace($ProjectRoot))
{
    $ProjectRoot = Split-Path -Parent $PSScriptRoot
}
if (-not $Repository -or -not $env:GH_TOKEN)
{
    throw 'GITHUB_REPOSITORY and GH_TOKEN are required to create a stable promotion.'
}
if (-not $env:GITHUB_API_URL)
{
    $env:GITHUB_API_URL = 'https://api.github.com'
}

$project = & (Join-Path $PSScriptRoot 'Get-BuildProject.ps1') -ProjectRoot $ProjectRoot
if ([string]::IsNullOrEmpty($project.Prerelease))
{
    throw "Tracked version '$($project.Version)' is already stable; there is no beta to promote."
}
if ($project.Prerelease -notmatch '^beta[0-9]{3,}$')
{
    throw "Tracked prerelease '$($project.Prerelease)' is not a supported beta channel."
}

$tag = "v$($project.Version)"
$null = & git -C $ProjectRoot rev-parse --verify "refs/tags/$tag" 2>$null
if ($LASTEXITCODE -ne 0)
{
    throw "Latest beta tag '$tag' is not available in the checkout."
}
$commitsAfterBeta = & git -C $ProjectRoot rev-list --count "$tag..HEAD"
if ($LASTEXITCODE -ne 0)
{
    throw "Could not compare HEAD with beta tag '$tag'."
}
if ([int]$commitsAfterBeta -ne 0)
{
    throw "Cannot promote '$tag' while main has $commitsAfterBeta commit(s) after it. Release or merge those changes as a beta first."
}

$headers = @{
    Authorization          = "Bearer $env:GH_TOKEN"
    Accept                 = 'application/vnd.github+json'
    'X-GitHub-Api-Version' = '2022-11-28'
}
$api = "$($env:GITHUB_API_URL)/repos/$Repository"
$release = Invoke-RestMethod -Uri "$api/releases/tags/$([uri]::EscapeDataString($tag))" -Headers $headers
if (-not $release.prerelease -or $release.tag_name -cne $tag)
{
    throw "GitHub release '$tag' is missing or is not marked as a prerelease."
}

$manifestPath = Join-Path $ProjectRoot '.release-please-manifest.json'
$manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
if ($manifest.'.' -cne $project.Version)
{
    throw 'The tracked Release Please manifest changed while preparing the stable promotion.'
}
$stableManifest = [ordered]@{ '.' = $project.ModuleVersion } | ConvertTo-Json
$stableVersion = $project.ModuleVersion

$changelogPath = Join-Path $ProjectRoot 'CHANGELOG.md'
$changelog = Get-Content -LiteralPath $changelogPath -Raw
$newline = if ($changelog.Contains("`r`n")) { "`r`n" } else { "`n" }
$normalizedChangelog = $changelog.Replace("`r`n", "`n")
$heading = [regex]::Match($normalizedChangelog, '(?m)^## \[?(?<version>\d+\.\d+\.\d+(?:-[A-Za-z][A-Za-z0-9]*)?)\]?[^\n]*(?:\n|$)')
if (-not $heading.Success -or $heading.Groups['version'].Value -cne $project.Version)
{
    throw "The first changelog release must match the tracked beta '$($project.Version)'."
}

$stableTagPattern = "\.\.\.v$([regex]::Escape($project.Version))(?=\))"
if ($heading.Value -notmatch $stableTagPattern)
{
    throw "The beta changelog heading does not end at tag '$tag'."
}
$stableHeading = $heading.Value.Replace($project.Version, $stableVersion)
$stableHeading = [regex]::Replace($stableHeading, '\(\d{4}-\d{2}-\d{2}\)', "($(Get-Date -Format 'yyyy-MM-dd'))")
$betaSectionEnd = $normalizedChangelog.IndexOf("`n## ", $heading.Index + $heading.Length)
if ($betaSectionEnd -lt 0)
{
    $betaSectionEnd = $normalizedChangelog.Length
}
$stableSection = $stableHeading + $normalizedChangelog.Substring($heading.Index + $heading.Length,
    $betaSectionEnd - $heading.Index - $heading.Length)
$candidateChangelog = $normalizedChangelog.Substring(0, $heading.Index) +
    $stableSection + "`n`n" + $normalizedChangelog.Substring($heading.Index)

$sectionEnd = $candidateChangelog.IndexOf("`n## ", $heading.Index + $stableSection.Length)
if ($sectionEnd -lt 0)
{
    $sectionEnd = $candidateChangelog.Length
}
$releaseNotes = $candidateChangelog.Substring($heading.Index, $sectionEnd - $heading.Index).Trim()
$body = @"
:robot: I have created a release *beep* *boop*
---

$releaseNotes

---
This PR was generated with [Release Please](https://github.com/googleapis/release-please). See [documentation](https://github.com/googleapis/release-please#release-please).
"@
$body = $body.Replace("`r`n", "`n")
$null = & (Join-Path $PSScriptRoot 'Get-StableReleaseNotes.ps1') `
    -Changelog $candidateChangelog -PullRequestBody $body -Version $stableVersion
$candidateChangelog = $candidateChangelog.Replace("`n", $newline)
$body = $body.Replace("`n", $newline)

$pullRequests = Invoke-RestMethod -Uri "$api/pulls?state=open&base=main&per_page=100" -Headers $headers
$branch = 'release-please--branches--main'
foreach ($pullRequest in $pullRequests)
{
    $labels = @($pullRequest.labels | ForEach-Object name)
    $stableReleaseTitle = $pullRequest.title -match '^chore\(main\): release \d+\.\d+\.\d+$'
    $stableReleaseBranch = $pullRequest.head.ref -ceq $branch
    if ('stable-promotion' -in $labels -or ($stableReleaseTitle -and $stableReleaseBranch))
    {
        Write-Output $pullRequest.number
        return
    }
    if ('autorelease: pending' -in $labels -or $stableReleaseBranch)
    {
        throw "Release Please pull request #$($pullRequest.number) is still open. Merge or close it before promoting the beta."
    }
}

$branchReference = "$api/git/ref/heads/$branch"
$baseReference = Invoke-RestMethod -Uri "$api/git/ref/heads/main" -Headers $headers
$baseSha = $baseReference.object.sha
$checkoutSha = & git -C $ProjectRoot rev-parse HEAD
if ($LASTEXITCODE -ne 0 -or $checkoutSha -cne $baseSha)
{
    throw 'Main changed since this workflow checked out the beta. Rerun the workflow before promoting.'
}
try
{
    $null = Invoke-RestMethod -Uri $branchReference -Headers $headers
    $branchExists = $true
}
catch
{
    if ([int]$_.Exception.Response.StatusCode -ne 404)
    {
        throw
    }
    $branchExists = $false
}
if ($branchExists)
{
    $referencePayload = @{ sha = $baseSha; force = $true } | ConvertTo-Json
    Invoke-RestMethod -Method Patch -Uri "$api/git/refs/heads/$branch" -Headers $headers `
        -ContentType 'application/json' -Body $referencePayload | Out-Null
}
else
{
    $referencePayload = @{ ref = "refs/heads/$branch"; sha = $baseSha } | ConvertTo-Json
    Invoke-RestMethod -Method Post -Uri "$api/git/refs" -Headers $headers `
        -ContentType 'application/json' -Body $referencePayload | Out-Null
}

foreach ($entry in @(
        @{ Path = '.release-please-manifest.json'; Content = $stableManifest },
        @{ Path = 'version.txt'; Content = "$stableVersion`n" },
        @{ Path = 'CHANGELOG.md'; Content = $candidateChangelog }
    ))
{
    $file = $null
    try
    {
        $file = Invoke-RestMethod -Uri "$api/contents/$($entry.Path)?ref=$baseSha" -Headers $headers
    }
    catch
    {
        if ($entry.Path -ne 'version.txt' -or [int]$_.Exception.Response.StatusCode -ne 404)
        {
            throw
        }
    }
    $payload = @{
        message = "chore(main): prepare stable promotion $stableVersion"
        branch  = $branch
        content = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($entry.Content))
    }
    if ($file)
    {
        $payload.sha = $file.sha
    }
    $payload = $payload | ConvertTo-Json
    Invoke-RestMethod -Method Put -Uri "$api/contents/$($entry.Path)" -Headers $headers `
        -ContentType 'application/json' -Body ([System.Text.Encoding]::UTF8.GetBytes($payload)) | Out-Null
}

$pullRequestPayload = @{
    title = "chore(main): release $stableVersion"
    head  = $branch
    base  = 'main'
    body  = $body
} | ConvertTo-Json
$pullRequest = Invoke-RestMethod -Method Post -Uri "$api/pulls" -Headers $headers `
    -ContentType 'application/json' -Body ([System.Text.Encoding]::UTF8.GetBytes($pullRequestPayload))

foreach ($label in @('autorelease: pending', 'stable-promotion'))
{
    $encodedLabel = [uri]::EscapeDataString($label)
    try
    {
        $null = Invoke-RestMethod -Uri "$api/labels/$encodedLabel" -Headers $headers
    }
    catch
    {
        if ([int]$_.Exception.Response.StatusCode -ne 404)
        {
            throw
        }
        $labelPayload = @{
            name  = $label
            color = if ($label -eq 'stable-promotion') { '5319e7' } else { 'ededed' }
        } | ConvertTo-Json
        Invoke-RestMethod -Method Post -Uri "$api/labels" -Headers $headers `
            -ContentType 'application/json' -Body $labelPayload | Out-Null
    }
}
$labelsPayload = @{ labels = @('autorelease: pending', 'stable-promotion') } | ConvertTo-Json
Invoke-RestMethod -Method Put -Uri "$api/issues/$($pullRequest.number)/labels" -Headers $headers `
    -ContentType 'application/json' -Body $labelsPayload | Out-Null

Write-Verbose "Created stable promotion pull request #$($pullRequest.number) for $stableVersion."
Write-Output $pullRequest.number
