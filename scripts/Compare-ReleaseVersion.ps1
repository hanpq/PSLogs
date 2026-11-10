[CmdletBinding()]
param
(
    [Parameter(Mandatory)]
    [string]$Left,

    [Parameter(Mandatory)]
    [string]$Right
)

$ErrorActionPreference = 'Stop'
foreach ($version in @($Left, $Right))
{
    if ($version -cnotmatch '^(?:0|[1-9][0-9]*)\.(?:0|[1-9][0-9]*)\.(?:0|[1-9][0-9]*)(?:-beta[0-9]{3,})?$')
    {
        throw "Invalid release version '$version'. Expected Major.Minor.Patch with optional -betaNNN."
    }
}
$comparison = ([version]($Left -split '-')[0]).CompareTo([version]($Right -split '-')[0])
if ($comparison -ne 0) { return $comparison }
if ($Left -notmatch '-' -and $Right -notmatch '-') { return 0 }
if ($Left -notmatch '-') { return 1 }
if ($Right -notmatch '-') { return -1 }
([bigint]($Left -replace '^.*-beta', '')).CompareTo([bigint]($Right -replace '^.*-beta', ''))
