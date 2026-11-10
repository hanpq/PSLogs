BeforeAll {
    $notesScript = Join-Path $PSScriptRoot '..\..\scripts\Get-GalleryReleaseNotes.ps1'
    $changelog = @'
# Changelog

## [1.3.0](https://github.com/example/module/compare/v1.2.3...v1.3.0) (2026-11-10)

* stable feature

## [Unreleased]

* development note
'@
}

Describe 'Release notes for stable and preview builds' {
    It 'uses stable version notes on the release PR and tag' {
        & $notesScript -Changelog $changelog -Version '1.3.0' -UseVersionSection |
            Should -BeExactly '* stable feature'
    }

    It 'preserves Unreleased notes for ordinary untagged builds' {
        & $notesScript -Changelog $changelog -Version '1.3.0' | Should -BeExactly '* development note'
    }

    It 'does not fall back to Unreleased when a stable release section is missing' {
        { & $notesScript -Changelog $changelog -Version '1.3.1' -UseVersionSection } |
            Should -Throw "*Could not find release notes section '1.3.1'*"
    }

    It 'builds beta notes without a changelog or a beta changelog section' {
        $notes = & $notesScript -Version '1.4.0-beta001'
        $notes | Should -Match 'Preview build 1.4.0-beta001'
        $notes | Should -Match 'next stable release'
    }

    It 'preserves notes at or below 10,000 characters' -ForEach @(0, 9999, 10000) {
        $notes = 'x' * $_
        & $notesScript -Notes $notes -Changelog $changelog | Should -BeExactly $notes
    }

    It 'keeps whole lines and the full changelog link within 10,000 characters' {
        $notes = ("* " + ('x' * 96) + "`n") * 112
        $notes.Length | Should -BeGreaterThan 11000
        $result = & $notesScript -Notes $notes -Changelog $changelog
        $result.Length | Should -BeLessOrEqual 10000
        $result | Should -Match 'Release notes are truncated. See the full changelog: https://github.com/example/module/blob/main/CHANGELOG.md'
        ($result -split "`n`nRelease notes are truncated")[0] | Should -Match ('x' * 96 + '$')
    }

    It 'fails explicitly when a single oversized line cannot be safely shortened' {
        { & $notesScript -Notes ('x' * 11000) -Changelog $changelog } |
            Should -Throw '*preserving whole lines*'
    }
}
