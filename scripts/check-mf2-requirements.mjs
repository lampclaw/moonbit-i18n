import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";

const root = new URL("../", import.meta.url);
const read = path => readFile(new URL(path, root), "utf8");
const matrix = JSON.parse(await read("tests/unicode-mf2/requirements.json"));
const profile = JSON.parse(await read("tests/unicode-mf2/profile.json"));
const standards = JSON.parse(await read("tests/unicode-mf2/standards.json"));
const pin = (await read("tests/unicode-mf2/PINNED_COMMIT")).trim();

assert.equal(matrix.matrixVersion, 2);
assert.equal(matrix.coverageModel, "normative-section-and-algorithm");
assert.deepEqual(matrix.statusVocabulary, ["passed", "not-applicable", "blocked"]);
assert.equal(matrix.messageProfile, "unicode-mf2-ldml48.2-js-v2");
assert.equal(
  matrix.experimentalDatetimeProfile,
  "unicode-mf2-ldml48.2-js-v2+experimental-datetime-v1",
);
assert.equal(matrix.syntaxProfile, profile.syntaxProfile);
assert.equal(matrix.resolutionProfile, profile.resolutionProfile);
assert.equal(matrix.defaultFunctionProfile, profile.defaultFunctionProfile);
assert.equal(matrix.upstreamTag, standards.messageFormat.tag);
assert.equal(matrix.upstreamCommit, pin);
assert.equal(standards.messageFormat.commit, pin);

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

const evidenceGroups = new Map(Object.entries(matrix.evidenceGroups));
assert.ok(evidenceGroups.size >= 8, "requirement matrix has too few evidence groups");
for (const [name, evidence] of evidenceGroups) {
  await verifyEvidence(`evidence group ${name}`, evidence);
}

const sourceCache = new Map();
async function verifySourceAnchor(requirement) {
  assert.equal(typeof requirement.source?.path, "string", `${requirement.id}: missing source path`);
  assert.equal(typeof requirement.source?.anchor, "string", `${requirement.id}: missing source anchor`);
  const path = `tests/unicode-mf2/upstream/${requirement.source.path}`;
  let source = sourceCache.get(path);
  if (source === undefined) {
    source = await read(path);
    sourceCache.set(path, source);
  }
  assert.ok(
    source.includes(requirement.source.anchor),
    `${requirement.id}: missing normative anchor ${requirement.source.anchor} in ${path}`,
  );
}

function requirementEvidence(requirement) {
  assert.ok(
    Array.isArray(requirement.evidenceGroups) && requirement.evidenceGroups.length > 0,
    `${requirement.id}: passed requirement has no evidence groups`,
  );
  const combined = [];
  for (const name of requirement.evidenceGroups) {
    assert.ok(evidenceGroups.has(name), `${requirement.id}: unknown evidence group ${name}`);
    combined.push(...evidenceGroups.get(name));
  }
  return combined;
}

const ids = new Set();
const sections = new Set();
const sourceAnchors = new Set();
for (const requirement of matrix.requirements) {
  assert.match(requirement.id, /^MF2-[A-Z]+-[0-9]{3}$/u);
  assert.ok(!ids.has(requirement.id), `duplicate requirement id: ${requirement.id}`);
  ids.add(requirement.id);
  sections.add(requirement.section);
  assert.ok(
    matrix.statusVocabulary.includes(requirement.status),
    `${requirement.id}: invalid status ${requirement.status}`,
  );
  assert.ok(requirement.requirement.length >= 20, `${requirement.id}: requirement is underspecified`);
  await verifySourceAnchor(requirement);
  sourceAnchors.add(`${requirement.source.path}#${requirement.source.anchor}`);
  if (requirement.status === "passed") {
    await verifyEvidence(requirement.id, requirementEvidence(requirement));
  } else if (requirement.status === "not-applicable") {
    assert.ok(requirement.rationale?.length >= 50, `${requirement.id}: missing public N/A rationale`);
    assert.ok(
      !requirement.evidenceGroups || requirement.evidenceGroups.length === 0,
      `${requirement.id}: N/A requirement must not masquerade as passed evidence`,
    );
  } else {
    assert.fail(`blocked requirement: ${requirement.id} — ${requirement.requirement}`);
  }
}

assert.ok(matrix.requirements.length >= 70, "normative audit regressed to summary-only rows");
assert.equal(sourceAnchors.size, matrix.requirements.length, "normative source anchors must be one-to-one");
for (const section of [
  "conformance",
  "stability",
  "syntax",
  "data-model",
  "formatting-context",
  "resolved-values",
  "resolution",
  "selection",
  "fallback",
  "bidi",
  "errors",
  "universal-options",
  "default-functions",
  "extensions",
  "number-selection",
  "draft-unit",
  "draft-datetime",
  "security",
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
    assert.equal(entry.evidenceAppliesToOptions, true, `${entry.function}: option evidence must be explicit`);
  }
  await verifyEvidence(`:${entry.function}`, requirementEvidence({
    id: `:${entry.function}`,
    evidenceGroups: entry.evidenceGroups,
  }));
  assert.ok(registrySource.includes(`"${entry.function}"`), `missing function: ${entry.function}`);
  for (const option of entry.options) {
    assert.ok(registrySource.includes(`"${option}"`), `missing ${entry.function}.${option}`);
  }
}

assert.deepEqual(matrix.draftRegistry.map(entry => entry.function), [
  "date", "time", "datetime", "unit",
]);
for (const draft of matrix.draftRegistry) {
  assert.equal(draft.status, "not-applicable", `${draft.function}: Draft leaked into stable claim`);
  assert.notEqual(draft.classification, "stable");
  assert.ok(draft.rationale?.length >= 50, `${draft.function}: missing N/A rationale`);
}

const blocked = matrix.requirements.filter(entry => entry.status === "blocked");
assert.deepEqual(blocked, [], "release has blocked normative requirements");

process.stdout.write(
  `MF2 requirement matrix complete: ${matrix.requirements.length} anchored normative rows, ` +
    `${[...expectedRegistry.values()].reduce((sum, options) => sum + options.length, 0)} stable options, ` +
    `${matrix.stableDefaultRegistry.length} stable functions, 0 blockers\n`,
);
