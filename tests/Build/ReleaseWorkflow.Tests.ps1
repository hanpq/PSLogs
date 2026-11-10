BeforeAll {
    $projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
    $stable = Get-Content (Join-Path $projectRoot '.github\workflows\release-please.yml') -Raw
    $beta = Get-Content (Join-Path $projectRoot '.github\workflows\beta.yml') -Raw
    $publish = Get-Content (Join-Path $projectRoot '.github\workflows\release.yml') -Raw
}

Describe 'Stable-only Release Please with independent beta previews' {
    It 'uses normal Release Please on main pushes and manual dispatch' {
        $stable | Should -Match '(?s)push:\s+branches:\s+- main.*workflow_dispatch:'
        $stable | Should -Match "if: github.ref == 'refs/heads/main'"
        $stable | Should -Match 'googleapis/release-please-action@v4'
        $stable | Should -Not -Match 'skip-github-release|skip-github-pull-request|pull_request:|scripts/'
        $config = Get-Content (Join-Path $projectRoot 'release-please-config.json') -Raw | ConvertFrom-Json
        $config.packages.'.'.prerelease | Should -BeFalse
        $config.packages.'.'.versioning | Should -BeNullOrEmpty
        Test-Path (Join-Path $projectRoot 'release-please-stable-config.json') | Should -BeFalse
    }

    It 'only dispatches betas from main and refreshes the same stable candidate without releasing it' {
        $beta | Should -Match '(?m)^  workflow_dispatch:'
        $beta | Should -Not -Match '(?m)^  (push|pull_request):'
        $beta | Should -Match "if: github.ref == 'refs/heads/main'"
        $beta | Should -Match '(?s)fetch-depth: 0\s+persist-credentials: false'
        $beta | Should -Match '(?s)googleapis/release-please-action@v4.*config-file: release-please-config.json.*skip-github-release: true.*scripts/New-BetaRelease.ps1'
        $beta | Should -Not -Match 'release-as:|stable-promotion|GALLERYAPITOKEN'
    }

    It 'serializes beta allocation and stable preparation with the same concurrency group' {
        foreach ($workflow in @($stable, $beta)) {
            $workflow | Should -Match '(?m)^permissions: \{\}'
            $workflow | Should -Match 'group: release-please-main'
            $workflow | Should -Match 'cancel-in-progress: false'
            $workflow | Should -Match 'token: \$\{\{ secrets.RELEASE_PLEASE_TOKEN \}\}'
        }
    }

    It 'builds and packages the event version instead of the stable baseline' {
        $publish | Should -Match '(?s)release:\s+types:\s+- published'
        $publish | Should -Match 'build.ps1 -Task Test -TestSuite Module -Version \$env:MODULE_VERSION'
        $publish | Should -Match 'build.ps1 -Task Package -Version \$env:MODULE_VERSION'
        ([regex]::Matches($publish, 'scripts/Assert-ReleaseMetadata.ps1')).Count | Should -Be 2
        $publish | Should -Match "if: github.event.release.prerelease == false"
    }

    It 'rejects prerelease metadata on stable release PRs before merging' {
        $ci = Get-Content (Join-Path $projectRoot '.github\workflows\ci.yml') -Raw
        $ci | Should -Match 'Assert-ReleaseMetadata.ps1 -Tag "v\$\(\$project.Version\)" -IsPrerelease \$false'
    }

    It 'exports the beta workflow, allocator and tests but none of the removed promotion machinery' {
        $kit = Import-PowerShellDataFile (Join-Path $projectRoot 'pipeline-migration-kit\kit-files.psd1')
        $kit.Copy | Should -Contain '.github/workflows/beta.yml'
        $kit.Copy | Should -Contain 'scripts/New-BetaRelease.ps1'
        $kit.Copy | Should -Contain 'tests/Build/BetaRelease.Tests.ps1'
        foreach ($path in $kit.Copy) {
            Test-Path (Join-Path $projectRoot $path) | Should -BeTrue
        }
        foreach ($path in $kit.Remove) {
            Test-Path (Join-Path $projectRoot $path) | Should -BeFalse
        }
        "$($kit.Copy)" | Should -Not -Match 'StablePromotion|StableReleaseNotes|ReleasePreparation|ReleaseChangelog|ReleasePullRequest|release-please-stable-config'
    }
}
