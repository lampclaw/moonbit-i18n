import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";

const root = new URL("../", import.meta.url);
const read = path => readFile(new URL(path, root), "utf8");
const matrix = JSON.parse(await read("tests/unicode-mf2/requirements.json"));
const profile = JSON.parse(await read("tests/unicode-mf2/profile.json"));
const pin = (await read("tests/unicode-mf2/PINNED_COMMIT")).trim();

assert.equal(matrix.matrixVersion, 1);
assert.deepEqual(matrix.statusVocabulary, ["passed", "not-applicable", "blocked"]);
assert.equal(matrix.messageProfile, "unicode-mf2-ldml48.2-js-v1");
assert.equal(matrix.syntaxProfile, profile.syntaxProfile);
assert.equal(matrix.resolutionProfile, profile.resolutionProfile);
assert.equal(matrix.defaultFunctionProfile, profile.defaultFunctionProfile);
assert.equal(matrix.upstreamCommit, pin);

const evidenceCache = new Map();
async function verifyEvidence(owner, evidence) {
  assert.ok(Array.isArray(evidence) && evidence.length > 0, `${owner}: missing evidence`);
  for (const item of evidence) {
    assert.equal(typeof item.path, "string", `${owner}: invalid evidence path`);
    assert.equal(typeof item.contains, "string", `${owner}: invalid evidence anchor`);
    let source = evidenceCache.get(item.path);
    if (source === undefined) {
      source = await read(item.path);
      evidenceCache.set(item.path, source);
    }
    assert.ok(source.includes(item.contains), `${owner}: missing ${item.contains} in ${item.path}`);
  }
}

const ids = new Set();
const sections = new Set();
for (const requirement of matrix.requirements) {
  assert.match(requirement.id, /^MF2-[A-Z]+-[0-9]{3}$/u);
  assert.ok(!ids.has(requirement.id), `duplicate requirement id: ${requirement.id}`);
  ids.add(requirement.id);
  sections.add(requirement.section);
  assert.equal(requirement.status, "passed", `${requirement.id}: unexplained gap`);
  assert.ok(requirement.requirement.length >= 20, `${requirement.id}: requirement is underspecified`);
  await verifyEvidence(requirement.id, requirement.evidence);
}
for (const section of [
  "syntax",
  "data-model",
  "resolution",
  "fallback",
  "errors",
  "bidi",
  "universal-options",
  "markup",
  "locale",
  "limits",
  "authoring",
  "migration",
  "catalog-runtime",
  "extensions",
]) {
  assert.ok(sections.has(section), `missing normative section: ${section}`);
}

const expectedRegistry = new Map([
  ["string", []],
  ["number", [
    "select", "signDisplay", "useGrouping", "minimumIntegerDigits",
    "minimumFractionDigits", "maximumFractionDigits", "minimumSignificantDigits",
    "maximumSignificantDigits", "trailingZeroDisplay", "roundingPriority",
    "roundingIncrement", "roundingMode",
  ]],
  ["integer", [
    "select", "signDisplay", "useGrouping", "minimumIntegerDigits",
    "maximumSignificantDigits",
  ]],
  ["offset", ["add", "subtract"]],
  ["currency", [
    "currency", "currencySign", "currencyDisplay", "useGrouping",
    "minimumIntegerDigits", "fractionDigits", "minimumSignificantDigits",
    "maximumSignificantDigits", "trailingZeroDisplay", "roundingPriority",
    "roundingIncrement", "roundingMode",
  ]],
  ["percent", [
    "signDisplay", "useGrouping", "minimumFractionDigits", "maximumFractionDigits",
    "minimumSignificantDigits", "maximumSignificantDigits", "trailingZeroDisplay",
    "roundingPriority", "roundingMode",
  ]],
]);

assert.deepEqual(
  matrix.stableDefaultRegistry.map(entry => entry.function),
  [...expectedRegistry.keys()],
);
const registrySource = await read("runtime/mf2_default_functions.mbt");
for (const entry of matrix.stableDefaultRegistry) {
  assert.equal(entry.status, "passed", `${entry.function}: stable function gap`);
  const expectedOptions = expectedRegistry.get(entry.function);
  assert.deepEqual(entry.options, expectedOptions, `${entry.function}: option inventory drift`);
  if (entry.options.length > 0) {
    assert.equal(
      entry.evidenceAppliesToOptions,
      true,
      `${entry.function}: option evidence must be explicit`,
    );
  }
  await verifyEvidence(`:${entry.function}`, entry.evidence);
  assert.ok(registrySource.includes(`"${entry.function}"`), `missing function: ${entry.function}`);
  for (const option of entry.options) {
    assert.ok(registrySource.includes(`"${option}"`), `missing ${entry.function}.${option}`);
  }
}

for (const draft of matrix.draftRegistry) {
  assert.ok(["passed", "not-applicable"].includes(draft.status));
  assert.notEqual(draft.classification, "stable");
  if (draft.status === "not-applicable") {
    assert.ok(draft.rationale?.length >= 30, `${draft.function}: missing N/A rationale`);
  }
}
assert.ok(!JSON.stringify(matrix).includes('"status":"blocked"'));

process.stdout.write(
  `MF2 requirement matrix complete: ${matrix.requirements.length} normative rows, ` +
    `${[...expectedRegistry.values()].reduce((sum, options) => sum + options.length, 0)} stable options, ` +
    `${matrix.stableDefaultRegistry.length} stable functions\n`,
);
