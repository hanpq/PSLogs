@{
    # Generic pipeline files. Copy them over the target repository unchanged.
    Copy  = @(
        'build.ps1'
        'RequiredModules.psd1'
        'codecov.yml'
        'release-please-config.json'
        'release-please-stable-config.json'
        'scripts/Assert-ReleaseMetadata.ps1'
        'scripts/Assert-ReleasePullRequest.ps1'
        'scripts/Get-BuildProject.ps1'
        'scripts/Get-StableReleaseNotes.ps1'
        'scripts/New-StablePromotion.ps1'
        'scripts/Update-Docs.ps1'
        'tests/Build/Build.Tests.ps1'
        'tests/Build/ReleaseNotes.Tests.ps1'
        'tests/Build/ReleasePullRequest.Tests.ps1'
        'tests/Build/ReleaseWorkflow.Tests.ps1'
        'tests/Build/StablePromotion.Tests.ps1'
        '.github/workflows/ci.yml'
        '.github/workflows/release.yml'
        '.github/workflows/release-please.yml'
        '.github/copilot-instructions.md'
        '.github/PULL_REQUEST_TEMPLATE.md'
        '.vscode/tasks.json'
    )

    # PSLogs versions of files that contain module-specific content. Use them as
    # the reference and adapt them as described in AI-MIGRATION.md.
    Adapt = @(
        'BUILDING.md'
        'ModuleDebug.ps1'
        'tests/QA/module.tests.ps1'
        '.vscode/launch.json'
        '.vscode/settings.json'
        '.github/CONTRIBUTING.md'
        '.gitignore'
        '.markdownlint.json'
    )
}
