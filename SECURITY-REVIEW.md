# GitHub Actions Security Review

## Scope

This review focused on whether forked pull requests can access repository secrets or write privileges through GitHub Actions, and on closely related release-workflow risks. Repository and organization settings in GitHub were not available for inspection.

## Summary

The pull-request CI pattern uses `pull_request` with `contents: read` and does not use `pull_request_target`. No direct path was identified for a forked pull request to access repository secrets or write privileges.

One high-severity risk was identified in the release workflow:

| # | Severity | File | Lines | Finding | Confidence |
|---|---|---|---|---|---|
| 1 | HIGH | `.github/workflows/release.yml` | 8–18, 31–37, 138–144 | The release job grants `contents: write`, checks out the release tag with checkout credentials persisted by default, and then runs repository-controlled build, test, and documentation code. If untrusted code is merged and included in a release, it could access the write-capable checkout credential. Documentation code also runs with `DOCS_GITHUB_TOKEN` available in its environment. | 8/10 |

## Recommendations

- Separate build and test from publishing. Run repository-controlled build/test code with read-only permissions and disable persisted checkout credentials where they are not needed.
- Keep publishing credentials out of jobs that execute repository-controlled code. Use a narrowly scoped publishing job and pass only the required artifacts into it.
- Protect release tags and restrict who can publish releases. Consider requiring approval for release credentials through a protected GitHub environment.
- In GitHub repository settings, verify fork pull-request workflows are not granted write tokens or secrets, and retain an approval requirement for workflows from outside contributors.

## Limitations

This was a review of repository workflow files, not a verification of GitHub repository or organization settings. Confirm the settings and secret access policies in GitHub separately.
