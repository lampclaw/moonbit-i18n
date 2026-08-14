import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";

const root = new URL("../", import.meta.url);
const read = path => readFile(new URL(path, root), "utf8");

const pin = (await read("tests/unicode-mf2/PINNED_COMMIT")).trim();
const matrix = JSON.parse(await read("tests/unicode-mf2/profile.json"));
const requirements = JSON.parse(await read("tests/unicode-mf2/requirements.json"));
const differential = JSON.parse(
  await read("tests/unicode-mf2/differential-report.json"),
);
assert.match(pin, /^[0-9a-f]{40}$/u);
assert.equal(matrix.upstreamCommit, pin);
assert.equal(
  matrix.conformanceClaim,
  "unicode-mf2-syntax-data-model-resolution-and-stable-default-functions-js",
);
assert.equal(matrix.standardMessageProfile, "unicode-mf2-ldml48.2-js-v1");
assert.equal(matrix.authoringProfiles.compatibility, matrix.catalogProfile);
assert.equal(matrix.authoringProfiles.standards, matrix.standardMessageProfile);
assert.equal(requirements.messageProfile, matrix.standardMessageProfile);
assert.deepEqual(matrix.requirementMatrix, {
  path: "tests/unicode-mf2/requirements.json",
  normativeRows: requirements.requirements.length,
  stableFunctions: requirements.stableDefaultRegistry.length,
  stableOptions: requirements.stableDefaultRegistry.reduce(
    (sum, entry) => sum + entry.options.length,
    0,
  ),
  unexplainedGaps: 0,
});
assert.equal(differential.messageProfile, matrix.standardMessageProfile);
assert.equal(matrix.differential.cases, differential.totalCases);
assert.equal(matrix.differential.unexplainedSemanticFailures, 0);
assert.deepEqual(differential.unexplainedSemanticFailures, []);
assert.deepEqual(matrix.stableDefaultFunctions, [
  "string",
  "number",
  "integer",
  "offset",
  "currency",
  "percent",
]);
assert.deepEqual(matrix.implementedDraftFunctions, ["date", "time", "datetime"]);
assert.deepEqual(matrix.deferredDraftFunctions, ["unit"]);

const syntaxNames = ["syntax", "syntax-errors", "data-model-errors"];
const syntaxFixtures = await Promise.all(
  syntaxNames.map(name => read(`tests/unicode-mf2/upstream/test/tests/${name}.json`)),
);
const syntaxCounts = {
  wellFormed: JSON.parse(syntaxFixtures[0]).tests.length,
  syntaxErrors: JSON.parse(syntaxFixtures[1]).tests.length,
  dataModelCases: JSON.parse(syntaxFixtures[2]).tests.length,
};
assert.deepEqual(matrix.syntaxFixtureCounts, syntaxCounts);

const resolutionNames = ["fallback", "pattern-selection", "bidi", "u-options"];
const resolutionFixtures = await Promise.all(
  resolutionNames.map(name =>
    read(`tests/unicode-mf2/upstream/test/tests/${name}.json`),
  ),
);
const resolutionCounts = {
  fallback: JSON.parse(resolutionFixtures[0]).tests.length,
  patternSelection: JSON.parse(resolutionFixtures[1]).tests.length,
  bidi: JSON.parse(resolutionFixtures[2]).tests.length,
  unicodeOptions: JSON.parse(resolutionFixtures[3]).tests.length,
};
resolutionCounts.total = Object.values(resolutionCounts).reduce(
  (sum, value) => sum + value,
  0,
);
assert.deepEqual(matrix.resolutionFixtureCounts, resolutionCounts);

const functionNames = [
  "currency",
  "date",
  "datetime",
  "integer",
  "number",
  "offset",
  "percent",
  "string",
  "time",
];
const functionFixtures = await Promise.all(
  functionNames.map(name =>
    read(`tests/unicode-mf2/upstream/test/tests/functions/${name}.json`),
  ),
);
const functionCounts = {
  currency: JSON.parse(functionFixtures[0]).tests.length,
  dateDraft: JSON.parse(functionFixtures[1]).tests.length,
  datetimeDraft: JSON.parse(functionFixtures[2]).tests.length,
  integer: JSON.parse(functionFixtures[3]).tests.length,
  number: JSON.parse(functionFixtures[4]).tests.length,
  offset: JSON.parse(functionFixtures[5]).tests.length,
  percent: JSON.parse(functionFixtures[6]).tests.length,
  string: JSON.parse(functionFixtures[7]).tests.length,
  timeDraft: JSON.parse(functionFixtures[8]).tests.length,
};
functionCounts.total = Object.values(functionCounts).reduce(
  (sum, value) => sum + value,
  0,
);
assert.deepEqual(matrix.defaultFunctionFixtureCounts, functionCounts);

const sources = Object.fromEntries(
  await Promise.all(
    [
      "runtime/catalog.mbt",
      "generator/parser.mbt",
      "generator/generate.mbt",
      "runtime/mf2_syntax.mbt",
      "runtime/mf2_format.mbt",
      "runtime/mf2_registry.mbt",
      "runtime/mf2_default_functions.mbt",
      "runtime/js/formatter.mbt",
      "runtime/mf2_profile_test.mbt",
      "runtime/mf2_upstream_syntax_wbtest.mbt",
      "runtime/mf2_upstream_format_wbtest.mbt",
      "runtime/js/mf2_upstream_functions_test.mbt",
      "docs/mf2-profile.mbt.md",
      "docs/mf2-profile.zh-CN.mbt.md",
      "docs/mf2-syntax-data-model.mbt.md",
      "docs/mf2-syntax-data-model.zh-CN.mbt.md",
      "docs/mf2-resolution-formatting.mbt.md",
      "docs/mf2-resolution-formatting.zh-CN.mbt.md",
      "docs/mf2-default-functions.mbt.md",
      "docs/mf2-default-functions.zh-CN.mbt.md",
      "examples/rabbita_todo/localization/config.json",
    ].map(async path => [path, await read(path)]),
  ),
);

for (const path of [
  "runtime/catalog.mbt",
  "runtime/mf2_profile_test.mbt",
  "docs/mf2-profile.mbt.md",
  "docs/mf2-profile.zh-CN.mbt.md",
]) {
  assert.ok(sources[path].includes(matrix.catalogProfile), path);
}
for (const path of [
  "runtime/catalog.mbt",
  "docs/mf2-profile.mbt.md",
  "docs/mf2-profile.zh-CN.mbt.md",
  "examples/rabbita_todo/localization/config.json",
]) {
  assert.ok(sources[path].includes(matrix.standardMessageProfile), path);
}
assert.ok(
  sources["generator/parser.mbt"].includes("@runtime.MF2_STANDARD_MESSAGE_PROFILE"),
  "generator/parser.mbt: standards profile must use the runtime contract constant",
);
assert.ok(
  sources["generator/generate.mbt"].includes("profile=config.message_profile"),
  "generator/generate.mbt: selected profile must propagate into generated catalogs",
);
for (const path of [
  "runtime/mf2_syntax.mbt",
  "runtime/mf2_profile_test.mbt",
  "docs/mf2-profile.mbt.md",
  "docs/mf2-profile.zh-CN.mbt.md",
  "docs/mf2-syntax-data-model.mbt.md",
  "docs/mf2-syntax-data-model.zh-CN.mbt.md",
]) {
  assert.ok(sources[path].includes(matrix.syntaxProfile), path);
}
for (const path of [
  "runtime/mf2_format.mbt",
  "runtime/mf2_profile_test.mbt",
  "docs/mf2-profile.mbt.md",
  "docs/mf2-profile.zh-CN.mbt.md",
  "docs/mf2-resolution-formatting.mbt.md",
  "docs/mf2-resolution-formatting.zh-CN.mbt.md",
]) {
  assert.ok(sources[path].includes(matrix.resolutionProfile), path);
}
for (const path of [
  "runtime/mf2_registry.mbt",
  "runtime/mf2_profile_test.mbt",
  "docs/mf2-profile.mbt.md",
  "docs/mf2-profile.zh-CN.mbt.md",
  "docs/mf2-default-functions.mbt.md",
  "docs/mf2-default-functions.zh-CN.mbt.md",
]) {
  assert.ok(sources[path].includes(matrix.defaultFunctionProfile), path);
}
for (const path of [
  "runtime/mf2_profile_test.mbt",
  "runtime/mf2_upstream_syntax_wbtest.mbt",
  "runtime/mf2_upstream_format_wbtest.mbt",
  "runtime/js/mf2_upstream_functions_test.mbt",
  "docs/mf2-profile.mbt.md",
  "docs/mf2-profile.zh-CN.mbt.md",
  "docs/mf2-syntax-data-model.mbt.md",
  "docs/mf2-syntax-data-model.zh-CN.mbt.md",
  "docs/mf2-resolution-formatting.mbt.md",
  "docs/mf2-resolution-formatting.zh-CN.mbt.md",
  "docs/mf2-default-functions.mbt.md",
  "docs/mf2-default-functions.zh-CN.mbt.md",
]) {
  assert.ok(sources[path].includes(pin), path);
}

assert.match(sources["runtime/mf2_default_functions.mbt"], /"currency"/u);
assert.match(sources["runtime/mf2_default_functions.mbt"], /"datetime"/u);
assert.match(sources["runtime/js/formatter.mbt"], /Intl\.NumberFormat/u);
assert.match(sources["runtime/js/formatter.mbt"], /Intl\.PluralRules/u);
assert.match(sources["runtime/js/formatter.mbt"], /Intl\.DateTimeFormat/u);

process.stdout.write(
    `MF2 catalog profile synchronized: ${matrix.catalogProfile}\n` +
    `MF2 standards authoring profile synchronized: ${matrix.standardMessageProfile}\n` +
    `MF2 syntax profile synchronized: ${matrix.syntaxProfile}\n` +
    `MF2 resolution profile synchronized: ${matrix.resolutionProfile}\n` +
    `MF2 default registry synchronized: ${matrix.defaultFunctionProfile}\n` +
    `Pinned upstream commit: ${pin}\n` +
    `Pinned syntax/data-model fixtures: ${Object.values(syntaxCounts).reduce((a, b) => a + b, 0)} cases\n` +
    `Pinned resolution fixtures: ${resolutionCounts.total} cases\n` +
    `Pinned default-function fixtures: ${functionCounts.total} cases\n`,
);
