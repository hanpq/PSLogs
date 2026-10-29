BeforeAll {
    $scriptUnderTest = Join-Path $PSScriptRoot '..\..\scripts\Get-ReleaseChannel.ps1'
}

Describe 'Release channel selection' {
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
        $apiState = @{
            OpenPullRequests = @()
            MergedPullRequests = @()
            Requests = [System.Collections.Generic.List[string]]::new()
        }
        Mock Invoke-RestMethod {
            param($Uri)
            $apiState.Requests.Add($Uri)
            if ($Uri -like '*/commits/*/pulls')
            {
                return $apiState.MergedPullRequests
            }
            if ($Uri -like '*/pulls?state=open*')
            {
                return $apiState.OpenPullRequests
            }
            throw "Unexpected API URI: $Uri"
        }
    }

    It 'keeps beta as the default configuration and checks in a separate stable configuration' {
        $projectRoot = Resolve-Path (Join-Path $PSScriptRoot '..\..')
        $beta = Get-Content -LiteralPath (Join-Path $projectRoot 'release-please-config.json') -Raw | ConvertFrom-Json
        $stable = Get-Content -LiteralPath (Join-Path $projectRoot 'release-please-stable-config.json') -Raw | ConvertFrom-Json

        $beta.packages.'.'.prerelease | Should -BeTrue
        $stable.packages.'.'.prerelease | Should -BeFalse
        $beta.packages.'.'.versioning | Should -Be 'prerelease'
        $stable.packages.'.'.versioning | Should -Be 'prerelease'
    }

    It 'uses the selected stable channel without querying the API' {
        $result = & $scriptUnderTest -EventName workflow_dispatch -DispatchChannel stable -RefName main -Repository 'example/module'

        $result.Channel | Should -Be 'stable'
        $result.RunAction | Should -BeFalse
        $apiState.Requests.Count | Should -Be 0
    }

    It 'protects an open stable promotion from beta runs' {
        $apiState.OpenPullRequests = @(@{ labels = @(@{ name = 'stable-promotion' }) })

        $result = & $scriptUnderTest -EventName workflow_dispatch -DispatchChannel beta -RefName main -Repository 'example/module'

        $result.Channel | Should -Be 'beta'
        $result.Skip | Should -BeTrue
        $result.RunAction | Should -BeFalse
    }

    It 'uses stable metadata for the push that merged a stable promotion' {
        $apiState.MergedPullRequests = @(
            @{
                state = 'closed'
                merged_at = '2026-10-29T14:00:00Z'
                merge_commit_sha = 'stable-merge'
                labels = @(@{ name = 'stable-promotion' })
            }
        )

        $result = & $scriptUnderTest -EventName push -CommitSha 'stable-merge' -RefName main -Repository 'example/module'

        $result.Channel | Should -Be 'stable'
        $result.Skip | Should -BeFalse
        $result.RunAction | Should -BeTrue
        $apiState.Requests.Count | Should -Be 1
    }

    It 'keeps normal pushes on beta and allows Release Please to run' {
        $apiState.MergedPullRequests = @(
            @{
                state = 'closed'
                merged_at = '2026-10-29T14:00:00Z'
                merge_commit_sha = 'other-merge'
                labels = @(@{ name = 'autorelease: pending' })
            }
        )

        $result = & $scriptUnderTest -EventName push -CommitSha 'feature-merge' -RefName main -Repository 'example/module'

        $result.Channel | Should -Be 'beta'
        $result.Skip | Should -BeFalse
        $result.RunAction | Should -BeTrue
    }

    It 'refuses release workflows dispatched from a non-main branch' {
        { & $scriptUnderTest -EventName workflow_dispatch -DispatchChannel beta -RefName feature `
            -Repository 'example/module' } |
            Should -Throw '*must run from main*'
        $apiState.Requests.Count | Should -Be 0
    }
}
