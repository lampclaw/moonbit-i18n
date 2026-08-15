import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";

const root = new URL("../", import.meta.url);
const read = path => readFile(new URL(path, root), "utf8");

const pin = (await read("tests/unicode-mf2/PINNED_COMMIT")).trim();
const matrix = JSON.parse(await read("tests/unicode-mf2/profile.json"));
const requirements = JSON.parse(await read("tests/unicode-mf2/requirements.json"));
const standards = JSON.parse(await read("tests/unicode-mf2/standards.json"));
const differential = JSON.parse(
  await read("tests/unicode-mf2/differential-report.json"),
);

assert.match(pin, /^[0-9a-f]{40}$/u);
assert.equal(pin, "7f142fb4f1f5ea6ab1eb34ce2b87e918ca9fd331");
assert.equal(matrix.upstreamTag, "LDML48.2");
assert.equal(matrix.upstreamCommit, pin);
assert.equal(matrix.standardsFreeze, "tests/unicode-mf2/standards.json");
assert.deepEqual(standards.messageFormat, {
  standard: "Unicode LDML Part 9: MessageFormat",
  ldmlVersion: "48.2",
  reportRevision: 78,
  report: "https://www.unicode.org/reports/tr35/tr35-78/tr35-messageFormat.html",
  repository: "https://github.com/unicode-org/message-format-wg",
  tag: "LDML48.2",
  commit: pin,
});
assert.equal(standards.cldr.version, "48.2");
assert.equal(standards.cldr.tag, "release-48-2");
assert.equal(standards.cldr.commit, "11299982335beb974c1c63c45265184e759c0f41");
assert.equal(standards.cldrJson.version, "48.2.0");
assert.equal(standards.javascriptHost.node, "26.7.0");

assert.equal(
  matrix.conformanceClaim,
  "unicode-mf2-ldml48.2-stable-js-release-candidate",
);
assert.equal(matrix.standardMessageProfile, "unicode-mf2-ldml48.2-js-v2");
assert.equal(matrix.legacyStandardMessageProfile, "unicode-mf2-ldml48.2-js-v1");
assert.equal(
  matrix.experimentalDatetimeMessageProfile,
  "unicode-mf2-ldml48.2-js-v2+experimental-datetime-v1",
);
assert.equal(matrix.authoringProfiles.compatibility, matrix.catalogProfile);
assert.equal(matrix.authoringProfiles.standards, matrix.standardMessageProfile);
assert.equal(
  matrix.authoringProfiles.legacyStandards,
  matrix.legacyStandardMessageProfile,
);
assert.equal(
  matrix.authoringProfiles.experimentalDatetime,
  matrix.experimentalDatetimeMessageProfile,
);
assert.equal(requirements.messageProfile, matrix.standardMessageProfile);
assert.equal(
  requirements.experimentalDatetimeProfile,
  matrix.experimentalDatetimeMessageProfile,
);
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
assert.equal(
  differential.experimentalDatetimeProfile,
  matrix.experimentalDatetimeMessageProfile,
);
assert.equal(matrix.differential.cases, differential.totalCases);
assert.equal(matrix.differential.stableCases, differential.stableCases.length);
assert.equal(
  matrix.differential.experimentalDatetimeCases,
  differential.experimentalDatetimeCases.length,
);
assert.equal(matrix.differential.unexplainedSemanticFailures, 0);
assert.deepEqual(differential.unexplainedSemanticFailures, []);
assert.equal(differential.host.node, "26.7.0");
assert.equal(differential.stableCases.length, 20);
assert.equal(differential.experimentalDatetimeCases.length, 4);

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
assert.equal(
  matrix.browserConformance.syntaxAndDataModelCases,
  Object.values(syntaxCounts).reduce((sum, value) => sum + value, 0),
);

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
assert.equal(matrix.browserConformance.resolutionCases, resolutionCounts.total);

const functionNames = [
  "currency", "date", "datetime", "integer", "number", "offset", "percent", "string", "time",
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
functionCounts.stableTotal = [
  "currency", "integer", "number", "offset", "percent", "string",
].reduce((sum, name) => sum + functionCounts[name], 0);
functionCounts.experimentalDatetimeTotal =
  functionCounts.dateDraft + functionCounts.datetimeDraft + functionCounts.timeDraft;
functionCounts.total =
  functionCounts.stableTotal + functionCounts.experimentalDatetimeTotal;
assert.deepEqual(matrix.defaultFunctionFixtureCounts, functionCounts);
assert.equal(
  matrix.browserConformance.stableDefaultFunctionCases,
  functionCounts.stableTotal,
);
assert.equal(
  matrix.browserConformance.experimentalDatetimeCases,
  functionCounts.experimentalDatetimeTotal,
);
assert.equal(matrix.browserConformance.differentialCases, differential.totalCases);
assert.deepEqual(matrix.browserConformance.engines, ["chromium", "firefox", "webkit"]);

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
      "tests/browser/mf2-conformance.spec.mjs",
      "tests/mf2-browser/main.mbt",
    ].map(async path => [path, await read(path)]),
  ),
);

for (const profile of [
  matrix.catalogProfile,
  matrix.standardMessageProfile,
  matrix.legacyStandardMessageProfile,
  matrix.experimentalDatetimeMessageProfile,
]) {
  assert.ok(sources["runtime/catalog.mbt"].includes(profile), profile);
  assert.ok(sources["docs/mf2-profile.mbt.md"].includes(profile), profile);
  assert.ok(sources["docs/mf2-profile.zh-CN.mbt.md"].includes(profile), profile);
}
assert.ok(
  sources["generator/parser.mbt"].includes("@runtime.MF2_STANDARD_MESSAGE_PROFILE"),
  "generator/parser.mbt: standards profile must use the runtime contract constant",
);
assert.ok(
  sources["generator/generate.mbt"].includes("profile=config.message_profile"),
  "generator/generate.mbt: selected profile must propagate into generated catalogs",
);
for (const [profileName, paths] of [
  [matrix.syntaxProfile, ["runtime/mf2_syntax.mbt", "docs/mf2-syntax-data-model.mbt.md", "docs/mf2-syntax-data-model.zh-CN.mbt.md"]],
  [matrix.resolutionProfile, ["runtime/mf2_format.mbt", "docs/mf2-resolution-formatting.mbt.md", "docs/mf2-resolution-formatting.zh-CN.mbt.md"]],
  [matrix.defaultFunctionProfile, ["runtime/mf2_registry.mbt", "docs/mf2-default-functions.mbt.md", "docs/mf2-default-functions.zh-CN.mbt.md"]],
]) {
  for (const path of paths) assert.ok(sources[path].includes(profileName), path);
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
assert.ok(
  sources["examples/rabbita_todo/localization/config.json"].includes(
    matrix.experimentalDatetimeMessageProfile,
  ),
  "Rabbita must explicitly select experimental datetime",
);
for (const token of ["270", "67", "104", "20", "24"]) {
  assert.ok(sources["tests/browser/mf2-conformance.spec.mjs"].includes(token));
}
assert.match(sources["runtime/mf2_default_functions.mbt"], /"currency"/u);
assert.match(sources["runtime/mf2_default_functions.mbt"], /"datetime"/u);
assert.match(sources["runtime/js/formatter.mbt"], /Intl\.NumberFormat/u);
assert.match(sources["runtime/js/formatter.mbt"], /Intl\.PluralRules/u);
assert.match(sources["runtime/js/formatter.mbt"], /Intl\.DateTimeFormat/u);

process.stdout.write(
  `MF2 stable profile synchronized: ${matrix.standardMessageProfile}\n` +
    `MF2 experimental datetime profile synchronized: ${matrix.experimentalDatetimeMessageProfile}\n` +
    `Pinned stable upstream: ${matrix.upstreamTag} (${pin})\n` +
    `Anchored normative requirements: ${requirements.requirements.length}; blockers: 0\n` +
    `Browser conformance: ${matrix.browserConformance.engines.join(", ")}\n`,
);
