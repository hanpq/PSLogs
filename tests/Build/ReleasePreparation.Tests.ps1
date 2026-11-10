BeforeAll {
    $scripts = Join-Path $PSScriptRoot '..\..\scripts'
    function git {
        param([Parameter(ValueFromRemainingArguments)][string[]]$Arguments)
        throw "Unexpected Git arguments: $Arguments"
    }
}

Describe 'Release version validation' {
    It 'accepts valid versions and normalizes only explicit beta dispatch inputs' -ForEach @(
        @{ Channel = 'beta'; Version = '3.3.7-beta001'; Latest = '3.3.6'; InputVersion = $false; Expected = '3.3.7-beta001' }
        @{ Channel = 'beta'; Version = '3.3.7'; Latest = '3.3.6'; InputVersion = $true; Expected = '3.3.7-beta001' }
        @{ Channel = 'beta'; Version = '3.3.7-beta010'; Latest = '3.3.7-beta009'; InputVersion = $false; Expected = '3.3.7-beta010' }
        @{ Channel = 'beta'; Version = '3.3.7-beta1000'; Latest = '3.3.7-beta999'; InputVersion = $false; Expected = '3.3.7-beta1000' }
        @{ Channel = 'stable'; Version = '3.3.7'; Latest = '3.3.7-beta002'; InputVersion = $false; Expected = '3.3.7' }
    ) {
        & "$scripts\Assert-ReleaseVersion.ps1" -Channel $Channel -Version $Version -LatestVersion $Latest -DispatchInput:$InputVersion |
            Should -BeExactly $Expected
    }

    It 'rejects channel mismatches and invalid or non-increasing versions' -ForEach @(
        @{ Channel = 'beta'; Version = '3.3.7'; Latest = '3.3.6'; Error = '*3.3.7-betaNNN*' }
        @{ Channel = 'stable'; Version = '3.3.7-beta001'; Latest = '3.3.6'; Error = '*without a prerelease suffix*' }
        @{ Channel = 'beta'; Version = '3.3.7-beta001'; Latest = '3.3.7-beta001'; Error = '*greater than latest tag*' }
        @{ Channel = 'beta'; Version = '3.3.7-beta001'; Latest = '3.3.7'; Error = '*greater than latest tag*' }
        @{ Channel = 'stable'; Version = '3.3.6'; Latest = '3.3.7-beta001'; Error = '*greater than latest tag*' }
        @{ Channel = 'beta'; Version = '3.3.7-rc001'; Latest = '3.3.6'; Error = '*Invalid release version*' }
        @{ Channel = 'beta'; Version = '03.3.7-beta001'; Latest = '3.3.6'; Error = '*Invalid release version*' }
        @{ Channel = 'beta'; Version = '3.3.7-beta.1'; Latest = '3.3.6'; Error = '*Invalid release version*' }
    ) {
        { & "$scripts\Assert-ReleaseVersion.ps1" -Channel $Channel -Version $Version -LatestVersion $Latest } |
            Should -Throw $Error
    }
}

Describe 'Release preparation preflight and duplicate recording' {
    BeforeAll {
        $savedToken = $env:GH_TOKEN
        $savedApi = $env:GITHUB_API_URL
        $env:GH_TOKEN = 'test-token'
        $env:GITHUB_API_URL = 'https://api.github.test'
    }
    AfterAll {
        $env:GH_TOKEN = $savedToken
        $env:GITHUB_API_URL = $savedApi
    }
    BeforeEach {
        $state = @{
            Sha = '0123456789abcdef0123456789abcdef01234567'
            Tags = @('v3.3.6-beta001', 'v3.3.6')
            Messages = @('fix: change')
            Pending = @()
            Pulls = @()
            PatchBody = $null
            Merged = $true
            Release = @{ tag_name = 'v3.3.6'; prerelease = $false; draft = $false; published_at = '2026-10-30' }
            PreparedVersion = '3.3.7-beta001'
        }
        Mock git {
            param($Arguments)
            $global:LASTEXITCODE = 0
            if ($Arguments -contains 'rev-parse') { return $state.Sha }
            if ($Arguments -contains 'tag') { return $state.Tags }
            if ($Arguments -contains 'log') { return $state.Messages }
            throw "Unexpected Git command: $Arguments"
        }
        Mock Invoke-RestMethod {
            param($Uri, $Method, $Body)
            if ($Method -eq 'Patch') {
                $state.PatchBody = [Text.Encoding]::UTF8.GetString([byte[]]$Body) | ConvertFrom-Json
                return
            }
            if ($Uri -like '*/issues?*') { return , @($state.Pending) }
            if ($Uri -like '*/pulls?state=open*') { return , @($state.Pulls) }
            if ($Uri -like '*/pulls/42') { return @{ merged_at = $(if ($state.Merged) { '2026-10-30' }); base = @{ ref = 'main' } } }
            if ($Uri -like '*/compare/*') { return @{ merge_base_commit = @{ sha = $state.Sha } } }
            if ($Uri -like '*/releases/tags/*') { return $state.Release }
            if ($Uri -like '*/contents/*') {
                return @{
                    encoding = 'base64'
                    content = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes((@{ '.' = $state.PreparedVersion } | ConvertTo-Json)))
                }
            }
            throw "Unexpected API request: $Method $Uri"
        }
    }

    It 'normalizes a bare beta input without changing history' {
        $result = & "$scripts\Get-ReleasePreparation.ps1" -Channel beta -Version '3.3.7' -Repository example/module
        $result.Skip | Should -BeFalse
        $result.Version | Should -BeExactly '3.3.7-beta001'
        Should -Invoke git -Times 1 -Exactly -ParameterFilter { $Arguments -contains 'v3.3.6..HEAD' }
        Should -Invoke Invoke-RestMethod -Times 0 -Exactly -ParameterFilter { $Method }
    }

    It 'checks all unreleased footers rather than only the newest commit' {
        $state.Messages = @("fix: latest`n`nRelease-As: 3.3.7-beta001", "fix: older`n`nRelease-As: 3.3.7")
        { & "$scripts\Get-ReleasePreparation.ps1" -Channel beta -Repository example/module } | Should -Throw '*3.3.7-betaNNN*'
    }

    It 'rejects a footer conflicting with the dispatch input' {
        $state.Messages = @("fix: change`n`nRelease-As: 3.3.8-beta001")
        { & "$scripts\Get-ReleasePreparation.ps1" -Channel beta -Version '3.3.7' -Repository example/module } | Should -Throw '*conflicts with dispatch*'
    }

    It 'names the stuck merged PR and exact safe remediation before running git' {
        $state.Pending = @(@{ number = 42; pull_request = @{ url = 'pr' } })
        { & "$scripts\Get-ReleasePreparation.ps1" -Channel beta -Repository example/module } |
            Should -Throw "*PR #42*gh pr edit 42 --repo example/module --remove-label 'autorelease: pending'*"
        Should -Invoke git -Times 0 -Exactly
    }

    It 'ignores closed but unmerged PRs with a pending label' {
        $state.Pending = @(@{ number = 42; pull_request = @{ url = 'pr' } })
        $state.Merged = $false
        (& "$scripts\Get-ReleasePreparation.ps1" -Channel beta -Repository example/module).Skip | Should -BeFalse
    }

    It 'skips a previously prepared SHA without changing the existing PR' {
        $state.Pulls = @(@{
            number = 42; html_url = 'https://github.test/example/module/pull/42'
            body = "<!-- release-preparation:beta:$($state.Sha) -->"
            labels = @(@{ name = 'autorelease: pending' })
            head = @{ ref = 'release-please--branches--main'; repo = @{ full_name = 'example/module' } }
        })
        (& "$scripts\Get-ReleasePreparation.ps1" -Channel beta -Repository example/module).Skip | Should -BeTrue
        Should -Invoke Invoke-RestMethod -Times 0 -Exactly -ParameterFilter { $Method }
    }

    It 'does not skip a different commit, channel or repository' -ForEach @(
        @{ Different = 'sha' }, @{ Different = 'channel' }, @{ Different = 'repo' }
    ) {
        $marker = "<!-- release-preparation:beta:$($state.Sha) -->"
        $repo = 'example/module'
        switch ($Different) {
            sha { $marker = '<!-- release-preparation:beta:other-sha -->' }
            channel { $marker = "<!-- release-preparation:stable:$($state.Sha) -->" }
            repo { $repo = 'other/module' }
        }
        $state.Pulls = @(@{ body = $marker; head = @{ ref = 'release-please--branches--main'; repo = @{ full_name = $repo } } })
        (& "$scripts\Get-ReleasePreparation.ps1" -Channel beta -Repository example/module).Skip | Should -BeFalse
    }

    It 'records a successful preparation and preserves release-please metadata' {
        $state.Pulls = @(@{
            number = 42; body = ":robot: release`n---`nnotes`n---`nmetadata"
            labels = @(@{ name = 'autorelease: pending' })
            head = @{ ref = 'release-please--branches--main'; sha = 'pr-head'; repo = @{ full_name = 'example/module' } }
        })
        & "$scripts\Set-ReleasePreparation.ps1" -Channel beta -Sha $state.Sha -Repository example/module
        $state.PatchBody.body | Should -Match "^:robot: release`n---`nnotes`n---`nmetadata"
        $state.PatchBody.body | Should -Match "<!-- release-preparation:beta:$($state.Sha) -->"
    }

    It 'does not record a PR that does not contain the dispatched commit' {
        $state.Pulls = @(@{
            number = 42; body = 'notes'; labels = @(@{ name = 'autorelease: pending' })
            head = @{ ref = 'release-please--branches--main'; sha = 'pr-head'; repo = @{ full_name = 'example/module' } }
        })
        Mock Invoke-RestMethod { return @{ merge_base_commit = @{ sha = 'old-sha' } } } -ParameterFilter { $Uri -like '*/compare/*' }
        { & "$scripts\Set-ReleasePreparation.ps1" -Channel beta -Sha $state.Sha -Repository example/module } |
            Should -Throw '*does not include the dispatched commit*'
        $state.PatchBody | Should -BeNullOrEmpty
    }

    It 'validates the input even when the same commit was already prepared' {
        $state.Pulls = @(@{
            number = 42; body = "<!-- release-preparation:beta:$($state.Sha) -->"
            head = @{ ref = 'release-please--branches--main'; repo = @{ full_name = 'example/module' } }
        })
        { & "$scripts\Get-ReleasePreparation.ps1" -Channel beta -Version '3.3.5' -Repository example/module } |
            Should -Throw '*must be greater*'
    }

    It 'does not record a version override unless the action produced exactly that version' {
        $state.Pulls = @(@{
            number = 42; body = 'notes'; labels = @(@{ name = 'autorelease: pending' })
            head = @{ ref = 'release-please--branches--main'; sha = 'pr-head'; repo = @{ full_name = 'example/module' } }
        })
        { & "$scripts\Set-ReleasePreparation.ps1" -Channel beta -Sha $state.Sha -Version '3.3.8-beta001' -Repository example/module } |
            Should -Throw "*Prepared version '3.3.7-beta001'*"
        $state.PatchBody | Should -BeNullOrEmpty
    }

    It 'fails closed on an unpublished latest tag' {
        $state.Release.draft = $true
        { & "$scripts\Get-ReleasePreparation.ps1" -Channel beta -Repository example/module } |
            Should -Throw '*matching published GitHub release*'
    }

    It 'orders beta counters numerically even when they exceed three digits' {
        $state.Tags = @('v3.3.6-beta999', 'v3.3.6-beta1000')
        $state.Release.tag_name = 'v3.3.6-beta1000'
        $state.Release.prerelease = $true
        (& "$scripts\Get-ReleasePreparation.ps1" -Channel beta -Version '3.3.6-beta1001' -Repository example/module).Version |
            Should -BeExactly '3.3.6-beta1001'
        Should -Invoke git -Times 1 -Exactly -ParameterFilter { $Arguments -contains 'v3.3.6-beta1000..HEAD' }
    }

    It 'finds stuck merged PRs on later pages' {
        Mock Invoke-RestMethod {
            param($Uri)
            if ($Uri -like '*page=1') { return , @(1..100 | ForEach-Object { @{ number = $_ } }) }
            return , @(@{ number = 42; pull_request = @{ url = 'pr' } })
        } -ParameterFilter { $Uri -like '*/issues?state=closed*' }
        { & "$scripts\Get-ReleasePreparation.ps1" -Channel beta -Repository example/module } |
            Should -Throw '*PR #42*'
    }

    It 'finds duplicate preparations on later pages without making writes' {
        Mock Invoke-RestMethod {
            param($Uri)
            if ($Uri -like '*page=1') { return , @(1..100 | ForEach-Object { @{ number = $_ } }) }
            return , @(@{
                number = 42; html_url = 'https://github.test/example/module/pull/42'
                body = "<!-- release-preparation:beta:$($state.Sha) -->"
                labels = @(@{ name = 'autorelease: pending' })
                head = @{ ref = 'release-please--branches--main'; repo = @{ full_name = 'example/module' } }
            })
        } -ParameterFilter { $Uri -like '*/pulls?state=open*' }
        (& "$scripts\Get-ReleasePreparation.ps1" -Channel beta -Repository example/module).Skip | Should -BeTrue
        Should -Invoke Invoke-RestMethod -Times 0 -Exactly -ParameterFilter { $Method }
    }

    It 'does not silently skip a stable promotion whose label was removed' {
        $state.Pulls = @(@{
            number = 42; body = "<!-- release-preparation:stable:$($state.Sha) -->"
            labels = @(@{ name = 'autorelease: pending' })
            head = @{ ref = 'release-please--branches--main'; repo = @{ full_name = 'example/module' } }
        })
        { & "$scripts\Get-ReleasePreparation.ps1" -Channel stable -Repository example/module } |
            Should -Throw '*#42*missing or inconsistent release labels*'
    }

    It 'accepts only the promoted numeric version as a stable dispatch override' {
        $fixture = Join-Path $TestDrive 'stable-input'
        New-Item -ItemType Directory -Path (Join-Path $fixture 'source') -Force | Out-Null
        Set-Content (Join-Path $fixture 'source\ExampleModule.psd1') "@{ ModuleVersion = '1.0.0' }"
        Set-Content (Join-Path $fixture '.release-please-manifest.json') '{".":"3.3.7-beta001"}'
        $state.Tags = @('v3.3.7-beta001')
        $state.Release.tag_name = 'v3.3.7-beta001'
        $state.Release.prerelease = $true
        (& "$scripts\Get-ReleasePreparation.ps1" -Channel stable -Version '3.3.7' -Repository example/module -ProjectRoot $fixture).Version |
            Should -BeExactly '3.3.7'
        { & "$scripts\Get-ReleasePreparation.ps1" -Channel stable -Version '3.3.8' -Repository example/module -ProjectRoot $fixture } |
            Should -Throw "*can only request*'3.3.7'*"
    }
}
