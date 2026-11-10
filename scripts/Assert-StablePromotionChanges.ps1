[CmdletBinding()]
param
(
    [Parameter(Mandatory)]
    [string]$BetaRef,

    [string]$HeadRef = 'HEAD',
    [string]$ProjectRoot = (Split-Path -Parent $PSScriptRoot)
)

$ErrorActionPreference = 'Stop'
& git -C $ProjectRoot merge-base --is-ancestor $BetaRef $HeadRef
if ($LASTEXITCODE -ne 0)
{
    throw "The published beta '$BetaRef' must be an ancestor of '$HeadRef'."
}
$paths = @(& git -C $ProjectRoot diff --name-only --no-renames $BetaRef $HeadRef --)
if ($LASTEXITCODE -ne 0) { throw 'Could not compare main with the published beta.' }
$blocked = @($paths | Where-Object { $_ -cne 'CHANGELOG.md' -and $_ -cnotlike 'docs/*' })
if ($blocked.Count)
{
    throw "Changes after the published beta affect release inputs: $($blocked -join ', '). Only CHANGELOG.md and docs/** are allowed. Publish a new beta first."
}
