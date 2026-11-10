const { Manifest } = require('release-please');
const { createGitHub } = require('./Get-BetaVersion.cjs');

async function prepareStableRelease(github, requestedVersion = '') {
  const version = requestedVersion.trim();
  if (version && !/^(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)$/.test(version)) {
    throw new Error('Release version must be a stable version such as 1.0.0, without v, prerelease or build metadata.');
  }
  const manifest = await Manifest.fromManifest(
    github, 'main', 'release-please-config.json', '.release-please-manifest.json',
    {}, '.', version || undefined
  );
  if (version) {
    const baseline = manifest.releasedVersions['.'];
    if (!baseline || baseline.preRelease || baseline.build) {
      throw new Error('Expected a stable root package baseline.');
    }
    const current = [baseline.major, baseline.minor, baseline.patch].map(BigInt);
    const requested = version.split('.').map(BigInt);
    const difference = requested.findIndex((part, index) => part !== current[index]);
    if (difference < 0 || requested[difference] < current[difference]) {
      throw new Error(`Release version ${version} must be newer than the stable baseline ${baseline}.`);
    }
  }
  const pulls = await manifest.createPullRequests();
  if (!pulls.some(Boolean)) {
    throw new Error('No stable release PR was prepared. Merge releasable Conventional Commits and retry.');
  }
  return pulls;
}

module.exports = { prepareStableRelease };

if (require.main === module) {
  createGitHub()
    .then(github => prepareStableRelease(github, process.env.RELEASE_VERSION || ''))
    .catch(error => {
      console.error(error.message);
      process.exitCode = 1;
    });
}
