BeforeAll {
    $projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
    $notesScript = Join-Path $projectRoot 'scripts\Get-StableReleaseNotes.ps1'
    $updateScript = Join-Path $projectRoot 'scripts\Update-StableReleaseNotes.ps1'
    $fixture = @'
# Changelog

## [2.0.0](https://github.com/example/module/compare/v2.0.0-beta002...v2.0.0) (2026-10-29)

### Bug Fixes

* promote to stable

## [2.0.0-beta002](https://github.com/example/module/compare/v1.1.0-beta001...v2.0.0-beta002) (2026-10-28)

### Features

* new feature

### Bug Fixes

* handle empty messages

## [1.1.0-beta001](https://github.com/example/module/compare/v1.0.0...v1.1.0-beta001) (2026-10-27)

### Features

* new feature

### BREAKING CHANGES

* remove old option

  Use the new option instead.

## [Unreleased]

* manually maintained note

## [1.0.0] - 2026-10-01

### Features

* old stable feature
'@
    $fixture = $fixture.Replace("`r`n", "`n")
    $stableNotes = ($fixture -split '(?m)^## \[2.0.0-beta002\]')[0] -replace '\A# Changelog\s*', ''
    $body = "Custom bot header`n---`n`n$($stableNotes.Trim())`n`n---`nCustom footer <!-- metadata -->"
}

Describe 'Stable release note consolidation' {
    It 'groups and deduplicates all beta notes since the previous stable release' {
        $result = & $notesScript -Changelog $fixture -PullRequestBody $body -Version '2.0.0'
        $notes = ($result.Changelog -split '(?m)^## \[2.0.0-beta002\]')[0]

        $result.RolledUp | Should -BeTrue
        $notes | Should -Match 'compare/v1\.0\.0\.\.\.v2\.0\.0'
        $notes | Should -Match '\* promote to stable'
        $notes | Should -Match '\* handle empty messages'
        ([regex]::Matches($notes, '(?m)^\* new feature$')).Count | Should -Be 1
        ([regex]::Matches($notes, '(?m)^### Bug Fixes$')).Count | Should -Be 1
        $notes | Should -Match '(?s)\* remove old option\s+Use the new option instead\.'
        $notes | Should -Not -Match 'old stable feature|manually maintained note'
    }

    It 'preserves historical entries and PR metadata while updating the PR notes' {
        $result = & $notesScript -Changelog $fixture -PullRequestBody $body -Version '2.0.0'
        $historical = $fixture.Substring($fixture.IndexOf('## [2.0.0-beta002]'))

        $result.Changelog.EndsWith($historical) | Should -BeTrue
        $result.PullRequestBody | Should -Match '\ACustom bot header\n---'
        $result.PullRequestBody | Should -Match '---\nCustom footer <!-- metadata -->\z'
        $result.PullRequestBody | Should -Match 'handle empty messages'
        $result.PullRequestBody | Should -Not -Match '## \[2.0.0-beta002\]'
    }

    It 'is identical on reruns and after the bot regenerates the PR body' {
        $first = & $notesScript -Changelog $fixture -PullRequestBody $body -Version '2.0.0'
        $second = & $notesScript -Changelog $first.Changelog -PullRequestBody $first.PullRequestBody -Version '2.0.0'
        $regenerated = & $notesScript -Changelog $first.Changelog -PullRequestBody $body -Version '2.0.0'

        $second.Changelog | Should -BeExactly $first.Changelog
        $second.PullRequestBody | Should -BeExactly $first.PullRequestBody
        $regenerated.PullRequestBody | Should -BeExactly $first.PullRequestBody
    }

    It 'preserves introductory paragraphs without duplicating them on reruns' {
        $withProse = $fixture.Replace("### Features`n`n* new feature",
            "Important upgrade information.`n`n### Features`n`n* new feature")
        $first = & $notesScript -Changelog $withProse -PullRequestBody $body -Version '2.0.0'
        $second = & $notesScript -Changelog $first.Changelog -PullRequestBody $first.PullRequestBody -Version '2.0.0'
        $second.Changelog | Should -BeExactly $first.Changelog
        $notes = ($first.Changelog -split '(?m)^## \[2.0.0-beta002\]')[0]
        ([regex]::Matches($notes, 'Important upgrade information\.')).Count | Should -Be 1
    }

    It 'preserves Windows line endings and non-ASCII text' {
        $unicodeNote = "message $([char]0x00e5)$([char]0x00e4)$([char]0x00f6)"
        $windowsFixture = $fixture.Replace('handle empty messages', $unicodeNote).Replace("`r`n", "`n").Replace("`n", "`r`n")
        $windowsBody = $body.Replace("`n", "`r`n")
        $result = & $notesScript -Changelog $windowsFixture -PullRequestBody $windowsBody -Version '2.0.0'

        $result.Changelog | Should -Match ([regex]::Escape($unicodeNote))
        $result.Changelog | Should -Not -Match '(?<!\r)\n'
        $result.PullRequestBody | Should -Not -Match '(?<!\r)\n'
    }

    It 'does not modify a stable release without intervening betas' {
        $withoutBetas = $fixture.Substring(0, $fixture.IndexOf('## [2.0.0-beta002]')) +
            $fixture.Substring($fixture.IndexOf('## [1.0.0]'))
        $result = & $notesScript -Changelog $withoutBetas -PullRequestBody $body -Version '2.0.0'

        $result.RolledUp | Should -BeFalse
        $result.Changelog | Should -BeExactly $withoutBetas
        $result.PullRequestBody | Should -BeExactly $body
    }

    It 'rejects a mismatched tracked version' {
        { & $notesScript -Changelog $fixture -PullRequestBody $body -Version '2.0.1' } |
            Should -Throw '*first changelog release*'
    }

    It 'rejects missing stable boundaries' {
        $withoutStable = $fixture.Substring(0, $fixture.IndexOf('## [1.0.0]'))
        { & $notesScript -Changelog $withoutStable -PullRequestBody $body -Version '2.0.0' } |
            Should -Throw '*without a previous stable*'
    }

    It 'rejects an inconsistent comparison baseline' {
        { & $notesScript -Changelog $fixture.Replace('compare/v1.0.0...', 'compare/v0.9.0...') -PullRequestBody $body -Version '2.0.0' } |
            Should -Throw '*comparison link*'
    }

    It 'rejects unknown release headings rather than omitting their notes' {
        { & $notesScript -Changelog $fixture.Replace('## [1.1.0-beta001]', '## [1.1.0-beta.1]') -PullRequestBody $body -Version '2.0.0' } |
            Should -Throw '*Unrecognized changelog heading*'
    }

    It 'rejects an unsupported PR body' {
        { & $notesScript -Changelog $fixture -PullRequestBody 'Unexpected body format' -Version '2.0.0' } |
            Should -Throw '*delimiters*'
    }

    It 'rejects PR notes for another release' {
        { & $notesScript -Changelog $fixture -PullRequestBody $body.Replace('## [2.0.0]', '## [2.0.1]') -Version '2.0.0' } |
            Should -Throw '*matching stable release*'
    }
}

Describe 'Release PR workflow integration' {
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
            PrBody = $body
            ChangelogContent = $fixture
            ManifestContent = '{".":"2.0.0"}'
            BranchChanged = $false
            Reads = 0
            Writes = [System.Collections.Generic.List[object]]::new()
        }
        Mock Invoke-RestMethod {
            param($Uri, $Method, $Body)
            if ($Method -in @('Put', 'Patch'))
            {
                $payload = [System.Text.Encoding]::UTF8.GetString($Body) | ConvertFrom-Json
                $apiState.Writes.Add([pscustomobject]@{ Method = $Method; Payload = $payload; Uri = $Uri })
                return
            }
            if ($Uri -like '*/pulls/42')
            {
                $apiState.Reads++
                return [pscustomobject]@{
                    state = 'open'
                    head = @{
                        sha = if ($apiState.BranchChanged -and $apiState.Reads -gt 1) { 'changed' } else { 'original' }
                        ref = 'release-please--branches--main'
                        repo = @{ full_name = 'example/module' }
                    }
                    labels = @(@{ name = 'autorelease: pending' }, @{ name = 'stable-promotion' })
                    body = $apiState.PrBody
                }
            }
            $content = switch -Wildcard ([string]$Uri)
            {
                '*/contents/.release-please-manifest.json?*' { $apiState.ManifestContent }
                '*/contents/CHANGELOG.md?*' { $apiState.ChangelogContent }
                default { throw "Unexpected API URI: $Uri" }
            }
            if ($null -eq $content) { throw "Missing mock content for $Uri" }
            return @{
                encoding = 'base64'
                sha = 'file-sha'
                content = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($content))
            }
        }
    }

    It 'updates the PR branch changelog and body using the API' {
        & $updateScript -Repository 'example/module' -PullRequestNumber 42

        $apiState.Writes.Count | Should -Be 2
        $commit = $apiState.Writes[0].Payload
        $commit.branch | Should -Be 'release-please--branches--main'
        $commit.sha | Should -Be 'file-sha'
        $commit.message | Should -Match 'Co-authored-by: Copilot'
        [System.Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($commit.content)) |
            Should -Match 'compare/v1\.0\.0\.\.\.v2\.0\.0'
        $apiState.Writes[1].Payload.body | Should -Match 'handle empty messages'
    }

    It 'rejects prerelease metadata on a stable promotion PR' {
        $apiState.ManifestContent = '{".":"2.0.0-beta002"}'
        { & $updateScript -Repository 'example/module' -PullRequestNumber 42 } |
            Should -Throw '*must track a stable version*'
        $apiState.Writes.Count | Should -Be 0
    }

    It 'makes no API writes on a rerun' {
        $result = & $notesScript -Changelog $fixture -PullRequestBody $body -Version '2.0.0'
        $apiState.ChangelogContent = $result.Changelog
        $apiState.PrBody = $result.PullRequestBody
        & $updateScript -Repository 'example/module' -PullRequestNumber 42
        $apiState.Writes.Count | Should -Be 0
    }

    It 'can repair the body after the changelog update already succeeded' {
        $result = & $notesScript -Changelog $fixture -PullRequestBody $body -Version '2.0.0'
        $apiState.ChangelogContent = $result.Changelog
        & $updateScript -Repository 'example/module' -PullRequestNumber 42
        $apiState.Writes.Count | Should -Be 1
        $apiState.Writes[0].Method | Should -Be 'Patch'
    }

    It 'fails before writing if the PR branch moved' {
        $apiState.BranchChanged = $true
        { & $updateScript -Repository 'example/module' -PullRequestNumber 42 } |
            Should -Throw '*changed during consolidation*'
        $apiState.Writes.Count | Should -Be 0
    }

    It 'surfaces API failures' {
        Mock Invoke-RestMethod { throw 'API unavailable' }
        { & $updateScript -Repository 'example/module' -PullRequestNumber 42 } |
            Should -Throw '*API unavailable*'
    }

    It 'does not update a closed or unrelated PR' {
        Mock Invoke-RestMethod {
            @{ state = 'closed'; head = @{ repo = @{ full_name = 'example/other' } }; labels = @() }
        }
        { & $updateScript -Repository 'example/module' -PullRequestNumber 42 } |
            Should -Throw '*open stable promotion PR*'
        $apiState.Writes.Count | Should -Be 0
    }

    It 'surfaces a body update failure after saving the changelog' {
        Mock Invoke-RestMethod { throw 'Body update failed' } -ParameterFilter { $Method -eq 'Patch' }
        { & $updateScript -Repository 'example/module' -PullRequestNumber 42 } |
            Should -Throw '*Body update failed*'
        $apiState.Writes.Count | Should -Be 1
        $apiState.Writes[0].Method | Should -Be 'Put'
    }
}
