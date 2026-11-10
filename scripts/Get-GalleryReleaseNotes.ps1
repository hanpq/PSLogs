[CmdletBinding(DefaultParameterSetName = 'Notes')]
param
(
    [Parameter(Mandatory, ParameterSetName = 'Notes')]
    [AllowEmptyString()]
    [string]$Notes,

    [Parameter(Mandatory)]
    [string]$Changelog,

    [Parameter(Mandatory, ParameterSetName = 'Version')]
    [string]$Version,

    [Parameter(ParameterSetName = 'Version')]
    [switch]$UseVersionSection
)

$ErrorActionPreference = 'Stop'
if ($PSCmdlet.ParameterSetName -eq 'Version')
{
    $sectionVersion = if ($UseVersionSection) { $Version } else { 'Unreleased' }
    $pattern = '(?ms)^## \[' + [regex]::Escape($sectionVersion) + '\][^\r\n]*\r?\n(?<notes>.*?)(?=^## \[|\z)'
    $section = [regex]::Match($Changelog, $pattern)
    if (-not $section.Success)
    {
        throw "Could not find release notes section '$sectionVersion' for version '$Version' in CHANGELOG.md."
    }
    $Notes = $section.Groups['notes'].Value
}
$notes = $Notes.Trim()
$maxReleaseNotesLength = 10000
if ($notes.Length -gt $maxReleaseNotesLength)
{
    $compare = [regex]::Match($Changelog, 'https://[^/\s)]+/[^/\s)]+/[^/\s)]+/compare/')
    if (-not $compare.Success)
    {
        throw 'Cannot find the repository changelog URL for oversized release notes.'
    }
    $changelogUrl = $compare.Value -replace '/compare/$', '/blob/main/CHANGELOG.md'
    $truncationNotice = "`n`nRelease notes are truncated. See the full changelog: $changelogUrl"
    $cut = $notes.LastIndexOf("`n", $maxReleaseNotesLength - $truncationNotice.Length)
    if ($cut -le 0)
    {
        throw 'Release notes cannot be shortened to fit the PSGallery limit while preserving whole lines.'
    }
    $notes = $notes.Substring(0, $cut).TrimEnd() + $truncationNotice
    Write-Host "Release notes truncated to $($notes.Length) characters for PSGallery." -ForegroundColor Yellow
}
$notes
