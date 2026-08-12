import { mkdtempSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join, relative, resolve } from "node:path";
import { spawnSync } from "node:child_process";

const root = resolve(import.meta.dirname, "..");
const targetDir = mkdtempSync(join(tmpdir(), "lampclaw-i18n-coverage-"));

const run = (command, args, options = {}) => {
  const result = spawnSync(command, args, {
    cwd: options.cwd ?? root,
    encoding: "utf8",
    stdio: options.capture ? "pipe" : "inherit",
  });
  if (result.error) throw result.error;
  if (result.status !== 0) {
    if (options.capture) {
      process.stdout.write(result.stdout ?? "");
      process.stderr.write(result.stderr ?? "");
    }
    throw new Error(`${command} exited with status ${result.status}`);
  }
  return result.stdout ?? "";
};

try {
  for (const [target, packages] of [
    ["js", ["runtime", "runtime/js", "generator"]],
    ["wasm", ["cmd/i18n"]],
  ]) {
    run("moon", [
      "test",
      "--frozen",
      "--target",
      target,
      "--enable-coverage",
      "--target-dir",
      targetDir,
      ...packages,
    ]);
  }
  const summary = run(
    "moon_cove_report",
    [
      "-f",
      "summary",
      "--ignore-missing-files",
      "--source-paths",
      root,
    ],
    { cwd: targetDir, capture: true },
  );
  process.stdout.write(summary);

  const totals = new Map([
    ["runtime", { hit: 0, total: 0 }],
    ["generator", { hit: 0, total: 0 }],
    ["cli", { hit: 0, total: 0 }],
  ]);
  for (const line of summary.split(/\r?\n/)) {
    const match = /^(.*\.mbt):\s+(\d+)\/(\d+)$/.exec(line.trim());
    if (!match) continue;
    const file = relative(root, match[1]).replaceAll("\\", "/");
    const group = file.startsWith("runtime/")
      ? "runtime"
      : file.startsWith("generator/")
        ? "generator"
        : file.startsWith("cmd/i18n/")
          ? "cli"
          : null;
    if (!group) continue;
    const value = totals.get(group);
    value.hit += Number(match[2]);
    value.total += Number(match[3]);
  }

  const thresholds = { runtime: 0.9, generator: 0.85, cli: 0.85 };
  let overallHit = 0;
  let overallTotal = 0;
  let failed = false;
  for (const [group, minimum] of Object.entries(thresholds)) {
    const value = totals.get(group);
    if (value.total === 0) throw new Error(`no ${group} coverage data found`);
    const ratio = value.hit / value.total;
    overallHit += value.hit;
    overallTotal += value.total;
    console.log(
      `${group}: ${value.hit}/${value.total} (${(ratio * 100).toFixed(1)}%, minimum ${(minimum * 100).toFixed(0)}%)`,
    );
    if (ratio < minimum) failed = true;
  }
  const overall = overallHit / overallTotal;
  console.log(
    `core overall: ${overallHit}/${overallTotal} (${(overall * 100).toFixed(1)}%, minimum 85%)`,
  );
  if (overall < 0.85) failed = true;
  if (failed) throw new Error("coverage threshold was not met");
} finally {
  rmSync(targetDir, { recursive: true, force: true });
}
