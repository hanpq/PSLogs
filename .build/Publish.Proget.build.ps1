<#
    .SYNOPSIS
        Tasks for releasing modules.

    .PARAMETER OutputDirectory
        The base directory of all output. Defaults to folder 'output' relative to
        the $BuildRoot.

    .PARAMETER BuiltModuleSubdirectory
        The parent path of the module to be built.

    .PARAMETER VersionedOutputDirectory
        If the module should be built using a version folder, e.g. ./MyModule/1.0.0.
        Defaults to $true.

    .PARAMETER ChangelogPath
        The path to and the name of the changelog file. Defaults to 'CHANGELOG.md'.

    .PARAMETER ReleaseNotesPath
        The path to and the name of the release notes file. Defaults to 'ReleaseNotes.md'.

    .PARAMETER ProjectName
        The project name.

    .PARAMETER ModuleVersion
        The module version that was built.

    .PARAMETER ProgetApiToken
        The module version that was built.

    .PARAMETER NuGetPublishSource
        The source to publish nuget packages. Defaults to https://www.powershellgallery.com.

    .PARAMETER PSModuleFeed
        The name of the feed (repository) that is passed to command Publish-Module.
        Defaults to 'PSGallery'.

    .PARAMETER SkipPublish
        If publishing should be skipped. Defaults to $false.

    .PARAMETER PublishModuleWhatIf
        If the publish command will be run with '-WhatIf' to show what will happen
        during publishing. Defaults to $false.
#>

param
(
    [Parameter()]
    [string]
    $OutputDirectory = (property OutputDirectory (Join-Path $BuildRoot 'output')),

    [Parameter()]
    [System.String]
    $BuiltModuleSubdirectory = (property BuiltModuleSubdirectory ''),

    [Parameter()]
    [System.Management.Automation.SwitchParameter]
    $VersionedOutputDirectory = (property VersionedOutputDirectory $true),

    [Parameter()]
    $ChangelogPath = (property ChangelogPath 'CHANGELOG.md'),

    [Parameter()]
    $ReleaseNotesPath = (property ReleaseNotesPath (Join-Path $OutputDirectory 'ReleaseNotes.md')),

    [Parameter()]
    [string]
    $ProjectName = (property ProjectName ''),

    [Parameter()]
    [System.String]
    $ModuleVersion = (property ModuleVersion ''),

    [Parameter()]
    [string]
    $PSTOOLS_APITOKEN = (property PSTOOLS_APITOKEN ''),

    [Parameter()]
    [string]
    $PSTOOLS_SOURCE = (property PSTOOLS_SOURCE ''),

    [Parameter()]
    [string]
    $PSTOOLS_USER = (property PSTOOLS_USER ''),

    [Parameter()]
    [string]
    $PSTOOLS_PASS = (property PSTOOLS_PASS '')
)

Task publish_module_to_proget -if ($PSTOOLS_APITOKEN) {
    # This task fails when publishing a non-preview version. The reason is that Publish-PSResource
    # does not allow the manifest attribute PreRelease = ''. It will fail with a strange error
    # The required element version is missing in manifest.
    # The module ModuleBuilder that is responsible for generating the module output requires that
    # the attribute PreRelease is defined as a empty string in the source module manifest regardless
    # of weather it will be populated or not. PowershellGet v2 does not care if PreRelease is defined
    # as an empty string when publishing a non-prerelease version however PowershellGet v3 does not
    # allow it. And PowershellGet v3 is required when publishing to proget.
    # Proposed solution is to remove the empty prerelease attribute in the manifest before publishing
    # to proget.

    . Set-SamplerTaskVariable

    # Remove empty Prerelease property, see note above
    $UpdatedManifest = Get-Content $BuiltModuleManifest | Where-Object { $_ -notlike "*Prerelease*= ''" }
    $UpdatedManifest | Set-Content $BuiltModuleManifest
    Write-Build DarkGray 'Removed empty Prerelease property if present'

    Import-Module -Name 'ModuleBuilder' -ErrorAction Stop
    Write-Build DarkGray 'Imported module ModuleBuilder'

    Write-Build DarkGray "`nAbout to publish '$BuiltModuleBase'."

    $RepoGuid = (New-Guid).Guid
    Register-PSResourceRepository -Name $RepoGuid -Uri $PSTOOLS_SOURCE -Trusted
    Set-PSResourceRepository -Name $RepoGuid -ApiVersion nugetServer
    Write-Build DarkGray 'Registered ResourceRepository'

    try
    {
        Write-Build DarkGray 'Trying to publish module to pstools...'
        Publish-PSResource -ApiKey $PSTOOLS_APITOKEN -Path $BuiltModuleBase -Repository $RepoGuid -ErrorAction Stop -SkipDependenciesCheck
        Write-Build Green 'Successfully published module to ProGet'
    }
    catch
    {
        if ($_.Exception.message -like '*is already available in the repository*')
        {
            Write-Build Yellow 'This module version is already published to ProGet'
        }
        elseif ($_.Exception.message -like '*The required element*version*is missing*')
        {
            Write-Build Red 'Failed to publish module because element version is missing from the manifest'
        }
        else
        {
            throw $_
        }
    }
    finally
    {
        Unregister-PSResourceRepository -Name $RepoGuid -Confirm:$false
    }
}
