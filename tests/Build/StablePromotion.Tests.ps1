BeforeAll {
    $scriptUnderTest = Join-Path $PSScriptRoot '..\..\scripts\New-StablePromotion.ps1'
}

Describe 'Stable promotion PR creation' {
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
        & git -C $fixtureRoot init --quiet -b main
        & git -C $fixtureRoot config user.name 'Release Tests'
        & git -C $fixtureRoot config user.email 'release-tests@example.test'
        & git -C $fixtureRoot add --all
        & git -C $fixtureRoot commit --quiet -m 'chore: publish beta'
        & git -C $fixtureRoot tag v2.0.0-beta001

        $apiState = @{
            Requests = [System.Collections.Generic.List[object]]::new()
            OpenPullRequests = @()
            Writes = [System.Collections.Generic.List[object]]::new()
            MainSha = (& git -C $fixtureRoot rev-parse HEAD)
        }
        Mock Invoke-RestMethod {
            param($Uri, $Method, $Body)
            $apiState.Requests.Add([pscustomobject]@{ Uri = $Uri; Method = $Method; Body = $Body })
            if ($Uri -like '*/releases/tags/*')
            {
                return @{ prerelease = $true; tag_name = 'v2.0.0-beta001' }
            }
            if ($Uri -like '*/pulls?state=open*')
            {
                return $apiState.OpenPullRequests
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

    It 'does not create a promotion while commits remain after the beta' {
        Set-Content -LiteralPath (Join-Path $fixtureRoot 'extra.txt') -Value 'post-beta change'
        & git -C $fixtureRoot add extra.txt
        & git -C $fixtureRoot commit --quiet -m 'fix: post-beta change'

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
            $response = [System.Net.Http.HttpResponseMessage]::new([System.Net.HttpStatusCode]::NotFound)
            throw [Microsoft.PowerShell.Commands.HttpResponseException]::new('Branch not found', $response)
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
            $response = [System.Net.Http.HttpResponseMessage]::new([System.Net.HttpStatusCode]::NotFound)
            throw [Microsoft.PowerShell.Commands.HttpResponseException]::new('Branch update failed', $response)
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
