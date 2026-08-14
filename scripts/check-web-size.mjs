import assert from "node:assert/strict";
import { createHash } from "node:crypto";
import {
  existsSync,
  readFileSync,
  readdirSync,
  statSync,
} from "node:fs";
import { gzipSync } from "node:zlib";
import { join, resolve } from "node:path";

const root = resolve(import.meta.dirname, "..");
const dist = resolve(
  process.argv[2] ?? join(root, "_build", "browser", "rabbita-todo"),
);
assert.ok(existsSync(dist), `browser release directory is missing: ${dist}`);

const baseline = JSON.parse(
  readFileSync(join(root, "benchmarks", "web-delivery.json"), "utf8"),
);
assert.equal(baseline.schemaVersion, 1);
const { budgets } = baseline;
const manifestPath = join(dist, "i18n", "manifest.json");
const manifestBytes = readFileSync(manifestPath);
const manifest = JSON.parse(manifestBytes);
assert.equal(manifest.manifestVersion, 1);
assert.equal(manifest.generator, "lampclaw/i18n");

const javascript = readdirSync(dist)
  .filter((name) => name.endsWith(".js"))
  .sort()
  .map((name) => readFileSync(join(dist, name)));
assert.ok(javascript.length > 0, "browser release contains no JavaScript");
const javascriptBytes = javascript.reduce((total, bytes) => total + bytes.length, 0);
const javascriptGzipBytes = javascript.reduce(
  (total, bytes) => total + gzipSync(bytes, { level: 9 }).length,
  0,
);

let embeddedLocaleBytes = 0;
let largestDynamicChunk = 0;
for (const chunk of manifest.chunks) {
  assert.match(chunk.path, /^[A-Za-z0-9._-]+\.json$/u);
  const path = join(dist, "i18n", chunk.path);
  assert.ok(statSync(path).isFile(), `catalog chunk is missing: ${chunk.path}`);
  const bytes = readFileSync(path);
  assert.equal(bytes.length, chunk.bytes, `chunk byte count drifted: ${chunk.path}`);
  assert.equal(
    createHash("sha256").update(bytes).digest("hex"),
    chunk.sha256,
    `chunk integrity drifted: ${chunk.path}`,
  );
  if (chunk.embeddedLocale) {
    embeddedLocaleBytes += bytes.length;
  } else {
    largestDynamicChunk = Math.max(largestDynamicChunk, bytes.length);
  }
}

const observed = {
  generatedJavaScript: javascriptBytes,
  generatedJavaScriptGzip: javascriptGzipBytes,
  embeddedLocaleChunks: embeddedLocaleBytes,
  dynamicChunk: largestDynamicChunk,
  deploymentManifest: manifestBytes.length,
};
for (const [name, value] of Object.entries(observed)) {
  const budget = budgets[name];
  assert.ok(Number.isInteger(budget) && budget > 0, `missing size budget: ${name}`);
  console.log(`${name}: ${value} bytes / ${budget} bytes`);
  assert.ok(value <= budget, `${name} exceeds its published size budget`);
}
