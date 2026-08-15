import { createHash } from "node:crypto";
import { existsSync, readFileSync, statSync } from "node:fs";
import { resolve } from "node:path";
import { spawnSync } from "node:child_process";

const root = resolve(import.meta.dirname, "..");
const manifest = readFileSync(resolve(root, "moon.mod"), "utf8");
const moduleName = /^name\s*=\s*"([^"]+)"/mu.exec(manifest)?.[1];
const version = /^version\s*=\s*"([^"]+)"/mu.exec(manifest)?.[1];

if (!moduleName || !version) {
  throw new Error("moon.mod is missing a module name or version");
}

const capture = (command, args) => {
  const result = spawnSync(command, args, {
    cwd: root,
    encoding: "utf8",
    stdio: "pipe",
  });
  if (result.error) throw result.error;
  return result;
};

const requireSuccess = (command, args) => {
  const result = capture(command, args);
  if (result.status !== 0) {
    process.stdout.write(result.stdout ?? "");
    process.stderr.write(result.stderr ?? "");
    throw new Error(`${command} exited with status ${result.status}`);
  }
  return `${result.stdout ?? ""}\n${result.stderr ?? ""}`;
};

const releaseGates = [
  ["node", ["scripts/check-doc-sync.mjs"]],
  ["node", ["scripts/check-api-docs.mjs"]],
  ["node", ["scripts/check-mf2-requirements.mjs"]],
  ["node", ["scripts/check-mf2-differential.mjs"]],
  ["node", ["scripts/check-mf2-profile.mjs"]],
  ["node", ["scripts/check-contract-snapshot.mjs"]],
  ["node", ["scripts/version-contract.mjs", "check"]],
];
for (const [command, args] of releaseGates) {
  process.stdout.write(requireSuccess(command, args));
}

const moonVersion = requireSuccess("moon", ["version", "--all"]);
const mooncakeVersion = requireSuccess("mooncake", ["--version"]);
process.stdout.write(moonVersion);
process.stdout.write(mooncakeVersion);

const resultStart = Date.now();
const result = capture("moon", ["publish", "--dry-run"]);
process.stdout.write(result.stdout ?? "");
process.stderr.write(result.stderr ?? "");
if (result.signal) {
  throw new Error(`moon publish --dry-run terminated by ${result.signal}`);
}

const output = `${result.stdout ?? ""}\n${result.stderr ?? ""}`.replaceAll(
  /\u001b\[[0-9;]*m/gu,
  "",
);
const passedChecks = output.match(/(?:^|\n)Check passed(?:\n|$)/gu)?.length ?? 0;
const expectedStatus = "Server status: 202 Accepted";
const expectedDetail =
  "detail: Dry run completed successfully. No changes were made. " +
  `The dry-run was made for package ${moduleName} version ${version}.`;
const archiveValidationPassed =
  output.includes("validating packaged zip:") &&
  output.includes("running moon check on extracted package") &&
  passedChecks >= 2;
const registryConfirmed =
  output.includes(expectedStatus) && output.includes(expectedDetail);

if (!archiveValidationPassed || !registryConfirmed) {
  throw new Error(
    "dry run did not satisfy both archive-validation and registry-confirmation conditions",
  );
}
if (result.status !== 0 && result.status !== 255) {
  throw new Error(`moon publish --dry-run exited with status ${result.status}`);
}

const archiveName = `${moduleName.replaceAll("/", "-")}-${version}.zip`;
const archive = resolve(root, "_build", "publish", archiveName);
if (!existsSync(archive)) {
  throw new Error(`publish archive is missing: ${archive}`);
}
const archiveTimestamp = statSync(archive).mtimeMs;
if (archiveTimestamp + 1_000 < resultStart) {
  throw new Error("moon publish --dry-run did not refresh the publish archive");
}
const checksum = createHash("sha256")
  .update(readFileSync(archive))
  .digest("hex");
const statusSummary =
  result.status === 255
    ? "accepted fully verified publish-client exit mismatch (255)"
    : "client exited successfully (0)";
console.log(`release dry run passed: ${statusSummary}`);
console.log(`archive: ${archive}`);
console.log(`archive sha256: ${checksum}`);
