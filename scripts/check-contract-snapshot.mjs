import { createHash } from "node:crypto";
import { readFileSync } from "node:fs";
import { resolve } from "node:path";

const root = resolve(import.meta.dirname, "..");
const read = (path) => readFileSync(resolve(root, path), "utf8");
const readJson = (path) => JSON.parse(read(path));
const hash = (path) =>
  createHash("sha256").update(readFileSync(resolve(root, path))).digest("hex");
const assert = (condition, message) => {
  if (!condition) throw new Error(message);
};

const path = "docs/contracts/1.0-candidate.json";
const snapshot = readJson(path);
const profile = readJson("tests/unicode-mf2/profile.json");
const runtime = read("runtime/catalog.mbt");
const cli = read("cmd/i18n/main.mbt");
const cliPackage = read("cmd/i18n/moon.pkg");
const tooling = read("cmd/i18n/tooling.mbt");
const diagnostics = `${read("generator/diagnostic.mbt")}\n${read(
  "generator/generate.mbt",
)}\n${cli}`;
const diagnosticDocs = `${read("docs/diagnostics.mbt.md")}\n${read(
  "docs/diagnostics.zh-CN.mbt.md",
)}`;

assert(snapshot.snapshotVersion === 1, "unsupported contract snapshot version");
assert(snapshot.candidateRelease === "0.9.0", "candidate release must be 0.9.0");
assert(snapshot.module?.name === "lampclaw/i18n", "module name drifted");
assert(
  snapshot.module?.layout === "single-mooncakes-module",
  "module layout drifted",
);

for (const [interfacePath, expected] of Object.entries(
  snapshot.publicInterfaces ?? {},
)) {
  assert(hash(interfacePath) === expected, `${interfacePath} public API drifted`);
}
assert(
  hash(snapshot.generatorTemplate.path) === snapshot.generatorTemplate.sha256,
  "generated application template drifted",
);

const profilePairs = [
  ["stableMessageProfile", "standardMessageProfile"],
  ["legacyMessageProfile", "legacyStandardMessageProfile"],
  ["experimentalDatetimeMessageProfile", "experimentalDatetimeMessageProfile"],
  ["compatibilityMessageProfile", "catalogProfile"],
];
for (const [snapshotKey, profileKey] of profilePairs) {
  const value = snapshot.authoring?.[snapshotKey];
  assert(value === profile[profileKey], `${snapshotKey} disagrees with profile.json`);
  assert(runtime.includes(`\"${value}\"`), `${snapshotKey} is absent from runtime`);
}
assert(snapshot.authoring?.messageProfileRequired === true, "profile must be explicit");

const wireAnchors = {
  catalogVersion: [runtime, "pub const CATALOG_VERSION : Int = 2"],
  diagnosticVersion: [read("generator/diagnostic.mbt"), '"diagnosticVersion": Json::number(1.0)'],
  generationManifestVersion: [cli, '"manifestVersion": Json::number(1.0)'],
  deploymentManifestVersion: [read("generator/generate.mbt"), '"manifestVersion": Json::number(1.0)'],
  ownershipManifestVersion: [cli, '\\"version\\\": 2'],
};
for (const [name, value] of Object.entries(snapshot.wireContracts ?? {})) {
  assert(Number.isInteger(value) && value > 0, `${name} must be a positive integer`);
  const [source, anchor] = wireAnchors[name] ?? [];
  assert(source?.includes(anchor), `${name} implementation anchor drifted`);
  assert(anchor.includes(`${value}`), `${name} snapshot and anchor disagree`);
}

assert(
  cliPackage.includes(`bin_name: \"${snapshot.cli.binary}\"`),
  "CLI binary name drifted",
);
assert(cli.includes('const CLI_VERSION : String = "0.9.0"'), "CLI version drifted");
for (const command of snapshot.cli.commands) {
  assert(cli.includes(`\"${command}\"`), `CLI command ${command} drifted`);
}
for (const command of snapshot.cli.standaloneCommandsRequireMessageProfile) {
  assert(
    cli.includes(`${command} --message-profile <profile>`),
    `${command} usage no longer requires --message-profile`,
  );
}
assert(
  tooling.includes("if !profile_seen") && tooling.includes("message_profile~"),
  "standalone tooling profile guard drifted",
);

for (const code of snapshot.diagnosticCodes) {
  assert(diagnostics.includes(`\"${code}\"`), `${code} is absent from implementation`);
  assert(diagnosticDocs.includes(`\`${code}\``), `${code} is absent from docs`);
}

assert(snapshot.supportedHost?.node === "26.7.0", "Node contract drifted");
assert(
  JSON.stringify(snapshot.supportedHost?.browserEngines) ===
    JSON.stringify(["chromium", "firefox", "webkit"]),
  "browser engine contract drifted",
);
assert(
  JSON.stringify(profile.browserConformance?.engines) ===
    JSON.stringify(snapshot.supportedHost.browserEngines),
  "browser profile and contract snapshot disagree",
);

console.log(
  `1.0 candidate contract passed: ${Object.keys(snapshot.publicInterfaces).length} interfaces, ` +
    `${snapshot.cli.commands.length} CLI commands, ${snapshot.diagnosticCodes.length} diagnostics`,
);
