[CmdletBinding()]
param
(
    [Parameter(Mandatory)]
    [ValidateSet('beta', 'stable')]
    [string]$Channel,

    [Parameter(Mandatory)]
    [ValidatePattern('^[0-9a-f]{40}$')]
    [string]$Sha,

    [string]$Repository = $env:GITHUB_REPOSITORY,
    [string]$Version
)

$ErrorActionPreference = 'Stop'
if (-not $Repository -or -not $env:GH_TOKEN -or -not $env:GITHUB_API_URL)
{
    throw 'GITHUB_REPOSITORY, GH_TOKEN and GITHUB_API_URL are required.'
}
$headers = @{ Authorization = "Bearer $env:GH_TOKEN"; Accept = 'application/vnd.github+json' }
$api = "$env:GITHUB_API_URL/repos/$Repository"
$page = 1
do
{
    $pulls = @(Invoke-RestMethod -Uri "$api/pulls?state=open&base=main&per_page=100&page=$page" -Headers $headers | ForEach-Object { $_ })
    foreach ($pr in $pulls)
    {
        if ($pr.head.ref -cne 'release-please--branches--main' -or $pr.head.repo.full_name -cne $Repository)
        {
            continue
        }
        $isStable = 'stable-promotion' -in $pr.labels.name
        if ($isStable -ne ($Channel -eq 'stable') -or 'autorelease: pending' -notin $pr.labels.name)
        {
            throw 'Prepared release PR labels do not match the requested channel.'
        }
        $file = Invoke-RestMethod -Uri "$api/contents/.release-please-manifest.json?ref=$($pr.head.sha)" -Headers $headers
        if ($file.encoding -ne 'base64') { throw 'Expected a base64 release manifest.' }
        $preparedVersion = ([Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($file.content)) | ConvertFrom-Json).'.'
        $pattern = if ($Channel -eq 'beta') { '^\d+\.\d+\.\d+-beta[0-9]{3,}$' } else { '^\d+\.\d+\.\d+$' }
        if ($preparedVersion -cnotmatch $pattern -or ($Version -and $preparedVersion -cne $Version))
        {
            throw "Prepared version '$preparedVersion' does not match channel '$Channel' or requested version '$Version'."
        }
        $comparison = Invoke-RestMethod -Uri "$api/compare/$Sha...$($pr.head.sha)" -Headers $headers
        if ($comparison.merge_base_commit.sha -cne $Sha)
        {
            throw 'The release PR does not include the dispatched commit; refusing to record a successful preparation.'
        }
        $body = $pr.body -replace '(?m)\r?\n?<!-- release-preparation:[^\r\n]* -->', ''
        $payload = @{ body = "$($body.TrimEnd())`n`n<!-- release-preparation:$Channel`:$Sha -->" } | ConvertTo-Json
        Invoke-RestMethod -Method Patch -Uri "$api/pulls/$($pr.number)" -Headers $headers -ContentType 'application/json' `
            -Body ([Text.Encoding]::UTF8.GetBytes($payload)) | Out-Null
        return
    }
    $page++
} while ($pulls.Count -eq 100)
Write-Host 'No release PR was created; there is no preparation to record.'
