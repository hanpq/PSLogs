# Building and releasing PSLogs

## Develop and verify

From the repository root, run the full build and test suite:

```powershell
./build.ps1
```

The default `Verify` task builds the module from `source/` and runs tests from `tests/`. To run one task:

```powershell
./build.ps1 -Task Build
./build.ps1 -Task Test
./build.ps1 -Task Package
```

Import the generated module from `output/PSLogs/<version>/` to try it locally. Make changes in `source/`, not generated output under `output/`.

## Submit a change

1. Make and test your change on a branch.
2. Open a pull request against `main`. CI runs for pull requests and pushes to `main`.
3. Use a Conventional Commit title for changes that should trigger a release. `feat:` requests a minor release; `fix:` and `perf:` request a patch; `!` or a `BREAKING CHANGE:` footer requests a major release. `docs:`, `test:`, and `chore:` do not trigger releases.
4. Squash-merge using the PR title as the commit message so Release Please can determine the correct version and generate release notes.

## Publish a stable release

1. After release-worthy changes reach `main`, Release Please opens or updates a release pull request.
2. Review the proposed version and generated notes. Compare them with `## [Unreleased]` in `CHANGELOG.md`; move relevant missing bullets into the release notes and remove stale bullets.
3. Wait for CI, then merge the release pull request.

The release workflow builds and tests the tag, attaches a ZIP to the GitHub release, and publishes the module to the PowerShell Gallery. Do not manually edit `.release-please-manifest.json` during routine development.

## Publish a prerelease

1. Make sure there is no stable release pull request waiting to be merged.
2. Set `"prerelease": true` in `release-please-config.json` and push that configuration change with a non-release commit, such as `chore: enable prerelease`.
3. Push a release-worthy `fix:` or `feat:` commit. Release Please opens a beta release pull request.
4. Review the version and notes, wait for CI, and merge the pull request to publish the beta. Repeat with further release-worthy changes for later beta numbers.

To promote a beta to stable, set `"prerelease": false` and push a `fix:` commit. Review the proposed stable version before merging the resulting release pull request. Keep the `"versioning": "prerelease"` strategy configured; inspect the proposed version because features or breaking changes during the beta cycle can change it.

Prereleases use padded labels such as `beta001`. Users must opt in when installing, for example:

```powershell
Install-Module PSLogs -AllowPrerelease
```

## Update build dependencies

1. Change the intended module version in [RequiredModules.psd1](RequiredModules.psd1).
2. Restore the pinned dependencies and verify the build:

```powershell
./build.ps1 -Task InstallDependencies
./build.ps1
```

The build uses these pinned dependencies from `output/RequiredModules`; you do not need to install them separately.
