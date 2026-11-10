[CmdletBinding()]
param
(
    [string]$ProjectRoot = (Split-Path -Parent $PSScriptRoot)
)

$ErrorActionPreference = 'Stop'
$tags = @(& git -C $ProjectRoot tag --merged HEAD --list 'v*')
if ($LASTEXITCODE -ne 0) { throw 'Could not read release tags.' }
$latest = $null
foreach ($tag in $tags)
{
    if ($tag -cmatch '^v(?:0|[1-9][0-9]*)\.(?:0|[1-9][0-9]*)\.(?:0|[1-9][0-9]*)(?:-beta[0-9]{3,})?$' -and
        (-not $latest -or (& "$PSScriptRoot\Compare-ReleaseVersion.ps1" -Left $tag.Substring(1) -Right $latest.Substring(1)) -gt 0))
    {
        $latest = $tag
    }
}
if (-not $latest) { throw 'No reachable release tag was found. Establish a release baseline before preparing a release.' }
$latest
