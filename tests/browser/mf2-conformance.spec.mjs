import { expect, test } from "@playwright/test";
import { readFile } from "node:fs/promises";
import { resolve } from "node:path";
import {
  MessageDataModelError,
  MessageFormat,
  MessageSyntaxError,
} from "messageformat";
import { DraftFunctions } from "messageformat/functions";

const root = new URL("../../", import.meta.url);
const readJson = async path =>
  JSON.parse(await readFile(new URL(path, root), "utf8"));
const harnessPath = resolve(
  new URL(root).pathname,
  "_build/js/debug/build/lampclaw/i18n/tests/mf2-browser/mf2-browser.js",
);

const errorType = new Map([
  ["syntax-error", "syntax-error"],
  ["data-model-error", "data-model-error"],
  ["variant-key-mismatch", "variant-key-mismatch"],
  ["missing-fallback-variant", "missing-fallback-variant"],
  ["missing-selector-annotation", "missing-selector-annotation"],
  ["duplicate-declaration", "duplicate-declaration"],
  ["duplicate-option-name", "duplicate-option-name"],
  ["duplicate-variant", "duplicate-variant"],
  ["bad-operand", "bad-operand"],
  ["bad-option", "bad-option"],
  ["bad-selector", "bad-selector"],
  ["bad-variant-key", "bad-variant-key"],
  ["unknown-function", "unknown-function"],
  ["unresolved-variable", "unresolved-variable"],
]);

function normalizedParams(params = []) {
  return params.map(param => ({
    name: param.name,
    type:
      param.type ??
      (typeof param.value === "number"
        ? Number.isInteger(param.value)
          ? "int"
          : "double"
        : typeof param.value === "boolean"
          ? "bool"
          : "string"),
    value: param.value,
  }));
}

function differentialParams(params = {}) {
  return Object.entries(params).map(([name, value]) => ({ name, ...value }));
}

function expectedCodes(errors = []) {
  return errors.map(error => {
    const code = errorType.get(error.type);
    if (!code) throw new Error(`unmapped MF2 error type: ${error.type}`);
    return code;
  });
}

function field(value) {
  return `${Array.from(value).length}:${value}`;
}

function expectedPartSignature(part) {
  if (part.type === "text") return `text|${field(part.value)}`;
  if (part.type === "bidiIsolation") return `bidi|${field(part.value)}`;
  if (part.type === "fallback") return `fallback|${field(`{${part.source}}`)}`;
  if (part.type === "string") {
    return `expression|${field("string")}|${part.dir ?? "unknown"}|${field(part.id ?? "")}|${field(part.value)}`;
  }
  if (part.type === "markup") {
    return `markup|${part.kind}|${field(part.name)}|${field(part.id ?? "")}`;
  }
  throw new Error(`unsupported MF2 expected part: ${JSON.stringify(part)}`);
}

async function runBrowserCases(page, cases) {
  await page.goto("about:blank");
  await page.evaluate(value => {
    globalThis.__LAMPCLAW_MF2_BROWSER_FIXTURES__ = JSON.stringify(value);
    delete globalThis.__LAMPCLAW_MF2_BROWSER_RESULTS__;
  }, cases);
  await page.addScriptTag({ path: harnessPath });
  return JSON.parse(
    await page.evaluate(() => globalThis.__LAMPCLAW_MF2_BROWSER_RESULTS__),
  );
}

function resultMap(results) {
  return new Map(results.map(result => [result.id, result]));
}

async function attachHostFingerprint(page, testInfo) {
  const fingerprint = await page.evaluate(() => ({
    userAgent: navigator.userAgent,
    locale: new Intl.NumberFormat().resolvedOptions().locale,
    number: new Intl.NumberFormat("de-DE", {
      minimumFractionDigits: 2,
    }).format(1234.5),
    currency: new Intl.NumberFormat("en-US", {
      style: "currency",
      currency: "EUR",
    }).format(42),
    date: new Intl.DateTimeFormat("en-US", {
      dateStyle: "long",
      timeZone: "UTC",
    }).format(new Date("2006-01-02T00:00:00Z")),
  }));
  await testInfo.attach("intl-host-fingerprint.json", {
    body: Buffer.from(`${JSON.stringify(fingerprint, null, 2)}\n`),
    contentType: "application/json",
  });
}

test("runs every pinned syntax and data-model fixture", async ({ page }) => {
  const [syntax, syntaxErrors, modelErrors] = await Promise.all([
    readJson("tests/unicode-mf2/upstream/test/tests/syntax.json"),
    readJson("tests/unicode-mf2/upstream/test/tests/syntax-errors.json"),
    readJson("tests/unicode-mf2/upstream/test/tests/data-model-errors.json"),
  ]);
  const cases = [
    ...syntax.tests.map((item, index) => ({
      id: `syntax-ok-${index}`,
      kind: "syntax",
      source: item.src,
      expected: [],
    })),
    ...syntaxErrors.tests.map((item, index) => ({
      id: `syntax-error-${index}`,
      kind: "syntax",
      source: item.src,
      expected: ["syntax-error"],
    })),
    ...modelErrors.tests.map((item, index) => ({
      id: `data-model-${index}`,
      kind: "data-model",
      source: item.src,
      expected: expectedCodes(item.expErrors),
    })),
  ];
  const actual = resultMap(await runBrowserCases(page, cases));
  expect(actual.size).toBe(270);
  for (const fixture of cases) {
    const result = actual.get(fixture.id);
    expect(result, fixture.id).toBeDefined();
    if (fixture.kind === "data-model") {
      for (const code of fixture.expected) {
        expect(result.errorCodes, `${fixture.id}: ${code}`).toContain(code);
      }
      if (fixture.expected.length === 0) expect(result.errorCodes).toEqual([]);
    } else {
      expect(result.errorCodes, fixture.id).toEqual(fixture.expected);
    }
  }
});

test("runs every pinned resolution, fallback, bidi, and u-option fixture", async ({
  page,
}) => {
  const names = ["fallback", "pattern-selection", "bidi", "u-options"];
  const files = await Promise.all(
    names.map(name =>
      readJson(`tests/unicode-mf2/upstream/test/tests/${name}.json`),
    ),
  );
  const cases = [];
  for (let fileIndex = 0; fileIndex < files.length; fileIndex += 1) {
    const file = files[fileIndex];
    for (let index = 0; index < file.tests.length; index += 1) {
      const item = file.tests[index];
      const properties = { ...file.defaultTestProperties, ...item };
      cases.push({
        id: `${names[fileIndex]}-${index}`,
        kind: "format",
        source: item.src,
        locale: properties.locale ?? "en-US",
        bidiIsolation: properties.bidiIsolation ?? "default",
        params: normalizedParams(item.params),
        expectedValue: item.exp,
        expectedCodes: expectedCodes(item.expErrors),
        expectedParts: item.expParts?.map(expectedPartSignature),
      });
    }
  }
  const actual = resultMap(await runBrowserCases(page, cases));
  expect(actual.size).toBe(67);
  for (const fixture of cases) {
    const result = actual.get(fixture.id);
    expect(result, fixture.id).toBeDefined();
    if (fixture.expectedValue !== undefined) {
      expect(result.value, fixture.id).toBe(fixture.expectedValue);
    }
    expect(result.errorCodes, fixture.id).toEqual(fixture.expectedCodes);
    if (fixture.expectedParts) {
      expect(result.partSignatures, fixture.id).toEqual(fixture.expectedParts);
    }
  }
});

test("runs all stable default-function fixtures and keeps Draft cases separate", async ({
  page,
}, testInfo) => {
  const stableNames = ["currency", "integer", "number", "offset", "percent", "string"];
  const experimentalNames = ["date", "datetime", "time"];
  const names = [...stableNames, ...experimentalNames];
  const files = await Promise.all(
    names.map(name =>
      readJson(`tests/unicode-mf2/upstream/test/tests/functions/${name}.json`),
    ),
  );
  const cases = [];
  for (let fileIndex = 0; fileIndex < files.length; fileIndex += 1) {
    const file = files[fileIndex];
    for (let index = 0; index < file.tests.length; index += 1) {
      const item = file.tests[index];
      const properties = { ...file.defaultTestProperties, ...item };
      const fields = [];
      for (const part of item.expParts ?? []) {
        if (part.type === "number") {
          for (const value of part.parts ?? []) {
            fields.push(`${value.type}|${value.value}`);
          }
        }
      }
      cases.push({
        id: `${names[fileIndex]}-${index}`,
        profile: stableNames.includes(names[fileIndex])
          ? "stable"
          : "experimental-datetime",
        kind: "format",
        source: item.src,
        locale: properties.locale ?? "en-US",
        bidiIsolation: properties.bidiIsolation ?? "none",
        params: normalizedParams(item.params),
        expectedValue: item.exp,
        expectedCodes: expectedCodes(properties.expErrors),
        expectedFields: item.expParts ? fields : undefined,
      });
    }
  }
  const actual = resultMap(await runBrowserCases(page, cases));
  expect(actual.size).toBe(124);
  expect(cases.filter(item => item.profile === "stable")).toHaveLength(104);
  expect(cases.filter(item => item.profile === "experimental-datetime")).toHaveLength(20);
  for (const fixture of cases) {
    const result = actual.get(fixture.id);
    expect(result, fixture.id).toBeDefined();
    expect(result.errorCodes, fixture.id).toEqual(fixture.expectedCodes);
    if (fixture.expectedValue !== undefined) {
      expect(result.value, fixture.id).toBe(fixture.expectedValue);
    }
    if (fixture.expectedFields) {
      expect(result.numberFields, fixture.id).toEqual(fixture.expectedFields);
    }
  }
  await attachHostFingerprint(page, testInfo);
});

function parameterValues(parameters = {}) {
  return Object.fromEntries(
    Object.entries(parameters).map(([name, parameter]) => [name, parameter.value]),
  );
}

function normalizedReferenceError(error) {
  if (error instanceof MessageDataModelError) return "data-model";
  if (error instanceof MessageSyntaxError) return "syntax";
  return "resolution";
}

function referenceResult(fixture) {
  const errors = [];
  const formatter = new MessageFormat(fixture.locale, fixture.source, {
    functions: DraftFunctions,
    bidiIsolation: fixture.bidiIsolation === "none" ? "none" : "default",
  });
  const value = formatter.format(parameterValues(fixture.params), error => {
    errors.push(normalizedReferenceError(error));
  });
  return { value, errorKinds: errors };
}

function coarseError(code) {
  if (code === "syntax-error") return "syntax";
  if (
    code === "data-model-error" ||
    code === "variant-key-mismatch" ||
    code === "missing-fallback-variant" ||
    code === "missing-selector-annotation" ||
    code === "duplicate-declaration" ||
    code === "duplicate-option-name" ||
    code === "duplicate-variant"
  ) {
    return "data-model";
  }
  return "resolution";
}

test("runs stable and experimental differential cases in the browser host", async ({
  page,
}, testInfo) => {
  const fixture = await readJson("tests/unicode-mf2/differential.json");
  const cases = fixture.cases.map(item => ({
    ...item,
    kind: "format",
    params: differentialParams(item.params),
  }));
  const actual = resultMap(await runBrowserCases(page, cases));
  expect(actual.size).toBe(24);
  expect(cases.filter(item => item.profile !== "experimental-datetime")).toHaveLength(20);
  expect(cases.filter(item => item.profile === "experimental-datetime")).toHaveLength(4);
  for (const fixtureCase of fixture.cases) {
    const moon = actual.get(fixtureCase.id);
    const reference = referenceResult(fixtureCase);
    const moonErrors = moon.errorCodes.map(coarseError);
    if (fixtureCase.classification === "exact") {
      expect(moonErrors, fixtureCase.id).toEqual([]);
      expect(reference.errorKinds, fixtureCase.id).toEqual([]);
      expect(moon.value, fixtureCase.id).toBe(reference.value);
    } else if (fixtureCase.classification === "semantic-error") {
      expect(moonErrors, fixtureCase.id).toContain(fixtureCase.expectedError);
      expect(reference.errorKinds, fixtureCase.id).toContain(
        fixtureCase.expectedError,
      );
      expect(moon.value, fixtureCase.id).toBe(reference.value);
    } else {
      expect(moonErrors, fixtureCase.id).toEqual([]);
      expect(reference.errorKinds, fixtureCase.id).toEqual([]);
      expect(moon.value.length, fixtureCase.id).toBeGreaterThan(0);
      expect(reference.value.length, fixtureCase.id).toBeGreaterThan(0);
      expect(moon.value, fixtureCase.id).toMatch(/\p{Number}/u);
      expect(reference.value, fixtureCase.id).toMatch(/\p{Number}/u);
    }
  }
  await attachHostFingerprint(page, testInfo);
});
