[CmdletBinding()]
param
(
    [Parameter(Mandatory)]
    [ValidateSet('push', 'workflow_dispatch')]
    [string]$EventName,

    [Parameter()]
    [ValidateSet('beta', 'stable')]
    [string]$DispatchChannel,

    [Parameter()]
    [string]$CommitSha,

    [Parameter(Mandatory)]
    [string]$RefName,

    [Parameter(Mandatory)]
    [ValidatePattern('^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$')]
    [string]$Repository
)

$ErrorActionPreference = 'Stop'
if ($RefName -cne 'main')
{
    throw "Release workflows must run from main, not '$RefName'."
}

$channel = if ($EventName -eq 'workflow_dispatch')
{
    if (-not $DispatchChannel)
    {
        throw 'A release channel is required for workflow_dispatch.'
    }
    $DispatchChannel
}
else
{
    'beta'
}

$result = [pscustomobject]@{
    Channel   = $channel
    Skip      = $false
    RunAction = $EventName -eq 'push' -or $channel -eq 'beta'
}
if ($EventName -eq 'workflow_dispatch' -and $channel -eq 'stable')
{
    return $result
}

if (-not $env:GH_TOKEN -or -not $env:GITHUB_API_URL)
{
    throw 'GH_TOKEN and GITHUB_API_URL are required to resolve the release channel.'
}

$headers = @{
    Authorization          = "Bearer $env:GH_TOKEN"
    Accept                 = 'application/vnd.github+json'
    'X-GitHub-Api-Version' = '2022-11-28'
}
$api = "$($env:GITHUB_API_URL)/repos/$Repository"

if ($EventName -eq 'push')
{
    if ([string]::IsNullOrWhiteSpace($CommitSha))
    {
        throw 'CommitSha is required for push events.'
    }
    $mergedPullRequests = Invoke-RestMethod -Uri "$api/commits/$CommitSha/pulls" -Headers $headers
    foreach ($pullRequest in $mergedPullRequests)
    {
        $labels = @($pullRequest.labels | ForEach-Object name)
        $stableReleaseTitle = $pullRequest.title -match '^chore\(main\): release \d+\.\d+\.\d+$'
        $stableReleaseBranch = $pullRequest.head.ref -ceq 'release-please--branches--main'
        $isMerged = $pullRequest.state -eq 'closed' -and -not [string]::IsNullOrWhiteSpace($pullRequest.merged_at)
        if ($isMerged -and $pullRequest.merge_commit_sha -eq $CommitSha -and
            ('stable-promotion' -in $labels -or ($stableReleaseTitle -and $stableReleaseBranch)))
        {
            $result.Channel = 'stable'
            return $result
        }
    }
}

$openPullRequests = Invoke-RestMethod -Uri "$api/pulls?state=open&base=main&per_page=100" -Headers $headers
foreach ($pullRequest in $openPullRequests)
{
    $labels = @($pullRequest.labels | ForEach-Object name)
    $stableReleaseTitle = $pullRequest.title -match '^chore\(main\): release \d+\.\d+\.\d+$'
    $stableReleaseBranch = $pullRequest.head.ref -ceq 'release-please--branches--main'
    if ('stable-promotion' -in $labels -or ($stableReleaseTitle -and $stableReleaseBranch))
    {
        $result.Skip = $true
        $result.RunAction = $false
        return $result
    }
}

$result
