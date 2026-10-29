[CmdletBinding()]
param
(
    [Parameter(Mandatory)]
    [ValidatePattern('^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$')]
    [string]$Repository,

    [Parameter(Mandatory)]
    [ValidateRange(1, [int]::MaxValue)]
    [int]$PullRequestNumber
)

$ErrorActionPreference = 'Stop'
if (-not $env:GH_TOKEN)
{
    throw 'GH_TOKEN is required to update stable release notes.'
}
$headers = @{
    Authorization          = "Bearer $env:GH_TOKEN"
    Accept                 = 'application/vnd.github+json'
    'X-GitHub-Api-Version' = '2022-11-28'
}
$api = "$env:GITHUB_API_URL/repos/$Repository"
if (-not $env:GITHUB_API_URL)
{
    throw 'GITHUB_API_URL is required.'
}
$pr = Invoke-RestMethod -Uri "$api/pulls/$PullRequestNumber" -Headers $headers
if ($pr.state -ne 'open' -or $pr.head.repo.full_name -ne $Repository -or
    'autorelease: pending' -notin $pr.labels.name)
{
    throw 'Expected an open Release Please PR with a branch in this repository.'
}

$files = @{}
foreach ($path in @('release-please-config.json', '.release-please-manifest.json', 'CHANGELOG.md'))
{
    $file = Invoke-RestMethod -Uri "$api/contents/${path}?ref=$($pr.head.sha)" -Headers $headers
    if ($file.encoding -ne 'base64')
    {
        throw "Expected base64 content for '$path'."
    }
    $files[$path] = @{
        Sha     = $file.sha
        Content = [System.Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($file.content))
    }
}
$config = $files['release-please-config.json'].Content | ConvertFrom-Json
$configuredPrerelease = $config.packages.'.'.prerelease
if ($configuredPrerelease -isnot [bool])
{
    throw 'Release Please must explicitly configure a boolean prerelease mode for the root package.'
}
if ($configuredPrerelease)
{
    Write-Output 'Prerelease mode: keeping incremental notes.'
    return
}
$version = ($files['.release-please-manifest.json'].Content | ConvertFrom-Json).'.'
$result = & (Join-Path $PSScriptRoot 'Get-StableReleaseNotes.ps1') `
    -Changelog $files['CHANGELOG.md'].Content -PullRequestBody $pr.body -Version $version
if (-not $result.RolledUp)
{
    Write-Output 'No prerelease notes to consolidate.'
    return
}

if ($result.Changelog -cne $files['CHANGELOG.md'].Content -or $result.PullRequestBody -cne $pr.body)
{
    # Refuse to overwrite a PR branch that changed while its notes were being computed.
    $current = Invoke-RestMethod -Uri "$api/pulls/$PullRequestNumber" -Headers $headers
    if ($current.head.sha -ne $pr.head.sha -or $current.state -ne 'open')
    {
        throw 'Release PR changed during consolidation. Rerun the workflow.'
    }
}
if ($result.Changelog -cne $files['CHANGELOG.md'].Content)
{
    $payload = @{
        message = "chore: consolidate stable release notes`n`nCo-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>"
        branch  = $pr.head.ref
        sha     = $files['CHANGELOG.md'].Sha
        content = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($result.Changelog))
    } | ConvertTo-Json
    Invoke-RestMethod -Method Put -Uri "$api/contents/CHANGELOG.md" -Headers $headers `
        -ContentType 'application/json; charset=utf-8' -Body ([System.Text.Encoding]::UTF8.GetBytes($payload)) | Out-Null
}
if ($result.PullRequestBody -cne $pr.body)
{
    $payload = @{ body = $result.PullRequestBody } | ConvertTo-Json
    Invoke-RestMethod -Method Patch -Uri "$api/pulls/$PullRequestNumber" -Headers $headers `
        -ContentType 'application/json; charset=utf-8' -Body ([System.Text.Encoding]::UTF8.GetBytes($payload)) | Out-Null
}
Write-Output "Stable notes consolidated for release PR #$PullRequestNumber."
