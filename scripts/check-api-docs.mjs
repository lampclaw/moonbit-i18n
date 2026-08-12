import assert from "node:assert/strict";
import {
  copyFileSync,
  existsSync,
  mkdtempSync,
  mkdirSync,
  readFileSync,
  rmSync,
  statSync,
} from "node:fs";
import { tmpdir } from "node:os";
import { dirname, join, resolve } from "node:path";
import { spawnSync } from "node:child_process";

const root = resolve(import.meta.dirname, "..");
const isolatedRoot = mkdtempSync(join(tmpdir(), "lampclaw-i18n-docs-"));
const targetDir = join(isolatedRoot, "generated-docs");

const run = (command, args, cwd = root) => {
  const result = spawnSync(command, args, {
    cwd,
    encoding: "utf8",
    stdio: "pipe",
  });
  process.stdout.write(result.stdout ?? "");
  process.stderr.write(result.stderr ?? "");
  if (result.error) throw result.error;
  if (result.status !== 0) {
    throw new Error(`${command} exited with status ${result.status}`);
  }
  return `${result.stdout ?? ""}${result.stderr ?? ""}`;
};

const meaningful = value =>
  typeof value === "string" && value.trim().length > 0;

try {
  const packageList = run("moon", ["package", "--frozen", "--list"]);
  for (const relativePath of packageList.split(/\r?\n/u)) {
    if (!relativePath || relativePath.startsWith("Running ") || relativePath.startsWith("Finished.")) {
      continue;
    }
    const source = resolve(root, relativePath);
    if (!source.startsWith(`${root}/`) || !existsSync(source) || !statSync(source).isFile()) {
      continue;
    }
    const destination = resolve(isolatedRoot, relativePath);
    mkdirSync(dirname(destination), { recursive: true });
    copyFileSync(source, destination);
  }
  assert.ok(existsSync(join(isolatedRoot, "moon.mod")), "package list omitted moon.mod");
  run("moon", ["doc", "--target-dir", targetDir], isolatedRoot);
  const packageRoots = ["runtime", "generator", "runtime/js"];
  let checked = 0;
  for (const packagePath of packageRoots) {
    const source = readFileSync(
      join(
        targetDir,
        "doc",
        "lampclaw",
        "i18n",
        packagePath,
        "package_data.json",
      ),
      "utf8",
    );
    const data = JSON.parse(source);
    for (const collection of [
      "traits",
      "errors",
      "types",
      "typealias",
      "values",
      "misc",
    ]) {
      for (const item of data[collection] ?? []) {
        assert.ok(
          meaningful(item.docstring),
          `missing API documentation: ${data.name}#${item.name}`,
        );
        checked += 1;
        for (const method of item.methods ?? []) {
          assert.ok(
            meaningful(method.docstring),
            `missing API documentation: ${data.name}#${item.name}::${method.name}`,
          );
          checked += 1;
        }
      }
    }
  }
  console.log(`API documentation: ${checked} public items documented`);
} finally {
  rmSync(isolatedRoot, { recursive: true, force: true });
}
