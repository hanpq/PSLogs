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

### VS Code shortcuts

- **Ctrl+Shift+B** runs `Verify` (build and tests). **Tasks: Run Task** also offers `build`, `test`, and `package`; `test` rebuilds first.
- Select **PowerShell Debug Module (build first)** and press **F5**. It builds, then runs [ModuleDebug.ps1](ModuleDebug.ps1) in a temporary PowerShell console, avoiding stale module state. Keep manual end-user scenarios and breakpoints in that script.
- To step into module functions, set breakpoints in the generated `output/PSLogs/<version>/PSLogs.psm1` after building. Rebuilds replace this file; edit only `source/`. Background logging runs in a separate runspace and is not stepped through by the normal script debugger.

Tasks require PowerShell 7 (`pwsh` on PATH). Debugging requires the VS Code PowerShell extension and uses its selected PowerShell session.

For background logging, run the script in a regular PowerShell terminal, then use **PowerShell Attach to Logging** and select its process. This targets the named `LoggingQueueConsumer` runspace. **PowerShell Attach to Runspace** instead prompts for both process and runspace.

## Submit a change

1. Make and test your change on a branch.
2. Open a pull request against `main`. CI runs for pull requests and pushes to `main`.
3. Use a Conventional Commit title for changes that should trigger a release. `feat:` requests a minor release; `fix:` and `perf:` request a patch; `!` or a `BREAKING CHANGE:` footer requests a major release. `docs:`, `test:`, and `chore:` do not trigger releases.
4. Squash-merge using the PR title as the commit message so Release Please can determine the correct version and generate release notes.

## Release channel cheat sheet

| How it starts | Channel | What happens |
| --- | --- | --- |
| Push or merge to `main` | Beta | Release Please opens or updates the beta release PR when conventional commits warrant one. |
| **Actions → Release Please → Run workflow → `beta`** | Beta | Runs the same beta release check manually. |
| **Actions → Release Please → Run workflow → `stable`** | Stable promotion | Opens a stable promotion PR for the latest published beta, even when there have been zero commits since it. |

Review the release PR version and notes, wait for CI, and merge it to publish. The release PR remains the gate for both channels. A stable promotion requires the latest beta to be published and `main` to have no commits after that beta; merge any pending beta release first. It creates a metadata-only release PR, so no config toggle or dummy fix commit is needed. Stable notes roll up beta entries since the previous stable release; beta entries remain in the changelog. Missing or unrecognized release boundaries fail the workflow instead of silently omitting notes.

An open stable promotion is protected from automatic beta runs. When it merges, the `stable-promotion` label selects the checked-in stable Release Please configuration for tag/release creation; beta pushes continue using the beta configuration. The release workflow checks that the immutable tag, tracked version, GitHub prerelease flag, and built module manifest agree before publishing.

The release workflow builds and tests the tag, attaches a ZIP to the GitHub release, and publishes the module to the PowerShell Gallery. Do not edit `.release-please-manifest.json` or toggle release configuration during routine development.

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
