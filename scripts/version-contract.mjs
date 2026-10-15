import assert from "node:assert/strict";
import { readFileSync, writeFileSync } from "node:fs";
import { resolve } from "node:path";

const root = resolve(import.meta.dirname, "..");
const mode = process.argv[2] ?? "check";
const requestedVersion = process.argv[3];
const allowedVersion = /^0\.[0-9]+\.[0-9]+(?:-rc\.[1-9][0-9]*)?$/u;

const read = (path) => readFileSync(resolve(root, path), "utf8");
const write = (path, source) => writeFileSync(resolve(root, path), source);
const manifestVersion = () => {
  const match = read("moon.mod").match(/^version = "([^"]+)"$/mu);
  assert.ok(match, "moon.mod must contain one version field");
  assert.match(match[1], allowedVersion, "unsupported release version");
  return match[1];
};

const activeFiles = [
  "README.mbt.md",
  "README.zh-CN.mbt.md",
  "cmd/i18n/main.mbt",
  "cmd/i18n/main_wbtest.mbt",
  "docs/mf2-profile.mbt.md",
  "docs/mf2-profile.zh-CN.mbt.md",
  "docs/runtime-spi.mbt.md",
  "docs/runtime-spi.zh-CN.mbt.md",
  "examples/rabbita_todo/README.mbt.md",
  "examples/rabbita_todo/README.zh-CN.mbt.md",
  "examples/rabbita_todo/moon.mod",
];

const replaceActiveVersion = (path, from, to) => {
  const source = read(path);
  const updated =
    path === "moon.mod"
      ? source.replace(`version = "${from}"`, `version = "${to}"`)
      : source.replaceAll(from, to);
  assert.notEqual(updated, source, `${path} did not contain ${from}`);
  write(path, updated);
};

const check = () => {
  const version = manifestVersion();
  for (const path of activeFiles) {
    const source = read(path);
    assert.ok(source.includes(version), `${path} does not reference ${version}`);
    const stale = source.match(/0\.1\.0-rc\.[1-9][0-9]*/gu) ?? [];
    assert.deepEqual(
      [...new Set(stale)],
      version.includes("-rc.") ? [version] : [],
      `${path} contains a stale active release reference`,
    );
  }
  assert.match(
    read("CHANGELOG.md"),
    /^\[Unreleased\]: https:\/\/github\.com\/lampclaw\/moonbit-i18n\/compare\/[0-9a-f]{40}\.\.\.HEAD$/mu,
    "CHANGELOG Unreleased comparison must start at a full published source commit SHA",
  );
  assert.ok(
    !/https:\/\/github\.com\/lampclaw\/moonbit-i18n\/(?:tree\/v|compare\/v|releases\/tag\/)/u.test(
      [read("CHANGELOG.md"), read("README.mbt.md"), read("README.zh-CN.mbt.md")].join("\n"),
    ),
    "active documentation must not link to deleted release tags",
  );
  console.log(`version contract passed for ${version}`);
};

if (mode === "get") {
  console.log(manifestVersion());
} else if (mode === "check") {
  check();
} else if (mode === "set") {
  assert.ok(requestedVersion, "usage: version-contract.mjs set <version>");
  assert.match(requestedVersion, allowedVersion, "unsupported release version");
  const current = manifestVersion();
  assert.notEqual(current, requestedVersion, `version is already ${current}`);
  replaceActiveVersion("moon.mod", current, requestedVersion);
  for (const path of activeFiles) replaceActiveVersion(path, current, requestedVersion);
  // The published source SHA is immutable; a version bump does not move it.
  check();
  console.log(`updated active release references: ${current} -> ${requestedVersion}`);
} else {
  throw new Error("usage: version-contract.mjs <get|check|set> [version]");
}
