const { test } = require('node:test');
const assert = require('node:assert/strict');
const { readFileSync } = require('node:fs');
const { join } = require('node:path');
const { Manifest } = require('../../scripts/release-please/node_modules/release-please');
const { prepareStableRelease } = require('../../scripts/release-please/Prepare-StableRelease.cjs');

function githubFixture(baseline = '1.2.3') {
  return new Proxy({
    repository: { owner: 'example', repo: 'module', defaultBranch: 'main' },
    async getFileJson(path, branch) {
      assert.equal(branch, 'main');
      if (path === 'release-please-config.json') {
        return JSON.parse(readFileSync(join(__dirname, '../../release-please-config.json'), 'utf8'));
      }
      assert.equal(path, '.release-please-manifest.json');
      return { '.': baseline };
    },
    async *releaseIterator() {
      yield { tagName: `v${baseline}`, sha: 'stable', notes: '' };
    },
    async *mergeCommitIterator() {
      yield { sha: 'new', message: 'fix: repair behavior', files: ['source/public/Example.ps1'] };
      yield { sha: 'stable', message: `chore(main): release ${baseline}`, files: [] };
    },
  }, {
    get(target, name) {
      assert.ok(Object.hasOwn(target, name), `Unexpected GitHub operation: ${String(name)}`);
      return target[name];
    },
  });
}

for (const [requested, expected] of [['', '1.2.4'], ['  ', '1.2.4'], ['2.0.0', '2.0.0'], [' 1.10.0 ', '1.10.0']]) {
  test(`prepares only a PR for '${requested}' using planned version ${expected}`, async t => {
    t.mock.method(Manifest.prototype, 'createReleases', () => {
      assert.fail('Preparation must never publish a release');
    });
    t.mock.method(Manifest.prototype, 'createPullRequests', async function () {
      const candidates = await this.buildPullRequests();
      assert.equal(candidates.length, 1);
      assert.equal(candidates[0].version.toString(), expected);
      const update = candidates[0].updates.find(item => item.path === '.release-please-manifest.json');
      const content = update.updater.updateContent('{".":"1.2.3"}');
      assert.equal(JSON.parse(content)['.'], expected);
      return [{ number: 42 }];
    });
    assert.deepEqual(await prepareStableRelease(githubFixture(), requested), [{ number: 42 }]);
  });
}

for (const version of ['v2.0.0', '2.0.0-beta001', '2.0.0+build', '2.0', '02.0.0', 'invalid', '2.0.0\nrun-command']) {
  test(`rejects invalid input '${version}' before any API operation`, async () => {
    await assert.rejects(prepareStableRelease(githubFixture(), version), /must be a stable version/);
  });
}

for (const version of ['1.2.3', '1.2.2', '1.1.9', '0.9.9']) {
  test(`rejects non-increasing version ${version} before PR creation`, async t => {
    t.mock.method(Manifest.prototype, 'createPullRequests', () => assert.fail('Must validate first'));
    await assert.rejects(prepareStableRelease(githubFixture(), version), /must be newer/);
  });
}

test('rejects a prerelease baseline', async () => {
  await assert.rejects(prepareStableRelease(githubFixture('1.2.3-beta001'), '2.0.0'), /stable root package baseline/);
});

test('reports when no PR was prepared', async t => {
  t.mock.method(Manifest.prototype, 'createPullRequests', async () => []);
  await assert.rejects(prepareStableRelease(githubFixture()), /No stable release PR was prepared/);
});

test('propagates GitHub errors', async t => {
  t.mock.method(Manifest.prototype, 'createPullRequests', async () => { throw new Error('GitHub API failed'); });
  await assert.rejects(prepareStableRelease(githubFixture()), /GitHub API failed/);
});
