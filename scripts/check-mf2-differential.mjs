import assert from "node:assert/strict";
import { execFileSync } from "node:child_process";
import { readFile, writeFile } from "node:fs/promises";
import { fileURLToPath } from "node:url";
import {
  MessageDataModelError,
  MessageFormat,
  MessageSyntaxError,
} from "messageformat";
import { DraftFunctions } from "messageformat/functions";

const root = new URL("../", import.meta.url);
const rootPath = fileURLToPath(root);
const read = path => readFile(new URL(path, root), "utf8");
const fixture = JSON.parse(await read("tests/unicode-mf2/differential.json"));
const update = process.argv.includes("--update");

assert.equal(process.versions.node.split(".")[0], "26", "differential tests support Node 26 only");
assert.equal(fixture.fixtureVersion, 1);
assert.deepEqual(fixture.reference, {
  package: "messageformat",
  version: "4.0.0",
  runtime: "Node 26.7.0",
});

function parameterValues(parameters = {}) {
  return Object.fromEntries(
    Object.entries(parameters).map(([name, parameter]) => [name, parameter.value]),
  );
}

function normalizedErrorKind(error) {
  if (error instanceof MessageDataModelError) return "data-model";
  if (error instanceof MessageSyntaxError) return "syntax";
  return "resolution";
}

function runReference(testCase) {
  const errors = [];
  try {
    const formatter = new MessageFormat(testCase.locale, testCase.source, {
      functions: DraftFunctions,
      bidiIsolation: testCase.bidiIsolation === "none" ? "none" : "default",
    });
    const value = formatter.format(parameterValues(testCase.params), error => {
      errors.push(normalizedErrorKind(error));
    });
    return { id: testCase.id, value, errorKinds: errors };
  } catch (error) {
    return {
      id: testCase.id,
      value: "",
      errorKinds: [normalizedErrorKind(error)],
    };
  }
}

const moonOutput = execFileSync(
  "moon",
  [
    "run",
    "--frozen",
    "--target",
    "js",
    "tests/mf2-differential",
    "--",
    JSON.stringify(fixture.cases),
  ],
  {
    cwd: rootPath,
    encoding: "utf8",
    maxBuffer: 16 * 1024 * 1024,
    stdio: ["ignore", "pipe", "inherit"],
  },
);
const moonResults = JSON.parse(moonOutput.trim());
const moonById = new Map(moonResults.map(result => [result.id, result]));
const referenceById = new Map(fixture.cases.map(testCase => {
  const result = runReference(testCase);
  return [result.id, result];
}));

assert.equal(moonById.size, fixture.cases.length, "MoonBit runner omitted or duplicated cases");
assert.equal(referenceById.size, fixture.cases.length, "fixture contains duplicate ids");

const exactMatches = [];
const semanticErrorMatches = [];
const cldrMatches = [];
const cldrTextDifferences = [];
for (const testCase of fixture.cases) {
  const moon = moonById.get(testCase.id);
  const reference = referenceById.get(testCase.id);
  assert.ok(moon, `${testCase.id}: missing MoonBit result`);
  assert.ok(reference, `${testCase.id}: missing reference result`);
  if (testCase.classification === "exact") {
    assert.deepEqual(moon.errorKinds, [], `${testCase.id}: MoonBit errors`);
    assert.deepEqual(reference.errorKinds, [], `${testCase.id}: reference errors`);
    assert.equal(moon.value, reference.value, `${testCase.id}: semantic output mismatch`);
    exactMatches.push(testCase.id);
  } else if (testCase.classification === "semantic-error") {
    assert.ok(moon.errorKinds.includes(testCase.expectedError), `${testCase.id}: MoonBit error class`);
    assert.ok(reference.errorKinds.includes(testCase.expectedError), `${testCase.id}: reference error class`);
    assert.equal(moon.value, reference.value, `${testCase.id}: fallback output mismatch`);
    semanticErrorMatches.push(testCase.id);
  } else if (testCase.classification === "cldr-text") {
    assert.deepEqual(moon.errorKinds, [], `${testCase.id}: MoonBit semantic failure`);
    assert.deepEqual(reference.errorKinds, [], `${testCase.id}: reference semantic failure`);
    assert.ok(moon.value.length > 0 && reference.value.length > 0, `${testCase.id}: empty CLDR output`);
    assert.match(moon.value, /\p{Number}/u, `${testCase.id}: MoonBit output has no numeric field`);
    assert.match(reference.value, /\p{Number}/u, `${testCase.id}: reference output has no numeric field`);
    if (moon.value === reference.value) {
      cldrMatches.push(testCase.id);
    } else {
      cldrTextDifferences.push({
        id: testCase.id,
        moonbit: moon.value,
        reference: reference.value,
        classification: "host-cldr-text",
      });
    }
  } else {
    assert.fail(`${testCase.id}: unknown classification ${testCase.classification}`);
  }
}

const report = {
  reportVersion: 1,
  messageProfile: "unicode-mf2-ldml48.2-js-v1",
  reference: fixture.reference,
  nodeMajor: 26,
  totalCases: fixture.cases.length,
  exactMatches,
  semanticErrorMatches,
  cldrMatches,
  cldrTextDifferences,
  unexplainedSemanticFailures: [],
};
const reportSource = `${JSON.stringify(report, null, 2)}\n`;
const reportUrl = new URL("tests/unicode-mf2/differential-report.json", root);
if (update) {
  await writeFile(reportUrl, reportSource, "utf8");
} else {
  assert.equal(
    await read("tests/unicode-mf2/differential-report.json"),
    reportSource,
    "differential report is stale; run with --update after reviewing classifications",
  );
}

process.stdout.write(
  `MF2 differential: ${fixture.cases.length} cases; ` +
    `${exactMatches.length} exact, ${semanticErrorMatches.length} error-semantic, ` +
    `${cldrMatches.length} CLDR exact, ${cldrTextDifferences.length} explained CLDR text differences\n`,
);
