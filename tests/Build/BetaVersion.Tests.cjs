const { test } = require('node:test');
const assert = require('node:assert/strict');
const { mkdtempSync, readFileSync, rmSync } = require('node:fs');
const { tmpdir } = require('node:os');
const { join } = require('node:path');
const { getBetaVersion, main } = require('../../scripts/release-please/Get-BetaVersion.cjs');
const { GitHub, Manifest } = require('../../scripts/release-please/node_modules/release-please');

test('reads the planned version without creating PRs, tags, releases or labels', async () => {
  const calls = [];
  const manifest = new Proxy({
    repositoryConfig: { '.': { releaseType: 'simple' } },
    async buildPullRequests() {
      calls.push('buildPullRequests');
      return [{ version: { toString: () => '1.3.0' } }];
    },
  }, {
    get(target, name) {
      assert.ok(['repositoryConfig', 'buildPullRequests'].includes(name), `Unexpected manifest operation: ${String(name)}`);
      return target[name];
    },
  });
  assert.equal(await getBetaVersion(manifest), '1.3.0');
  assert.deepEqual(calls, ['buildPullRequests']);
});

for (const candidates of [
  [],
  [{ version: '1.3.0' }, { version: '2.0.0' }],
]) {
  test(`rejects missing or ambiguous root candidates: ${JSON.stringify(candidates)}`, async () => {
    await assert.rejects(getBetaVersion({
      repositoryConfig: { '.': {} },
      buildPullRequests: async () => candidates,
    }), /Expected one release candidate/);
  });
}

for (const version of [undefined, '1.3.0-beta001', '1.3', 'invalid']) {
  test(`rejects an invalid stable candidate: ${version}`, async () => {
    await assert.rejects(getBetaVersion({
      repositoryConfig: { '.': {} },
      buildPullRequests: async () => [{ version }],
    }), /Expected a stable release candidate/);
  });
}

test('surfaces planning failures', async () => {
  await assert.rejects(getBetaVersion({
    repositoryConfig: { '.': {} },
    buildPullRequests: async () => { throw new Error('GitHub API failed'); },
  }), /GitHub API failed/);
});

test('rejects non-root or multiple packages before planning', async () => {
  for (const repositoryConfig of [{ other: {} }, { '.': {}, other: {} }]) {
    await assert.rejects(getBetaVersion({ repositoryConfig }), /single root package/);
  }
});

function readOnlyGitHub(message) {
  return new Proxy({
    then: undefined,
    repository: { owner: 'example', repo: 'module', defaultBranch: 'main' },
    async getFileJson(path, branch) {
      assert.equal(branch, 'main');
      if (path === 'release-please-config.json') {
        return JSON.parse(readFileSync(join(__dirname, '../../release-please-config.json'), 'utf8'));
      }
      assert.equal(path, '.release-please-manifest.json');
      return { '.': '1.2.3' };
    },
    async *releaseIterator() {
      yield { tagName: 'v1.3.0-beta009', sha: 'preview' };
      yield { tagName: 'v1.2.3', sha: 'stable', notes: '' };
    },
    async *mergeCommitIterator() {
      yield { sha: 'new', message, files: ['source/public/Example.ps1'] };
      yield { sha: 'stable', message: 'chore(main): release 1.2.3', files: [] };
    },
  }, {
    get(target, name) {
      assert.ok(Object.hasOwn(target, name), `Unexpected GitHub operation: ${String(name)}`);
      return target[name];
    },
  });
}

for (const [message, expected] of [
  ['fix: repair behavior', '1.2.4'],
  ['feat: add behavior', '1.3.0'],
  ['feat!: change behavior', '2.0.0'],
  ['docs: explain behavior', null],
]) {
  test(`real Release Please infers ${expected} for ${message} using read-only GitHub operations`, async () => {
    const github = readOnlyGitHub(message);
    const manifest = await Manifest.fromManifest(github, 'main');
    if (expected) {
      assert.equal(await getBetaVersion(manifest), expected);
    } else {
      await assert.rejects(getBetaVersion(manifest), /Expected one release candidate/);
    }
  });
}

async function verifyEndpoint(endpoint, t) {
  const directory = mkdtempSync(join(tmpdir(), 'beta-inference-'));
  const environment = {
    GITHUB_REPOSITORY: 'example/module',
    GH_TOKEN: 'read-only-test-token',
    GITHUB_API_URL: endpoint.api,
    GITHUB_GRAPHQL_URL: endpoint.graphql,
    GITHUB_OUTPUT: join(directory, 'output'),
  };
  const saved = {};
  for (const [name, value] of Object.entries(environment)) {
    saved[name] = process.env[name];
    process.env[name] = value;
  }
  t.after(() => {
    for (const [name, value] of Object.entries(saved)) {
      if (value === undefined) delete process.env[name];
      else process.env[name] = value;
    }
    rmSync(directory, { recursive: true });
  });
  const createGitHub = GitHub.create.bind(GitHub);
  t.mock.method(GitHub, 'create', async options => {
    assert.deepEqual(options, {
      owner: 'example',
      repo: 'module',
      token: environment.GH_TOKEN,
      apiUrl: environment.GITHUB_API_URL,
      graphqlUrl: endpoint.base,
    });
    const requests = [];
    const client = await createGitHub({
      ...options,
      defaultBranch: 'main',
      fetch: async (url, request) => {
        requests.push({ url, method: request.method });
        assert.equal(url, endpoint.graphql);
        assert.equal(request.method, 'POST');
        assert.match(JSON.parse(request.body).query, /query releases\(/);
        return new Response(JSON.stringify({
          data: {
            repository: {
              releases: {
                nodes: [{
                  name: 'v1.2.3', tag: { name: 'v1.2.3' }, tagCommit: { oid: 'stable' },
                  url: 'https://github.example.test/example/module/releases/tag/v1.2.3',
                  description: '', isDraft: false,
                }],
                pageInfo: { hasNextPage: false, endCursor: null },
              },
            },
          },
        }), { status: 200, headers: { 'content-type': 'application/json' } });
      },
    });
    const releases = [];
    for await (const release of client.releaseIterator()) releases.push(release);
    assert.equal(releases[0].tagName, 'v1.2.3');
    assert.equal(requests.length, 1);
    return readOnlyGitHub('feat: add behavior');
  });
  await main();
  assert.equal(readFileSync(environment.GITHUB_OUTPUT, 'utf8'), 'version=1.3.0\n');
}

for (const endpoint of [
  { api: 'https://api.github.com', graphql: 'https://api.github.com/graphql', base: 'https://api.github.com' },
  { api: 'https://github.example.test/api/v3', graphql: 'https://github.example.test/api/graphql', base: 'https://github.example.test/api' },
]) {
  test(`writes the inferred version and requests the correct GraphQL endpoint: ${endpoint.graphql}`,
    t => verifyEndpoint(endpoint, t));
}
