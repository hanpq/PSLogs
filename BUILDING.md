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

Optional `source/en-US`, `source/include` and `source/format` directories are copied into the built module when present. Keep source directory names lowercase except for canonical PowerShell culture directories such as `en-US`; the migration kit explains how to rename legacy folders without losing Git history.

Import the generated module from `output/PSLogs/<version>/` to try it locally. Make changes in `source/`, not generated output under `output/`.

Local tests run all suites by default. Use `-Task Test -TestSuite Module` for unit/QA tests or `-Task Test -TestSuite Infrastructure` for build/release tests. CI runs module tests with coverage across all supported platforms, and infrastructure tests once on Linux PowerShell 7 without coverage. Release publishing runs the module suite.

Packaging tests use a fixture changelog and controlled Git tags/PR context, so their example module version is independent of the repository's current release. They verify development, stable release PR and stable tag notes while checking format assets in the built module and ZIP.

Coverage instruments the built module that the tests execute, then uses ModuleBuilder's source mappings to report the original `source/public` and `source/private` files in `output/testResults/JaCoCo_coverage.xml`. The module test run fails if coverage is below the configured target (currently 1%).

The QA suite in `tests/QA/module.tests.ps1` reports each file-quality check separately. It discovers source files and reads unit-test files once per run, and parses each function file once in its context's `BeforeAll`. Keep these shared inputs read-only so individual checks remain independent.

Beta-allocation tests mock Git, the GitHub API and the GitHub CLI. They never create real tags or releases. Beta version-inference tests exercise the pinned Release Please library against a read-only GitHub fixture, including patch, minor, breaking and docs-only changes, and verify GraphQL request URLs through the real HTTP adapter for GitHub.com and GitHub Enterprise. CI runs these separately on Node.js 22; to run them locally:

```powershell
npm ci --prefix scripts/release-please --ignore-scripts --no-audit --no-fund
npm test --prefix scripts/release-please
```

The same Node test command also checks stable preparation's automatic inference, explicit version overrides, invalid/non-increasing versions and PR-only behavior.

### VS Code shortcuts

- **Ctrl+Shift+B** runs `Verify` (build and tests). **Tasks: Run Task** also offers `build`, `test`, and `package`; `test` rebuilds first.
- Select **PowerShell Debug Module (build first)** and press **F5**. It builds, then runs [ModuleDebug.ps1](ModuleDebug.ps1) in a temporary PowerShell console, avoiding stale module state. Keep manual end-user scenarios and breakpoints in that script.
- To step into module functions, set breakpoints in the generated `output/PSLogs/<version>/PSLogs.psm1` after building. Rebuilds replace this file; edit only `source/`. Background logging runs in a separate runspace and is not stepped through by the normal script debugger.

Tasks require PowerShell 7 (`pwsh` on PATH). Debugging requires the VS Code PowerShell extension and uses its selected PowerShell session.

For background logging, run the script in a regular PowerShell terminal, then use **PowerShell Attach to Logging** and select its process. This targets the named `LoggingQueueConsumer` runspace. **PowerShell Attach to Runspace** instead prompts for both process and runspace.

## Submit a change

1. Make and test your change on a branch.
2. Open a pull request against `main`. CI runs for pull requests and pushes to `main`. Pushes that only change release metadata (`.release-please-manifest.json`, `version.txt`, `CHANGELOG.md`), such as merged release PRs, skip CI on `main` because the PR and the release workflow already test them.
3. Use a Conventional Commit title for changes that should trigger a release. `feat:` requests a minor release; `fix:` and `perf:` request a patch; `!` or a `BREAKING CHANGE:` footer requests a major release. `docs:`, `test:`, and `chore:` do not trigger releases.
4. Squash-merge using the PR title as the commit message so Release Please can determine the correct version and generate release notes.

## Release channel cheat sheet

| How it starts | Channel | What happens |
| --- | --- | --- |
| Ordinary PR or push to `main` | None | CI only; never opens or refreshes a release PR. |
| **Actions → Prepare stable release → Run workflow** (from `main`) | Stable preparation | Release Please opens or refreshes the stable release PR from Conventional Commits; never creates a tag/release. |
| Merge the manually prepared stable release PR | Stable | Release Please finalizes its tag/GitHub release on the merged PR's close event; never prepares another PR. |
| **Actions → Publish beta → Run workflow** (from `main`) | Beta preview | Infers the next version without creating a PR, then creates a beta tag/GitHub prerelease for the dispatched commit. |
| GitHub release published | Its tag's channel | The Release workflow builds/tests the tag, validates and packages it, then publishes it. |

### Stable releases

Release Please owns stable version inference, the release PR, changelog, tag and GitHub release. Start preparation explicitly with **Prepare stable release** on `main`, review its PR, wait for CI, then merge it when ready to authorize publishing. Preparation cannot publish, and finalization cannot prepare another PR. Ordinary pushes and ordinary PR merges do neither. A beta is optional, not a prerequisite for stable publishing; its manual dispatch never opens or updates a stable PR and never publishes stable.

The dispatch form has an optional **version** field. Leave it blank for Conventional Commit inference, or enter an exact stable version such as `5.8.0` (no `v`, prerelease or build suffix). Explicit versions must be newer than the tracked stable baseline. The pinned Release Please library prepares/updates the PR with this override in memory; no configuration edit or `Release-As:` commit is needed. The override applies only to that dispatch: another dispatch with a blank field recalculates automatically. Beta inference is unchanged and does not inherit this override. Always review the prepared version and changelog before merging.

The tracked `.release-please-manifest.json` and `version.txt` stay on the last stable version until the stable PR merges. Beta publishing never updates them. Release Please therefore generates the next stable changelog from the previous stable release, covering all intervening releasable commits, regardless of how many betas were published. Historical beta changelog entries can remain untouched; new ones are not created.

### Beta previews

Publish beta uses the pinned Release Please library's read-only `buildPullRequests()` planning API to infer the next stable version from the stable baseline and Conventional Commits. The plan stays in memory: it never creates or updates a PR, branch, label, stable tag or stable release. Version inference uses the read-only Actions token; only beta tag/prerelease creation uses `RELEASE_PLEASE_TOKEN`. No stable preparation or open stable PR is required. There is no second Conventional Commit parser, version override input, beta PR, or beta changelog. If there are no releasable changes, merge a releasable change first; if main advances during inference, rerun the dispatch.

For example, after stable `5.7.2`, fixes infer `5.7.3-beta001`, then `5.7.3-beta002`. If a feature changes the stable candidate to `5.8.0`, its counter starts at `5.8.0-beta001`. The counter is one above the highest existing beta tag for that numeric version. Repeated dispatches on the same commit intentionally create successive preview versions.

The beta tag points at the selected source SHA. The build receives the beta tag version through `-Version` and uses short preview notes instead of reading the changelog. Beta publishing and stable preparation share a concurrency group to serialize version allocation. Beta releases are marked prerelease and never marked latest.

Stable is built and tested independently from the reviewed stable release commit; it is not guaranteed to be the exact source of the last beta. There is no post-beta path allowlist or promotion label.

### Validation and credentials

Release PR CI rejects prerelease versions in the stable manifest. Stable PR/tag builds use their matching changelog section; ordinary untagged development builds still use `[Unreleased]`. Gallery notes retain whole lines and a full-changelog link within 10,000 characters. An oversized single line that cannot be shortened fails explicitly. Built manifests are checked against PSGallery's 10,600-character limit; the full stable changelog and GitHub release notes are not truncated.

The Release workflow validates the tag, GitHub prerelease flag and built module version before publishing. Stable tags must match the tracked stable version; beta tags must have a newer numeric version and do not change the stable baseline.

`RELEASE_PLEASE_TOKEN` needs repository contents, issues and pull-request write access. Both release workflows use it so their PR/release events can trigger CI and publishing (unlike the default Actions token). Do not edit release labels, tracked versions or release configuration during routine development, and do not use empty `Release-As:` commits to request betas.

If publishing fails after a tag/GitHub release was created, rerun the failed Release job. If stable preparation reports an outstanding merged pending PR, retry its failed stable preparation first; never remove a pending label to bypass an unpublished stable release.

Prereleases use padded labels such as `beta001`. Users must opt in when installing, for example:

```powershell
Install-Module PSLogs -AllowPrerelease
```

## Documentation publishing

Stable releases update getps.dev through `scripts/Update-Docs.ps1`. Generated command help, README and changelog belong in `modules/<ModuleName>` at the documentation repository root. The site's separate module-docs plugin reads this folder; `docs/modules` belongs to the Knowledge Base instead.

## Update build dependencies

1. Change the intended module version in [RequiredModules.psd1](RequiredModules.psd1).
2. Restore the pinned dependencies and verify the build:

```powershell
./build.ps1 -Task InstallDependencies
./build.ps1
```

The build uses these pinned dependencies from `output/RequiredModules`; you do not need to install them separately.

Pipeline kit: hanpq/PSModuleBuildReleaseTemplate@159c6cc887db52309f046016e415cd621fdc5c10
