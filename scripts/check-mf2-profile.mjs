import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";

const root = new URL("../", import.meta.url);
const read = path => readFile(new URL(path, root), "utf8");

const [
  pinSource,
  matrixSource,
  runtimeSource,
  syntaxRuntimeSource,
  resolutionRuntimeSource,
  testSource,
  generatedTestSource,
  generatedFormatTestSource,
  docs,
  docsZh,
  syntaxDocs,
  syntaxDocsZh,
  resolutionDocs,
  resolutionDocsZh,
  syntaxFixture,
  syntaxErrorFixture,
  dataModelFixture,
  fallbackFixture,
  patternSelectionFixture,
  bidiFixture,
  unicodeOptionsFixture,
] =
  await Promise.all([
    read("tests/unicode-mf2/PINNED_COMMIT"),
    read("tests/unicode-mf2/profile.json"),
    read("runtime/catalog.mbt"),
    read("runtime/mf2_syntax.mbt"),
    read("runtime/mf2_format.mbt"),
    read("runtime/mf2_profile_test.mbt"),
    read("runtime/mf2_upstream_syntax_wbtest.mbt"),
    read("runtime/mf2_upstream_format_wbtest.mbt"),
    read("docs/mf2-profile.mbt.md"),
    read("docs/mf2-profile.zh-CN.mbt.md"),
    read("docs/mf2-syntax-data-model.mbt.md"),
    read("docs/mf2-syntax-data-model.zh-CN.mbt.md"),
    read("docs/mf2-resolution-formatting.mbt.md"),
    read("docs/mf2-resolution-formatting.zh-CN.mbt.md"),
    read("tests/unicode-mf2/upstream/test/tests/syntax.json"),
    read("tests/unicode-mf2/upstream/test/tests/syntax-errors.json"),
    read("tests/unicode-mf2/upstream/test/tests/data-model-errors.json"),
    read("tests/unicode-mf2/upstream/test/tests/fallback.json"),
    read("tests/unicode-mf2/upstream/test/tests/pattern-selection.json"),
    read("tests/unicode-mf2/upstream/test/tests/bidi.json"),
    read("tests/unicode-mf2/upstream/test/tests/u-options.json"),
  ]);

const pin = pinSource.trim();
const matrix = JSON.parse(matrixSource);
assert.match(pin, /^[0-9a-f]{40}$/u);
assert.equal(matrix.upstreamCommit, pin);
assert.equal(
  matrix.conformanceClaim,
  "unicode-mf2-syntax-data-model-and-resolution-core",
);
assert.ok(matrix.acceptedFeatures.length > 0);
assert.ok(matrix.rejectedFeatures.length > 0);
assert.ok(matrix.syntaxProfileAcceptedFeatures.length > 0);
assert.ok(matrix.syntaxProfileDeferredFeatures.length > 0);
assert.ok(matrix.resolutionProfileAcceptedFeatures.length > 0);
assert.ok(matrix.resolutionProfileDeferredFeatures.length > 0);

const fixtureCounts = {
  wellFormed: JSON.parse(syntaxFixture).tests.length,
  syntaxErrors: JSON.parse(syntaxErrorFixture).tests.length,
  dataModelCases: JSON.parse(dataModelFixture).tests.length,
};
assert.deepEqual(matrix.syntaxFixtureCounts, fixtureCounts);
const resolutionFixtureCounts = {
  fallback: JSON.parse(fallbackFixture).tests.length,
  patternSelection: JSON.parse(patternSelectionFixture).tests.length,
  bidi: JSON.parse(bidiFixture).tests.length,
  unicodeOptions: JSON.parse(unicodeOptionsFixture).tests.length,
};
resolutionFixtureCounts.total = Object.values(resolutionFixtureCounts).reduce(
  (sum, value) => sum + value,
  0,
);
assert.deepEqual(matrix.resolutionFixtureCounts, resolutionFixtureCounts);

for (const source of [runtimeSource, testSource, docs, docsZh]) {
  assert.ok(source.includes(matrix.catalogProfile));
}
for (const source of [
  syntaxRuntimeSource,
  testSource,
  docs,
  docsZh,
  syntaxDocs,
  syntaxDocsZh,
]) {
  assert.ok(source.includes(matrix.syntaxProfile));
}
for (const source of [
  resolutionRuntimeSource,
  testSource,
  docs,
  docsZh,
  resolutionDocs,
  resolutionDocsZh,
]) {
  assert.ok(source.includes(matrix.resolutionProfile));
}
for (const source of [
  testSource,
  generatedTestSource,
  docs,
  docsZh,
  syntaxDocs,
  syntaxDocsZh,
  generatedFormatTestSource,
  resolutionDocs,
  resolutionDocsZh,
]) {
  assert.ok(source.includes(pin));
}

process.stdout.write(
  `MF2 catalog profile synchronized: ${matrix.catalogProfile}\n` +
    `MF2 syntax profile synchronized: ${matrix.syntaxProfile}\n` +
    `MF2 resolution profile synchronized: ${matrix.resolutionProfile}\n` +
    `Pinned upstream commit: ${pin}\n` +
    `Pinned syntax fixtures: ${fixtureCounts.wellFormed} accepted, ${fixtureCounts.syntaxErrors} rejected, ${fixtureCounts.dataModelCases} data-model cases\n` +
    `Pinned resolution fixtures: ${resolutionFixtureCounts.total} cases\n`,
);
