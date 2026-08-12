import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";

const root = new URL("../", import.meta.url);
const read = path => readFile(new URL(path, root), "utf8");

const [pinSource, matrixSource, runtimeSource, testSource, docs, docsZh] =
  await Promise.all([
    read("tests/unicode-mf2/PINNED_COMMIT"),
    read("tests/unicode-mf2/profile.json"),
    read("runtime/catalog.mbt"),
    read("runtime/mf2_profile_test.mbt"),
    read("docs/mf2-profile.mbt.md"),
    read("docs/mf2-profile.zh-CN.mbt.md"),
  ]);

const pin = pinSource.trim();
const matrix = JSON.parse(matrixSource);
assert.match(pin, /^[0-9a-f]{40}$/u);
assert.equal(matrix.upstreamCommit, pin);
assert.equal(
  matrix.conformanceClaim,
  "strict-project-subset-not-unicode-mf2-conformance",
);
assert.ok(matrix.acceptedFeatures.length > 0);
assert.ok(matrix.rejectedFeatures.length > 0);

for (const source of [runtimeSource, testSource, docs, docsZh]) {
  assert.ok(source.includes(matrix.catalogProfile));
}
for (const source of [testSource, docs, docsZh]) {
  assert.ok(source.includes(pin));
}

process.stdout.write(
  `MF2 profile synchronized: ${matrix.catalogProfile}\n` +
    `Pinned upstream commit: ${pin}\n` +
    `Accepted groups: ${matrix.acceptedFeatures.length}; rejected groups: ${matrix.rejectedFeatures.length}\n`,
);
