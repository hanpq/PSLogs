BeforeAll {
    $scriptUnderTest = Join-Path $PSScriptRoot '..\..\scripts\New-StablePromotion.ps1'

    function git
    {
        param(
            [Parameter(ValueFromRemainingArguments)]
            [string[]]$Arguments
        )

        throw "Unexpected unmocked Git command: $Arguments"
    }

    function New-TestHttpException
    {
        param([string]$Message, [System.Net.HttpStatusCode]$StatusCode)

        $exception = [System.Exception]::new($Message)
        $exception | Add-Member -NotePropertyName Response -NotePropertyValue ([pscustomobject]@{
            StatusCode = $StatusCode
        })
        return $exception
    }
}

Describe 'Stable promotion PR creation' {
    BeforeAll {
        $savedToken = $env:GH_TOKEN
        $savedApi = $env:GITHUB_API_URL
        $savedGitExitCode = $global:LASTEXITCODE
        $env:GH_TOKEN = 'test-token'
        $env:GITHUB_API_URL = 'https://api.github.test'
    }

    AfterAll {
        $env:GH_TOKEN = $savedToken
        $env:GITHUB_API_URL = $savedApi
        $global:LASTEXITCODE = $savedGitExitCode
    }

    BeforeEach {
        $fixtureRoot = Join-Path $TestDrive ([guid]::NewGuid().ToString())
        $sourceDirectory = Join-Path $fixtureRoot 'source'
        New-Item -ItemType Directory -Path $sourceDirectory -Force | Out-Null
        Set-Content -LiteralPath (Join-Path $sourceDirectory 'ExampleModule.psd1') -Value "@{ ModuleVersion = '1.0.0' }"
        Set-Content -LiteralPath (Join-Path $fixtureRoot '.release-please-manifest.json') -Value '{".":"2.0.0-beta001"}'
        Set-Content -LiteralPath (Join-Path $fixtureRoot 'CHANGELOG.md') -Value @'
# Changelog

## [2.0.0-beta001](https://github.com/example/module/compare/v1.0.0...v2.0.0-beta001) (2026-10-29)

### Features

* beta feature

## [1.0.0](https://github.com/example/module/compare/v0.9.0...v1.0.0) (2026-10-01)

### Features

* old stable feature
'@
        $gitState = @{
            CheckoutSha = '0123456789abcdef0123456789abcdef01234567'
            BetaSha = '0123456789abcdef0123456789abcdef01234567'
            CommitsAfterBeta = 0
        }
        Mock git {
            param($Arguments)

            if ($Arguments.Count -lt 3 -or $Arguments[0] -cne '-C' -or $Arguments[1] -cne $fixtureRoot)
            {
                throw "Unexpected Git arguments: $Arguments"
            }

            $global:LASTEXITCODE = 0
            switch -Exact ($Arguments[2..($Arguments.Count - 1)] -join ' ')
            {
                'rev-parse --verify refs/tags/v2.0.0-beta001' { return $gitState.BetaSha }
                'rev-list --count v2.0.0-beta001..HEAD' { return $gitState.CommitsAfterBeta }
                'rev-parse v2.0.0-beta001^{commit}' { return $gitState.BetaSha }
                'rev-parse HEAD' { return $gitState.CheckoutSha }
                default { throw "Unexpected Git command: $Arguments" }
            }
        }

        $apiState = @{
            Requests = [System.Collections.Generic.List[object]]::new()
            OpenPullRequests = @()
            Writes = [System.Collections.Generic.List[object]]::new()
            MainSha = $gitState.CheckoutSha
            Release = @{ prerelease = $true; draft = $false; tag_name = 'v2.0.0-beta001'; published_at = '2026-10-29T12:00:00Z' }
            OtherBetas = @()
        }
        Mock Invoke-RestMethod {
            param($Uri, $Method, $Body)
            $apiState.Requests.Add([pscustomobject]@{ Uri = $Uri; Method = $Method; Body = $Body })
            if ($Uri -like '*/releases/tags/*')
            {
                return $apiState.Release
            }
            if ($Uri -like '*/releases?*')
            {
                # The real cmdlet returns JSON arrays as a single object.
                return , (@($apiState.Release) + $apiState.OtherBetas)
            }
            if ($Uri -like '*/pulls?state=open*')
            {
                return , @($apiState.OpenPullRequests)
            }
            if ($Uri -like '*/git/ref/heads/main')
            {
                return @{ object = @{ sha = $apiState.MainSha } }
            }
            if ($Uri -like '*/git/ref/heads/release-please--branches--main')
            {
                if ($Method)
                {
                    throw 'The singular ref endpoint only supports reading.'
                }
                return @{ object = @{ sha = 'old-branch-sha' } }
            }
            if ($Uri -like '*/contents/*')
            {
                return @{ sha = 'file-sha' }
            }
            if ($Uri -like '*/pulls' -and $Method -eq 'Post')
            {
                return @{ number = 42 }
            }
            if ($Uri -like '*/labels/*')
            {
                return @{ name = 'label' }
            }
            if ($Method -in @('Put', 'Patch'))
            {
                $apiState.Writes.Add([pscustomobject]@{ Uri = $Uri; Method = $Method; Body = $Body })
                return
            }
            throw "Unexpected API request: $Method $Uri"
        }
    }

    It 'creates a stable Release Please PR with zero commits after the latest beta' {
        $number = & $scriptUnderTest -Repository 'example/module' -ProjectRoot $fixtureRoot

        $number | Should -Be 42
        $apiState.Requests.Uri | Should -Contain 'https://api.github.test/repos/example/module/git/ref/heads/main'
        $apiState.Requests.Uri | Should -Contain 'https://api.github.test/repos/example/module/pulls'
        $pullRequestBody = [System.Text.Encoding]::UTF8.GetString(
            [byte[]]($apiState.Requests | Where-Object { $_.Uri -like '*/pulls' -and $_.Method -eq 'Post' }).Body
        ) | ConvertFrom-Json
        $pullRequestBody.title | Should -Be 'chore(main): release 2.0.0'
        $pullRequestBody.head | Should -Be 'release-please--branches--main'
        $pullRequestBody.body | Should -Match '## \[2\.0\.0\]'

        $contentWrites = @($apiState.Requests | Where-Object { $_.Uri -like '*/contents/*' -and $_.Method -eq 'Put' })
        $contentWrites.Count | Should -Be 3
        $manifestPayload = [System.Text.Encoding]::UTF8.GetString([byte[]]$contentWrites[0].Body) | ConvertFrom-Json
        [System.Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($manifestPayload.content)) |
            Should -Match '2\.0\.0'
        $versionPayload = [System.Text.Encoding]::UTF8.GetString([byte[]]$contentWrites[1].Body) | ConvertFrom-Json
        [System.Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($versionPayload.content)) |
            Should -Be "2.0.0`n"
        $changelogPayload = [System.Text.Encoding]::UTF8.GetString([byte[]]$contentWrites[2].Body) | ConvertFrom-Json
        $updatedChangelog = [System.Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($changelogPayload.content))
        $updatedChangelog | Should -Match '## \[2\.0\.0\]'
        $updatedChangelog | Should -Match '## \[2\.0\.0-beta001\]'
    }

    It 'creates version.txt without a sha when it is absent from the beta' {
        Mock Invoke-RestMethod {
            throw (New-TestHttpException -Message 'Version file not found' -StatusCode NotFound)
        } -ParameterFilter { -not $Method -and $Uri -like '*/contents/version.txt?*' }

        & $scriptUnderTest -Repository 'example/module' -ProjectRoot $fixtureRoot

        $write = $apiState.Requests | Where-Object { $_.Method -eq 'Put' -and $_.Uri -like '*/contents/version.txt' }
        $payload = [System.Text.Encoding]::UTF8.GetString([byte[]]$write.Body) | ConvertFrom-Json
        $payload.PSObject.Properties.Name | Should -Not -Contain 'sha'
        [System.Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($payload.content)) |
            Should -Be "2.0.0`n"
    }

    It 'rolls up all beta notes before writing the promotion, preserving beta history' {
        $changelogPath = Join-Path $fixtureRoot 'CHANGELOG.md'
        $changelog = Get-Content $changelogPath -Raw
        $olderBeta = @'
## [1.1.0-beta001](https://github.com/example/module/compare/v1.0.0...v1.1.0-beta001) (2026-10-28)

### Bug Fixes

* earlier beta fix

'@
        $changelog = $changelog.Replace('compare/v1.0.0...v2.0.0-beta001', 'compare/v1.1.0-beta001...v2.0.0-beta001')
        $changelog = $changelog.Replace('## [1.0.0]', "$olderBeta`n## [1.0.0]")
        Set-Content $changelogPath $changelog
        & $scriptUnderTest -Repository 'example/module' -ProjectRoot $fixtureRoot
        $write = $apiState.Requests | Where-Object { $_.Method -eq 'Put' -and $_.Uri -like '*/contents/CHANGELOG.md' }
        $payload = [System.Text.Encoding]::UTF8.GetString([byte[]]$write.Body) | ConvertFrom-Json
        $result = [System.Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($payload.content))
        $stableSection = ($result -split '(?m)^## \[2.0.0-beta001\]')[0]
        $stableSection | Should -Match 'earlier beta fix'
        $stableSection | Should -Match 'beta feature'
        $stableSection | Should -Match 'compare/v1.0.0...v2.0.0'
        $result | Should -Match '## \[1.1.0-beta001\]'
        $request = $apiState.Requests | Where-Object { $_.Method -eq 'Post' -and $_.Uri -like '*/pulls' }
        $pr = [System.Text.Encoding]::UTF8.GetString([byte[]]$request.Body) | ConvertFrom-Json
        $pr.body | Should -Match 'earlier beta fix'
    }

    It 'rejects a draft or unpublished beta' -ForEach @(
        @{ Draft = $true; Published = '2026-10-29T12:00:00Z' }
        @{ Draft = $false; Published = $null }
    ) {
        $apiState.Release.draft = $Draft
        $apiState.Release.published_at = $Published
        { & $scriptUnderTest -Repository 'example/module' -ProjectRoot $fixtureRoot } |
            Should -Throw '*missing or is not marked*'
        @($apiState.Requests | Where-Object Method -in @('Put', 'Patch', 'Post')).Count | Should -Be 0
    }

    It 'rejects a tracked beta older than the latest published beta' {
        $apiState.OtherBetas = @(@{
            prerelease = $true; draft = $false; tag_name = 'v2.0.0-beta002'; published_at = '2026-10-30T12:00:00Z'
        })
        { & $scriptUnderTest -Repository 'example/module' -ProjectRoot $fixtureRoot } |
            Should -Throw '*latest published beta*'
        @($apiState.Requests | Where-Object Method -in @('Put', 'Patch', 'Post')).Count | Should -Be 0
    }

    It 'does not ignore missing required release files' {
        Mock Invoke-RestMethod {
            throw (New-TestHttpException -Message 'Manifest not found' -StatusCode NotFound)
        } -ParameterFilter { -not $Method -and $Uri -like '*/contents/.release-please-manifest.json?*' }

        { & $scriptUnderTest -Repository 'example/module' -ProjectRoot $fixtureRoot } |
            Should -Throw '*Manifest not found*'
        @($apiState.Requests | Where-Object { $_.Method -eq 'Put' -and $_.Uri -like '*/contents/*' }).Count |
            Should -Be 0
    }

    It 'does not treat a version file permission error as a missing file' {
        Mock Invoke-RestMethod {
            throw (New-TestHttpException -Message 'Version file forbidden' -StatusCode Forbidden)
        } -ParameterFilter { -not $Method -and $Uri -like '*/contents/version.txt?*' }

        { & $scriptUnderTest -Repository 'example/module' -ProjectRoot $fixtureRoot } |
            Should -Throw '*Version file forbidden*'
    }

    It 'does not create a promotion while commits remain after the beta' {
        $gitState.CommitsAfterBeta = 1

        { & $scriptUnderTest -Repository 'example/module' -ProjectRoot $fixtureRoot } |
            Should -Throw '*commit(s) after it*'
        $apiState.Requests.Count | Should -Be 0
    }

    It 'updates an existing branch through the plural refs endpoint' {
        & $scriptUnderTest -Repository 'example/module' -ProjectRoot $fixtureRoot

        $updates = @($apiState.Requests | Where-Object {
            $_.Method -eq 'Patch' -and $_.Uri -like '*/git/refs/heads/*'
        })
        $updates.Count | Should -Be 1
        ($updates[0].Body | ConvertFrom-Json).sha | Should -Be $apiState.MainSha
        @($apiState.Requests | Where-Object { $_.Method -eq 'Post' -and $_.Uri -like '*/git/refs' }).Count |
            Should -Be 0
    }

    It 'creates a branch only when the branch lookup returns 404' {
        Mock Invoke-RestMethod {
            throw (New-TestHttpException -Message 'Branch not found' -StatusCode NotFound)
        } -ParameterFilter { $Uri -like '*/git/ref/heads/release-please--branches--main' }
        Mock Invoke-RestMethod {
            param($Uri, $Method, $Body)
            $apiState.Requests.Add([pscustomobject]@{ Uri = $Uri; Method = $Method; Body = $Body })
        } -ParameterFilter { $Method -eq 'Post' -and $Uri -like '*/git/refs' }

        & $scriptUnderTest -Repository 'example/module' -ProjectRoot $fixtureRoot

        $creates = @($apiState.Requests | Where-Object { $_.Method -eq 'Post' -and $_.Uri -like '*/git/refs' })
        $creates.Count | Should -Be 1
        ($creates[0].Body | ConvertFrom-Json).ref | Should -Be 'refs/heads/release-please--branches--main'
    }

    It 'surfaces update errors without attempting branch creation' {
        Mock Invoke-RestMethod {
            throw (New-TestHttpException -Message 'Branch update failed' -StatusCode NotFound)
        } -ParameterFilter { $Method -eq 'Patch' -and $Uri -like '*/git/refs/heads/*' }

        { & $scriptUnderTest -Repository 'example/module' -ProjectRoot $fixtureRoot } |
            Should -Throw '*Branch update failed*'
        @($apiState.Requests | Where-Object { $_.Method -eq 'Post' -and $_.Uri -like '*/git/refs' }).Count |
            Should -Be 0
    }

    It 'protects an existing stable promotion PR from being recreated' {
        $apiState.OpenPullRequests = @(
            @{
                number = 84
                labels = @(@{ name = 'stable-promotion' })
            }
        )

        $number = & $scriptUnderTest -Repository 'example/module' -ProjectRoot $fixtureRoot

        $number | Should -Be 84
        $apiState.Requests.Uri | Should -Not -Contain 'https://api.github.test/repos/example/module/git/ref/heads/main'
    }

    It 'refuses a stale checkout before changing the release branch' {
        $apiState.MainSha = 'changed-on-remote'
        { & $scriptUnderTest -Repository 'example/module' -ProjectRoot $fixtureRoot } |
            Should -Throw '*Main changed*'
        @($apiState.Requests | Where-Object { $_.Method -in @('Put', 'Patch', 'Post') }).Count |
            Should -Be 0
    }
}
