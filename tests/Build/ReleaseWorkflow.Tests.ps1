BeforeAll {
    $projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
    $stable = Get-Content (Join-Path $projectRoot '.github\workflows\release-please.yml') -Raw
    $beta = Get-Content (Join-Path $projectRoot '.github\workflows\beta.yml') -Raw
    $publish = Get-Content (Join-Path $projectRoot '.github\workflows\release.yml') -Raw
}

Describe 'Stable-only Release Please with independent beta previews' {
    It 'prepares stable PRs only on explicit main dispatch and never publishes during preparation' {
        $stable | Should -Match '(?m)^  workflow_dispatch:'
        $stable | Should -Not -Match '(?m)^  (push|pull_request_target):'
        $stable | Should -Match "github.event_name == 'workflow_dispatch' && github.ref == 'refs/heads/main'"
        $stable | Should -Match 'googleapis/release-please-action@v4'
        $stable | Should -Match 'RELEASE_VERSION: \$\{\{ inputs.version \}\}'
        $stable | Should -Match 'node scripts/release-please/Prepare-StableRelease.cjs'
        $stable | Should -Match '(?s)workflow_dispatch:\s+inputs:\s+version:.*required: false.*type: string'
        $stable | Should -Match "(?s)Finalize merged stable release\s+if: github.event_name == 'pull_request'\s+uses: googleapis/release-please-action@v4"
        $config = Get-Content (Join-Path $projectRoot 'release-please-config.json') -Raw | ConvertFrom-Json
        $config.packages.'.'.prerelease | Should -BeFalse
        $config.packages.'.'.versioning | Should -BeNullOrEmpty
        Test-Path (Join-Path $projectRoot 'release-please-stable-config.json') | Should -BeFalse
    }

    It 'only finalizes a merged pending same-repository release PR without preparing another PR' {
        $stable | Should -Match '(?s)pull_request:\s+types: \[closed\]\s+branches:\s+- main'
        $stable | Should -Match "github.event_name == 'pull_request'"
        $stable | Should -Match 'github.event.pull_request.merged == true'
        $stable | Should -Match 'github.event.pull_request.head.repo.full_name == github.repository'
        $stable | Should -Match "github.event.pull_request.head.ref == 'release-please--branches--main'"
        $stable | Should -Match "contains\(github.event.pull_request.labels.\*.name, 'autorelease: pending'\)"
        $stable | Should -Match 'skip-github-pull-request: true'
    }

    It 'only dispatches betas from main and infers their version without creating a stable PR' {
        $beta | Should -Match '(?m)^  workflow_dispatch:'
        $beta | Should -Not -Match '(?m)^  (push|pull_request):'
        $beta | Should -Match "if: github.ref == 'refs/heads/main'"
        $beta | Should -Match '(?s)fetch-depth: 0\s+persist-credentials: false'
        $beta | Should -Match 'npm ci --prefix scripts/release-please'
        $beta | Should -Match 'node scripts/release-please/Get-BetaVersion.cjs'
        $beta | Should -Match 'GH_TOKEN: \$\{\{ github.token \}\}'
        $beta | Should -Match 'CANDIDATE_VERSION: \$\{\{ steps.candidate.outputs.version \}\}'
        $beta | Should -Match 'scripts/New-BetaRelease.ps1 -CandidateVersion \$env:CANDIDATE_VERSION'
        $beta | Should -Not -Match 'googleapis/release-please-action|release-as:|stable-promotion|GALLERYAPITOKEN'
    }

    It 'serializes beta allocation and stable preparation with the same concurrency group' {
        foreach ($workflow in @($stable, $beta)) {
            $workflow | Should -Match '(?m)^permissions: \{\}'
            $workflow | Should -Match 'group: release-please-main'
            $workflow | Should -Match 'cancel-in-progress: false'
            $workflow | Should -Match '(token|GH_TOKEN): \$\{\{ secrets.RELEASE_PLEASE_TOKEN \}\}'
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
        $ci | Should -Match 'npm test --prefix scripts/release-please'
    }

}
