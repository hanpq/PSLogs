BeforeAll {
    $scriptUnderTest = Join-Path $PSScriptRoot '..\..\scripts\New-BetaRelease.ps1'
    function git {
        param([Parameter(ValueFromRemainingArguments)][string[]]$Arguments)
        throw "Unexpected Git arguments: $Arguments"
    }
    function gh {
        param([Parameter(ValueFromRemainingArguments)][string[]]$Arguments)
        throw "Unexpected GitHub CLI arguments: $Arguments"
    }
}

Describe 'Independent beta release allocation' {
    BeforeAll {
        $savedToken = $env:GH_TOKEN
        $savedApi = $env:GITHUB_API_URL
        $savedExitCode = $global:LASTEXITCODE
        $env:GH_TOKEN = 'test-token'
        $env:GITHUB_API_URL = 'https://api.github.test'
    }
    AfterAll {
        $env:GH_TOKEN = $savedToken
        $env:GITHUB_API_URL = $savedApi
        $global:LASTEXITCODE = $savedExitCode
    }
    BeforeEach {
        $fixture = Join-Path $TestDrive ([guid]::NewGuid().ToString())
        New-Item -ItemType Directory -Path (Join-Path $fixture 'source') -Force | Out-Null
        Set-Content (Join-Path $fixture 'source\ExampleModule.psd1') "@{ ModuleVersion = '1.2.3' }"
        Set-Content (Join-Path $fixture '.release-please-manifest.json') '{".":"1.2.3"}'
        Set-Content (Join-Path $fixture 'version.txt') '1.2.3'
        Set-Content (Join-Path $fixture 'CHANGELOG.md') '# Stable changelog'
        $state = @{
            Sha = '0123456789abcdef0123456789abcdef01234567'
            Candidate = '1.3.0'
            Tags = @()
            GitExitCode = 0
            CliExitCode = 0
            Pulls = @(@{
                number = 42; base = @{ sha = '0123456789abcdef0123456789abcdef01234567' }
                head = @{ sha = 'stable-pr-head'; repo = @{ full_name = 'example/module' } }
            })
            MainSha = '0123456789abcdef0123456789abcdef01234567'
        }
        Mock git {
            param($Arguments)
            $global:LASTEXITCODE = 0
            if ($Arguments -contains 'rev-parse') { return $state.Sha }
            if ($Arguments -contains 'tag') { $global:LASTEXITCODE = $state.GitExitCode; return $state.Tags }
            throw "Unexpected Git command: $Arguments"
        }
        Mock gh { $global:LASTEXITCODE = $state.CliExitCode }
        Mock Invoke-RestMethod {
            param($Uri)
            if ($Uri -like '*/pulls?state=open*') { return , @($state.Pulls) }
            if ($Uri -like '*/git/ref/heads/main') { return @{ object = @{ sha = $state.MainSha } } }
            if ($Uri -like '*/contents/*') {
                return @{
                    encoding = 'base64'
                    content = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes((@{ '.' = $state.Candidate } | ConvertTo-Json)))
                }
            }
            throw "Unexpected API URI: $Uri"
        }
    }

    It 'uses the inferred stable candidate with beta001 and never writes release metadata' {
        $before = Get-ChildItem $fixture -File -Recurse | Get-FileHash
        & $scriptUnderTest -Repository example/module -ProjectRoot $fixture
        $after = Get-ChildItem $fixture -File -Recurse | Get-FileHash
        $after.Hash | Should -Be $before.Hash
        Should -Invoke gh -Times 1 -Exactly -ParameterFilter {
            $Arguments[0] -ceq 'release' -and $Arguments[1] -ceq 'create' -and
            $Arguments[2] -ceq 'v1.3.0-beta001' -and $Arguments -contains $state.Sha -and
            $Arguments -contains '--prerelease' -and $Arguments -contains '--latest=false'
        }
        Should -Invoke Invoke-RestMethod -Times 1 -Exactly -ParameterFilter {
            $Uri -like '*/contents/.release-please-manifest.json?ref=stable-pr-head'
        }
    }

    It 'increments counters numerically and ignores other version bases' {
        $state.Tags = @('v1.3.0-beta009', 'v1.3.0-beta010', 'v1.3.0-beta003', 'v1.2.4-beta999')
        & $scriptUnderTest -Repository example/module -ProjectRoot $fixture
        Should -Invoke gh -Times 1 -Exactly -ParameterFilter { $Arguments[2] -ceq 'v1.3.0-beta011' }
    }

    It 'starts beta001 for a newly inferred major or patch version' -ForEach @('1.2.4', '2.0.0') {
        $state.Candidate = $_
        & $scriptUnderTest -Repository example/module -ProjectRoot $fixture
        Should -Invoke gh -Times 1 -Exactly -ParameterFilter { $Arguments[2] -ceq "v$($state.Candidate)-beta001" }
    }

    It 'continues beyond three counter digits' {
        $state.Tags = @('v1.3.0-beta999')
        & $scriptUnderTest -Repository example/module -ProjectRoot $fixture
        Should -Invoke gh -Times 1 -Exactly -ParameterFilter { $Arguments[2] -ceq 'v1.3.0-beta1000' }
    }

    It 'rejects an absent or cross-repository stable PR' -ForEach @('absent', 'fork') {
        if ($_ -eq 'absent') { $state.Pulls = @() } else { $state.Pulls[0].head.repo.full_name = 'other/module' }
        { & $scriptUnderTest -Repository example/module -ProjectRoot $fixture } | Should -Throw '*one open stable Release Please PR*'
        Should -Invoke gh -Times 0 -Exactly
    }

    It 'refuses the dispatch if main advanced while the stable candidate was refreshed' {
        $state.MainSha = 'new-main'
        { & $scriptUnderTest -Repository example/module -ProjectRoot $fixture } | Should -Throw '*Rerun Publish beta*'
        Should -Invoke gh -Times 0 -Exactly
    }

    It 'uses the candidate version even when the stable PR head has not changed after a docs-only push' {
        $state.Pulls[0].base.sha = 'old-main'
        & $scriptUnderTest -Repository example/module -ProjectRoot $fixture
        Should -Invoke gh -Times 1 -Exactly -ParameterFilter {
            $Arguments[2] -ceq 'v1.3.0-beta001' -and $Arguments -contains $state.Sha
        }
    }

    It 'rejects prerelease, equal or older stable candidates' -ForEach @('1.3.0-beta001', '1.2.3', '1.2.2') {
        $state.Candidate = $_
        { & $scriptUnderTest -Repository example/module -ProjectRoot $fixture } | Should -Throw '*must be a stable version newer*'
        Should -Invoke gh -Times 0 -Exactly
    }

    It 'rejects a baseline left on the old beta release model' {
        Set-Content (Join-Path $fixture '.release-please-manifest.json') '{".":"1.3.0-beta001"}'
        { & $scriptUnderTest -Repository example/module -ProjectRoot $fixture } | Should -Throw '*tracked version must be the last stable release*'
    }

    It 'does not preview a candidate already published as stable' {
        $state.Tags = @('v1.3.0')
        { & $scriptUnderTest -Repository example/module -ProjectRoot $fixture } | Should -Throw '*already tagged*'
        Should -Invoke gh -Times 0 -Exactly
    }

    It 'surfaces tag lookup and release creation errors' -ForEach @('git', 'gh') {
        if ($_ -eq 'git') { $state.GitExitCode = 1 } else { $state.CliExitCode = 1 }
        { & $scriptUnderTest -Repository example/module -ProjectRoot $fixture } | Should -Throw '*Could not*'
    }
}
