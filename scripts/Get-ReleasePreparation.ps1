[CmdletBinding()]
param
(
    [Parameter(Mandatory)]
    [ValidateSet('beta', 'stable')]
    [string]$Channel,

    [string]$Version,
    [string]$Repository = $env:GITHUB_REPOSITORY,
    [string]$ProjectRoot = (Split-Path -Parent $PSScriptRoot)
)

$ErrorActionPreference = 'Stop'
if (-not $Repository -or -not $env:GH_TOKEN -or -not $env:GITHUB_API_URL)
{
    throw 'GITHUB_REPOSITORY, GH_TOKEN and GITHUB_API_URL are required.'
}
$headers = @{ Authorization = "Bearer $env:GH_TOKEN"; Accept = 'application/vnd.github+json' }
$api = "$env:GITHUB_API_URL/repos/$Repository"
$pendingNumbers = @()
$page = 1
do
{
    $pending = @(Invoke-RestMethod -Uri "$api/issues?state=closed&labels=autorelease%3A%20pending&per_page=100&page=$page" -Headers $headers | ForEach-Object { $_ })
    foreach ($issue in $pending)
    {
        if ($issue.pull_request)
        {
            $pr = Invoke-RestMethod -Uri "$api/pulls/$($issue.number)" -Headers $headers
            if ($pr.merged_at -and $pr.base.ref -ceq 'main')
            {
                $pendingNumbers += $issue.number
            }
        }
    }
    $page++
} while ($pending.Count -eq 100)
if ($pendingNumbers.Count)
{
    $remediation = $pendingNumbers | ForEach-Object {
        "PR #${_}: rerun its failed Prepare release finalization. If its matching tag and published GitHub release already exist, remove the stale label with: gh pr edit $_ --repo $Repository --remove-label 'autorelease: pending'. Do not remove the label from an unpublished release."
    }
    throw "Merged releases are still pending. $($remediation -join ' ')"
}

$sha = & git -C $ProjectRoot rev-parse HEAD
if ($LASTEXITCODE -ne 0) { throw 'Could not resolve HEAD.' }
$latest = & "$PSScriptRoot\Get-LatestReleaseTag.ps1" -ProjectRoot $ProjectRoot
$release = Invoke-RestMethod -Uri "$api/releases/tags/$latest" -Headers $headers
if ($release.tag_name -cne $latest -or $release.draft -or -not $release.published_at -or
    [bool]$release.prerelease -ne ($latest -match '-'))
{
    throw "Latest tag '$latest' must have a matching published GitHub release with the correct prerelease flag."
}
$messages = @(& git -C $ProjectRoot log "$latest..HEAD" --format=%B)
if ($LASTEXITCODE -ne 0) { throw "Could not read commits since '$latest'." }
$requestedVersion = ''
if ($Version)
{
    $requestedVersion = & "$PSScriptRoot\Assert-ReleaseVersion.ps1" -Channel $Channel -Version $Version -LatestVersion $latest.Substring(1) -DispatchInput
}
foreach ($footer in [regex]::Matches(($messages -join "`n"), '(?im)^[ \t]*Release-As:[ \t]*(?<version>[^\r\n]*)'))
{
    $footerVersion = & "$PSScriptRoot\Assert-ReleaseVersion.ps1" -Channel $Channel -Version $footer.Groups['version'].Value.Trim() -LatestVersion $latest.Substring(1)
    if ($requestedVersion -and $footerVersion -cne $requestedVersion)
    {
        throw "Release-As footer '$footerVersion' conflicts with dispatch version '$requestedVersion'. Remove the conflicting footer from the unreleased history before retrying."
    }
}
if ($Channel -eq 'stable' -and $requestedVersion)
{
    $project = & "$PSScriptRoot\Get-BuildProject.ps1" -ProjectRoot $ProjectRoot
    if ($requestedVersion -cne $project.ModuleVersion)
    {
        throw "Stable promotion can only request the published beta's numeric version '$($project.ModuleVersion)'."
    }
}
$page = 1
do
{
    $pulls = @(Invoke-RestMethod -Uri "$api/pulls?state=open&base=main&per_page=100&page=$page" -Headers $headers | ForEach-Object { $_ })
    foreach ($pr in $pulls)
    {
        if ($pr.head.ref -ceq 'release-please--branches--main' -and $pr.head.repo.full_name -ceq $Repository -and
            $pr.body -cmatch "<!-- release-preparation:$Channel`:$sha -->")
        {
            if ('autorelease: pending' -notin $pr.labels.name -or
                ('stable-promotion' -in $pr.labels.name) -ne ($Channel -eq 'stable'))
            {
                throw "Release PR #$($pr.number) has missing or inconsistent release labels. Restore its channel labels before retrying."
            }
            Write-Host "::notice::Release PR #$($pr.number) already exists for $sha`: $($pr.html_url). Close it before requesting a different version on this commit."
            return [pscustomobject]@{ Skip = $true; Version = ''; Sha = $sha }
        }
    }
    $page++
} while ($pulls.Count -eq 100)
[pscustomobject]@{ Skip = $false; Version = $requestedVersion; Sha = $sha }
