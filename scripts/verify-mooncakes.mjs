import assert from "node:assert/strict";

const version = process.argv[2];
assert.ok(version, "usage: verify-mooncakes.mjs <published-version> [sha256]");
assert.match(version, /^0\.1\.0(?:-rc\.[1-9][0-9]*)?$/u);
const expectedChecksum = process.argv[3];
if (expectedChecksum) assert.match(expectedChecksum, /^[0-9a-f]{64}$/u);

const deadline = Date.now() + Number(process.env.LAMPCLAW_REGISTRY_WAIT_MS ?? 900_000);
const base = `https://assets.mooncakes.io/assets/lampclaw/i18n@${version}`;
const requiredPackages = ["cmd/i18n", "generator", "runtime", "runtime/js"];

const get = async (url) => {
  const response = await fetch(url, { signal: AbortSignal.timeout(30_000) });
  if (!response.ok) throw new Error(`${response.status} ${response.statusText}: ${url}`);
  return response;
};

const verify = async () => {
  const manifest = await (await get("https://mooncakes.io/api/v0/manifest/lampclaw/i18n")).json();
  assert.equal(manifest.version, version);
  assert.equal(manifest.build_status, "success");
  assert.equal(manifest.metadata.name, "lampclaw/i18n");
  assert.equal(manifest.metadata.version, version);
  assert.equal(manifest.metadata.repository, "https://github.com/lampclaw/moonbit-i18n");
  assert.equal(manifest.metadata.license, "Apache-2.0");
  assert.ok(manifest.metadata.description);
  if (expectedChecksum) assert.equal(manifest.metadata.checksum, expectedChecksum);

  const moduleResource = await (await get(`${base}/resource.json`)).json();
  assert.equal(moduleResource.kind, "module");
  assert.match(moduleResource.readme_content, /lampclaw\/i18n/u);
  if (process.env.LAMPCLAW_EXPECT_ROADMAP !== "0") {
    assert.match(moduleResource.readme_content, /product roadmap|产品路线图/u);
  }

  const moduleIndex = await (await get(`${base}/module_index.json`)).text();
  for (const path of requiredPackages) {
    assert.ok(moduleIndex.includes(`lampclaw/i18n/${path}`), `package missing from module index: ${path}`);
    const packageData = await (await get(`${base}/${path}/package_data.json`)).json();
    assert.equal(packageData.name, `lampclaw/i18n/${path}`);
  }

  await get(`https://download.mooncakes.io/user/lampclaw/i18n/${version}.zip`);
  console.log(`Mooncakes assets passed for lampclaw/i18n@${version}`);
};

let lastError;
while (Date.now() < deadline) {
  try {
    await verify();
    process.exit(0);
  } catch (error) {
    lastError = error;
    console.log(`Mooncakes assets not ready: ${error.message}`);
    await new Promise((resolve) => setTimeout(resolve, 15_000));
  }
}
throw lastError ?? new Error("Mooncakes verification timed out");
