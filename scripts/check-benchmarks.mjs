import { readFileSync } from "node:fs";
import { resolve } from "node:path";
import { spawnSync } from "node:child_process";

const root = resolve(import.meta.dirname, "..");
const baseline = JSON.parse(
  readFileSync(resolve(root, "benchmarks/baseline.json"), "utf8"),
);
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
process.stdout.write(result.stdout ?? "");
process.stderr.write(result.stderr ?? "");
if (result.error) throw result.error;
if (result.status !== 0) {
  throw new Error(`moon bench exited with status ${result.status}`);
}

const factors = new Map([
  ["ns", 0.001],
  ["µs", 1],
  ["us", 1],
  ["ms", 1000],
  ["s", 1_000_000],
]);
const observed = new Map();
const plain = (result.stdout ?? "").replaceAll(/\u001b\[[0-9;]*m/g, "");
for (const line of plain.split(/\r?\n/)) {
  const match = /^\s*([a-z0-9-]+)\s+([0-9.]+)\s+(ns|µs|us|ms|s)\s+±/i.exec(
    line,
  );
  if (!match) continue;
  observed.set(match[1], Number(match[2]) * factors.get(match[3]));
}

let failed = false;
for (const [name, budgetMicros] of Object.entries(baseline.benchmarks)) {
  const value = observed.get(name);
  if (value === undefined) throw new Error(`benchmark result is missing: ${name}`);
  const ratio = value / budgetMicros;
  console.log(
    `${name}: ${value.toFixed(3)} µs, budget ${budgetMicros.toFixed(3)} µs, ratio ${ratio.toFixed(2)}x`,
  );
  if (
    ratio > baseline.maxRatio ||
    value > baseline.absoluteCeilingMicroseconds
  ) {
    failed = true;
  }
}
if (failed) {
  throw new Error(
    `benchmark exceeded ${baseline.maxRatio}x budget or ${baseline.absoluteCeilingMicroseconds} µs absolute ceiling`,
  );
}
