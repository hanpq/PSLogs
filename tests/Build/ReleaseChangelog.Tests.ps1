BeforeAll {
    $scriptUnderTest = Join-Path $PSScriptRoot '..\..\scripts\Assert-ReleaseChangelog.ps1'
    function git {
        param([Parameter(ValueFromRemainingArguments)][string[]]$Arguments)
        throw "Unexpected Git arguments: $Arguments"
    }
}

Describe 'Early release changelog validation' {
    BeforeEach {
        $fixtureRoot = Join-Path $TestDrive ([guid]::NewGuid().ToString())
        New-Item -ItemType Directory -Path (Join-Path $fixtureRoot 'source') -Force | Out-Null
        Set-Content (Join-Path $fixtureRoot 'source\ExampleModule.psd1') "@{ ModuleVersion = '1.0.0' }"
        Set-Content (Join-Path $fixtureRoot '.release-please-manifest.json') '{".":"2.0.0-beta001"}'
        $changelogPath = Join-Path $fixtureRoot 'CHANGELOG.md'
        $changelog = @'
# Changelog

## [2.0.0-beta001](https://github.com/example/module/compare/v1.0.0...v2.0.0-beta001) (2026-10-29)

### Features

* new feature

## [1.0.0](https://github.com/example/module/compare/v0.9.0...v1.0.0) (2026-10-01)

* old feature
'@
        Set-Content $changelogPath $changelog
        $gitState = @{ Tags = @('v1.0.0', 'v2.0.0-beta001'); ExitCode = 0 }
        Mock git {
            $global:LASTEXITCODE = $gitState.ExitCode
            return $gitState.Tags
        }
    }

    It 'validates that the published beta can be rolled up before promotion' {
        { & $scriptUnderTest -ProjectRoot $fixtureRoot } | Should -Not -Throw
    }

    It 'allows only the proposed first section to be unreleased on a release PR' {
        $gitState.Tags = @('v1.0.0')
        { & $scriptUnderTest -ProjectRoot $fixtureRoot -ReleasePullRequest } | Should -Not -Throw
        { & $scriptUnderTest -ProjectRoot $fixtureRoot } | Should -Throw "*Unpublished changelog section '2.0.0-beta001'*"
    }

    It 'rejects a stale stable section before preparation' {
        Set-Content $changelogPath ($changelog.Replace('2.0.0-beta001', '2.0.0'))
        { & $scriptUnderTest -ProjectRoot $fixtureRoot } | Should -Throw "*Unpublished changelog section '2.0.0'*"
    }

    It 'rejects an unpublished historical section even when the proposed section is valid' {
        $stale = "## [1.5.0] - 2026-10-20`n`n* stale notes`n`n"
        Set-Content $changelogPath ($changelog.Replace('## [1.0.0]', "$stale## [1.0.0]"))
        $gitState.Tags = @('v1.0.0')
        { & $scriptUnderTest -ProjectRoot $fixtureRoot -ReleasePullRequest } | Should -Throw "*Unpublished changelog section '1.5.0'*"
    }

    It 'rejects a missing previous stable boundary on the beta PR' {
        Set-Content $changelogPath (($changelog -split '(?m)^## \[1.0.0\]')[0])
        { & $scriptUnderTest -ProjectRoot $fixtureRoot -ReleasePullRequest } | Should -Throw '*without a previous stable*'
    }

    It 'rejects an invalid previous-stable comparison link on the beta PR' {
        Set-Content $changelogPath ($changelog.Replace('compare/v1.0.0...', 'compare/v0.8.0...'))
        { & $scriptUnderTest -ProjectRoot $fixtureRoot -ReleasePullRequest } | Should -Throw '*comparison link*'
    }

    It 'rejects a release PR with a mismatched first version' {
        Set-Content (Join-Path $fixtureRoot '.release-please-manifest.json') '{".":"2.0.0-beta002"}'
        { & $scriptUnderTest -ProjectRoot $fixtureRoot -ReleasePullRequest } | Should -Throw '*first changelog release*'
    }

    It 'fails closed when tags cannot be read' {
        $gitState.ExitCode = 1
        { & $scriptUnderTest -ProjectRoot $fixtureRoot } | Should -Throw '*Could not read release tags*'
    }
}
