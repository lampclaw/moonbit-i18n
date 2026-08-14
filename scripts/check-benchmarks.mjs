import { readFileSync } from "node:fs";
import { resolve } from "node:path";
import { spawnSync } from "node:child_process";

const root = resolve(import.meta.dirname, "..");
const baseline = JSON.parse(
  readFileSync(resolve(root, "benchmarks/baseline.json"), "utf8"),
);
const factors = new Map([
  ["ns", 0.001],
  ["µs", 1],
  ["us", 1],
  ["ms", 1000],
  ["s", 1_000_000],
]);
const samples = [];

function collectSample(sample, total) {
  const result = spawnSync(
    "moon",
    [
      "bench",
      "--frozen",
      "--release",
      "--target",
      "js",
      "runtime",
      "runtime/js",
    ],
    { cwd: root, encoding: "utf8" },
  );
  process.stdout.write(`benchmark sample ${sample}/${total}\n`);
  process.stdout.write(result.stdout ?? "");
  process.stderr.write(result.stderr ?? "");
  if (result.error) throw result.error;
  if (result.status !== 0) {
    throw new Error(`moon bench sample ${sample} exited with status ${result.status}`);
  }
  const observed = new Map();
  const plain = (result.stdout ?? "").replaceAll(/\u001b\[[0-9;]*m/g, "");
  for (const line of plain.split(/\r?\n/)) {
    const match = /^\s*([a-z0-9-]+)\s+([0-9.]+)\s+(ns|µs|us|ms|s)\s+±/i.exec(
      line,
    );
    if (!match) continue;
    observed.set(match[1], Number(match[2]) * factors.get(match[3]));
  }
  samples.push(observed);
}

function evaluateSamples() {
  const results = [];
  for (const [name, budgetMicros] of Object.entries(baseline.benchmarks)) {
    const values = samples.map((observed, index) => {
      const value = observed.get(name);
      if (value === undefined) {
        throw new Error(
          `benchmark result is missing from sample ${index + 1}: ${name}`,
        );
      }
      return value;
    });
    const sorted = values.toSorted((left, right) => left - right);
    const value = sorted[Math.floor(sorted.length / 2)];
    const ratio = value / budgetMicros;
    results.push({ name, budgetMicros, values, value, ratio });
  }
  return results;
}

function failures(results) {
  return results.filter(
    ({ value, ratio }) =>
      ratio > baseline.maxRatio ||
      value > baseline.absoluteCeilingMicroseconds,
  );
}

function printResults(results) {
  for (const { name, budgetMicros, values, value, ratio } of results) {
    console.log(
      `${name}: median ${value.toFixed(3)} µs ` +
        `(samples ${values.map(sample => sample.toFixed(3)).join(", ")}), ` +
        `budget ${budgetMicros.toFixed(3)} µs, ratio ${ratio.toFixed(2)}x`,
    );
  }
}

for (let sample = 1; sample <= 3; sample += 1) {
  collectSample(sample, 3);
}

let results = evaluateSamples();
if (failures(results).length > 0) {
  console.log(
    "three-sample median exceeded a budget; collecting four more samples " +
      "to distinguish shared-runner contention from a repeatable regression",
  );
  for (let sample = 4; sample <= 7; sample += 1) {
    collectSample(sample, 7);
  }
  results = evaluateSamples();
}

printResults(results);
const failed = failures(results);
if (failed.length > 0) {
  const details = failed
    .map(
      ({ name, value, ratio }) =>
        `${name}=${value.toFixed(3)}us (${ratio.toFixed(2)}x)`,
    )
    .join(", ");
  process.stderr.write(
    `::error title=Performance budget exceeded::${details}; ` +
      `limits ${baseline.maxRatio}x and ` +
      `${baseline.absoluteCeilingMicroseconds}us\n`,
  );
  throw new Error(
    `benchmark exceeded ${baseline.maxRatio}x budget or ` +
      `${baseline.absoluteCeilingMicroseconds} µs absolute ceiling: ${details}`,
  );
}
