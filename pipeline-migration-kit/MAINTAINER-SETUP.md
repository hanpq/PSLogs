# Maintainer setup checklist

These are the steps an AI agent cannot do in the repository. Do them for each migrated module.

## 1. Run the migration

1. In PSLogs, export a fresh kit:

   ```powershell
   ./pipeline-migration-kit/Export-PipelineKit.ps1
   ```

   It writes a complete kit to `output/pipeline-migration-kit/`. Copy that folder, not the `pipeline-migration-kit/` source folder, which only holds the documents. To export straight into the target repository instead, use `-OutputPath D:\Repos\<Module>\pipeline-migration-kit`. The output folder is deleted and recreated on every export.

2. Copy `output/pipeline-migration-kit/` to the root of the target repository (skip this if you used `-OutputPath`).
3. In the target repository, ask the AI agent:

   > Follow `pipeline-migration-kit/AI-MIGRATION.md` to replace the build and release pipeline in this repository.

4. Review the agent's summary and the diff. Answer any questions it stopped on.
5. Push the branch, open a PR, check that CI passes and merge it. The migration commit uses `build:` and does not request a release.

## 2. Repository secrets

**Settings → Secrets and variables → Actions → Repository secrets.**

| Secret | Required | Value |
| --- | --- | --- |
| `RELEASE_PLEASE_TOKEN` | Yes | Fine-grained personal access token from your account with access to this repository and **Contents**, **Pull requests** and **Issues** set to read and write. One token can cover several repositories, including private ones. Release PRs must be created by the token owner; finalization checks this. |
| `GALLERYAPITOKEN` | Gallery modules | PowerShell Gallery API key with push rights for this module. Not used when the agent removed Gallery publishing. |
| `CODECOV_TOKEN` | Yes | Upload token from Codecov for this repository. Private repositories cannot upload without it. |
| `GITHUBTOKEN` | Gallery modules, for docs | Token with **Contents** read and write on `hanpq/getps.dev`. Without it, stable releases skip the getps.dev docs update. Not used when the agent removed the docs steps. |
| `PSTOOLS_APITOKEN` | ProGet | ProGet API key. Optional for Gallery modules (ProGet publishing is skipped without it); required for ProGet-only modules. |
| `PSTOOLS_SOURCE` | With ProGet | ProGet feed URL. Required when `PSTOOLS_APITOKEN` is set. |

The agent's summary lists the module profile and which of these secrets the migrated workflows use. The **Pipeline customizations** section in the module's `BUILDING.md` shows the same.

Delete secrets from the old pipeline that are no longer used: `PFX_BASE64`, `PFX_PASS`, `PSTOOLS_USER`, `PSTOOLS_PASS`, and anything else the agent's summary lists as unused.

Fine-grained tokens expire. When one does, releases or docs updates fail, so note the expiry dates.

## 3. Repository settings

**Settings → General → Pull Requests:**

- Allow squash merging, with **Default commit message** set to **Pull request title**.
- Allow merge commits if you want them. Disable **Allow rebase merging**; a stable promotion must be merged with squash or a merge commit.

**Settings → Actions → General:**

- Allow GitHub Actions and the actions used by the workflows (`actions/checkout`, `codecov/codecov-action`, `googleapis/release-please-action`).
- Workflow permissions can stay at read-only. The workflows request what they need and use `RELEASE_PLEASE_TOKEN` for release work.

**Branch protection (optional):** if you protect `main` and require status checks, use the CI job names that remain in `ci.yml` (by default `Linux PowerShell`, `macOS PowerShell`, `Windows PowerShell`, `Windows PowerShell Desktop`) and `Build and release infrastructure`. Requiring pull requests blocks direct pushes to `main`.

**Codecov:** make sure the repository is enabled in Codecov.

**PowerShell Gallery:** for Gallery modules, make sure the `GALLERYAPITOKEN` key can push this module name.

**Private repositories:** the workflows need no changes, but check these:

- **Codecov:** coverage of a private repository is only visible to people with access to the repository. The free Developer plan covers private repositories for one user, with a monthly limit on private uploads (250 when this was written). Every CI run uploads once per OS target, so a run with all four targets uses four. If you hit the limit or do not want Codecov, the upload step only warns; the build's own coverage target still applies. Codecov badges for private repositories need the badge token from the repository's Codecov settings.
- **GitHub Actions minutes:** private repositories use the account's included minutes (2,000 per month on the free plan). Windows minutes count double and macOS minutes ten times, so the macOS target is by far the most expensive.
- **Branch protection and rulesets** on private repositories require a paid GitHub plan.
- **Badges:** shields.io badges cannot read private repositories. The agent switches the CI badge to GitHub's own badge.

## 4. Clean up after the old pipeline

- Close open pull requests created by the old pipeline (changelog or docs PRs) and delete their branches.
- Check that the latest release has both a `vX.Y.Z` tag and a published GitHub release. The agent stops if it cannot confirm this.

## 5. First release

The first release after the migration must be a beta. Stable promotion needs a published beta.

1. Merge at least one `fix:` or `feat:` change. Release Please only prepares a release when there are releasable commits.
2. **Actions → Prepare release → Run workflow → `beta`.**
3. Review the release PR's version and notes, wait for CI and merge it.
4. Check that the **Release** workflow succeeded, the GitHub release has a ZIP and the prerelease appears in the PowerShell Gallery or ProGet.
5. When ready, run **Prepare release → `stable`**, review and merge the stable promotion PR, and check the Gallery or ProGet, and getps.dev for public modules.

See `BUILDING.md` in the migrated repository for the day-to-day cheat sheet.

## Updating a migrated repository later

When the PSLogs pipeline changes, export a new kit, copy it to the target repository and ask the agent to follow `AI-MIGRATION.md`. It detects that the repository is already migrated and switches to update mode. The `Pipeline kit:` line at the end of `BUILDING.md` shows which PSLogs commit each repository was last updated from.
