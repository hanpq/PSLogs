# Building and releasing PSLogs

PSLogs is built with [ModuleBuilder](https://www.powershellgallery.com/packages/ModuleBuilder), tested with [Pester](https://pester.dev/), and checked with PSScriptAnalyzer. The build script restores its pinned PowerShell module dependencies into `output/RequiredModules`, so the build does not depend on modules installed elsewhere on the machine.

## Local development

Run the full build and test suite from the repository root:

```powershell
./build.ps1
```

The default `Verify` task builds the module from `source/` into `output/PSLogs/<version>/` and runs the tests in `tests/`. To run individual tasks:

```powershell
./build.ps1 -Task Build
./build.ps1 -Task Test
./build.ps1 -Task Package
./build.ps1 -Task Clean
./build.ps1 -Task InstallDependencies
```

`Package` creates `output/PSLogs.<version>.zip`. `Clean` removes generated module output, test results, and package archives without deleting the restored dependencies. Generated files under `output/` are ignored by Git.

The build prints progress messages for dependency checks, module compilation, tests, packaging, and cleanup, including the relevant output paths. A successful task ends with a completion message; failed tasks report an error instead.

The build infrastructure discovers the module name and version from the single module manifest directly under `source/`, using `scripts/Get-BuildProject.ps1`. Output directories, package names, test report names, release publishing, and generated documentation use that identity rather than a hard-coded project name. The reusable build steps are `Build-ProjectModule`, `Invoke-ModuleTests`, and `New-ModulePackage`; their order is defined in the `switch ($Task)` block at the bottom of `build.ps1`.

When reusing the infrastructure in another repository, keep the same source layout and update repository configuration such as the manifest path in `release-please-config.json`, the documentation destination in the release workflow, and GitHub secrets. The module's own source and functional tests remain project-specific.

Use the module locally by importing the manifest under `output/PSLogs/<version>/`. Do not edit generated files there; make changes under `source/` and rebuild.

Each build invocation runs in a fresh, profile-free PowerShell process using the same PowerShell installation as the caller. This prevents modules and assemblies already loaded by VS Code or your interactive session from conflicting with the pinned build dependencies. You can continue using `./build.ps1 Test` in your existing session; restarting PowerShell or manually unloading modules is not required.

The test runner explicitly imports the pinned PSScriptAnalyzer and Pester modules from `output/RequiredModules` before test discovery. A dependency import error or discovery error fails the build, just like a failed test. A nonzero exit code from the isolated process is reported as an error to the caller.

## Making changes without a release

Make changes on a branch and open a pull request against `main`. CI runs for pull requests and pushes to `main`; pushing a feature branch alone does not run this workflow. Use a [Conventional Commit](https://www.conventionalcommits.org/) message for changes that should affect the next release:

```text
feat: add a new logging target
fix: handle an empty log message
docs: clarify the file target options
chore: update pinned build dependencies
```

`feat` requests a minor release, `fix` and `perf` request a patch release, and `!` or a `BREAKING CHANGE:` footer requests a major release. Other commit types do not request a release.

Squash merging feature pull requests is recommended. With squash merge, Release Please sees the resulting squash commit on `main`, so use a Conventional Commit PR title such as `feat: add a new logging target`; check that the squash commit uses that title. For a regular merge or rebase merge, the individual commits land on `main`, so give each release-worthy commit a Conventional Commit message. The branch name does not determine the release type.

Merging a feature pull request to `main` does not publish a release. Several feature pull requests can be merged over time; Release Please will open or update one release pull request to collect the unreleased changes. Merge that release pull request when you are ready to release the accumulated changes. After it is merged, a new set of changes on `main` starts the next release cycle.

## Releasing

The Release Please workflow watches `main` and opens or updates a release pull request when Conventional Commits request a version bump. Review and merge that pull request to create the version tag and GitHub release. The release workflow then builds and tests that tag, attaches a ZIP package to the GitHub release, and publishes the module to the PowerShell Gallery.

The release pull request adds a versioned section with generated release notes to `CHANGELOG.md` and updates the version in both `source/PSLogs.psd1` and `.release-please-manifest.json`. Notes are generated from the Conventional Commit messages that land on `main`, so make those messages clear and user-focused. Non-release commits such as `docs:` and `chore:` do not appear in the generated release notes.

Existing bullets under `## [Unreleased]` are not inputs to Release Please. It generates notes from commits, adds the new version section above the existing changelog headings, and leaves the current `Unreleased` bullets where they are. In particular, bullets already there will not automatically move into the release section; they can remain under `Unreleased` even after the changes they describe have shipped.

Before merging a release pull request, compare its generated notes with the existing `Unreleased` bullets. If a bullet describes a change included in the release but is missing from the generated notes, add or move it into the release section on the release pull request, then remove it from `Unreleased`. Remove stale bullets that have already shipped. Review these edits after the bot's last update, because a later update may regenerate the release pull request. For future changes, use clear Conventional Commit messages so generated release notes include them automatically. Do not edit the `.release-please-manifest.json` version manually during routine development. For an intentional release-version correction, update that manifest and the module manifest together.

### GitHub configuration

The release workflow expects the existing `GALLERYAPITOKEN` secret for PowerShell Gallery publishing. ProGet publishing is skipped unless `PSTOOLS_APITOKEN` is set; when enabled, it also requires `PSTOOLS_SOURCE`. The automatic `getps.dev` documentation update runs when `GITHUBTOKEN` is configured with permission to push to `hanpq/getps.dev`. Without that token, the docs update is skipped.

Configure a `RELEASE_PLEASE_TOKEN` fine-grained token with repository contents, issues, and pull-request read/write permissions. Release Please uses it to open release pull requests and create tags/releases; using a token also allows the generated pull requests and releases to trigger their normal GitHub Actions workflows.

## Pinning build dependencies

Exact versions for the build, publishing, and documentation PowerShell modules are listed in [RequiredModules.psd1](RequiredModules.psd1). Update the relevant version there when intentionally upgrading a dependency, then run:

```powershell
./build.ps1 -Task InstallDependencies
./build.ps1
```

The first command restores the newly pinned versions into `output/RequiredModules`; the second validates the updated toolchain and module.
