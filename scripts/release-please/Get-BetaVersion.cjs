const { appendFileSync } = require('node:fs');

async function getBetaVersion(manifest) {
  const paths = Object.keys(manifest.repositoryConfig);
  if (paths.length !== 1 || paths[0] !== '.') {
    throw new Error('Beta inference requires a single root package.');
  }
  const candidates = await manifest.buildPullRequests();
  if (candidates.length !== 1) {
    throw new Error('Expected one release candidate for the root package. Merge releasable Conventional Commits and rerun Publish beta.');
  }
  const version = candidates[0].version?.toString();
  if (!version || !/^\d+\.\d+\.\d+$/.test(version)) {
    throw new Error(`Expected a stable release candidate, received '${version}'.`);
  }
  return version;
}

async function createGitHub() {
  const { GITHUB_REPOSITORY, GH_TOKEN, GITHUB_API_URL, GITHUB_GRAPHQL_URL } = process.env;
  if (!GITHUB_REPOSITORY || !GH_TOKEN || !GITHUB_API_URL || !GITHUB_GRAPHQL_URL) {
    throw new Error('GITHUB_REPOSITORY, GH_TOKEN, GITHUB_API_URL and GITHUB_GRAPHQL_URL are required.');
  }
  const { GitHub } = require('release-please');
  const [owner, repo] = GITHUB_REPOSITORY.split('/');
  return GitHub.create({
    owner,
    repo,
    token: GH_TOKEN,
    apiUrl: GITHUB_API_URL,
    // Release Please passes this as Octokit's base URL, which appends /graphql.
    graphqlUrl: GITHUB_GRAPHQL_URL.replace(/\/graphql\/?$/, ''),
  });
}

async function main() {
  const { GITHUB_OUTPUT } = process.env;
  if (!GITHUB_OUTPUT) throw new Error('GITHUB_OUTPUT is required.');
  const { Manifest } = require('release-please');
  const github = await createGitHub();
  const manifest = await Manifest.fromManifest(
    github, 'main', 'release-please-config.json', '.release-please-manifest.json'
  );
  const version = await getBetaVersion(manifest);
  appendFileSync(GITHUB_OUTPUT, `version=${version}\n`);
}

module.exports = { getBetaVersion, createGitHub, main };

if (require.main === module) {
  main().catch(error => {
    console.error(error.message);
    process.exitCode = 1;
  });
}
