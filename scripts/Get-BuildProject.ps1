[CmdletBinding()]
param
(
    [Parameter()]
    [string]
    $ProjectRoot
)

if ([string]::IsNullOrWhiteSpace($ProjectRoot))
{
    $ProjectRoot = Split-Path -Parent $PSScriptRoot
}

$manifests = @(Get-ChildItem -LiteralPath (Join-Path $ProjectRoot 'source') -Filter '*.psd1' -File -ErrorAction Stop)
if ($manifests.Count -ne 1)
{
    throw "Expected exactly one module manifest in the source directory; found $($manifests.Count)."
}

$manifest = $manifests[0]
$data = Import-PowerShellDataFile -LiteralPath $manifest.FullName -ErrorAction Stop

[pscustomobject]@{
    Name           = $manifest.BaseName
    Version        = $data.ModuleVersion
    SourceManifest = $manifest.FullName
}
