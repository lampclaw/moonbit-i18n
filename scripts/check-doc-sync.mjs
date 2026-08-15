import assert from "node:assert/strict";
import { access, readFile } from "node:fs/promises";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const root = fileURLToPath(new URL("../", import.meta.url));
const read = path => readFile(resolve(root, path), "utf8");
const moonMod = await read("moon.mod");
const version = /^version = "([^"]+)"$/mu.exec(moonMod)?.[1];
assert.match(version ?? "", /^0\.[0-9]+\.[0-9]+$/u);

const pairs = [
  ["README.mbt.md", "README.zh-CN.mbt.md"],
  ["docs/mf2-profile.mbt.md", "docs/mf2-profile.zh-CN.mbt.md"],
  ["docs/message-profile-migration.mbt.md", "docs/message-profile-migration.zh-CN.mbt.md"],
  ["docs/runtime-spi.mbt.md", "docs/runtime-spi.zh-CN.mbt.md"],
  ["docs/diagnostics.mbt.md", "docs/diagnostics.zh-CN.mbt.md"],
  ["docs/support-policy.mbt.md", "docs/support-policy.zh-CN.mbt.md"],
  ["docs/mf2-default-functions.mbt.md", "docs/mf2-default-functions.zh-CN.mbt.md"],
  ["docs/mf2-syntax-data-model.mbt.md", "docs/mf2-syntax-data-model.zh-CN.mbt.md"],
  ["docs/mf2-resolution-formatting.mbt.md", "docs/mf2-resolution-formatting.zh-CN.mbt.md"],
  ["docs/roadmap.mbt.md", "docs/roadmap.zh-CN.mbt.md"],
  ["examples/rabbita_todo/README.mbt.md", "examples/rabbita_todo/README.zh-CN.mbt.md"],
];
const requiredTokens = [version];
for (const [englishPath, chinesePath] of pairs) {
  const english = await read(englishPath);
  const chinese = await read(chinesePath);
  for (const token of requiredTokens) {
    assert.ok(english.includes(token), `${englishPath}: missing synchronized token ${token}`);
    assert.ok(chinese.includes(token), `${chinesePath}: missing synchronized token ${token}`);
  }
}

const readme = await read("README.mbt.md");
const readmeZh = await read("README.zh-CN.mbt.md");
for (const source of [readme, readmeZh]) {
  assert.ok(source.includes('"messageProfile": "unicode-mf2-ldml48.2-js-v2"'));
  assert.ok(source.includes("unicode-mf2-ldml48.2-js-v2+experimental-datetime-v1"));
  assert.ok(source.includes("message-profile-migration"));
  assert.ok(source.includes("messageformat@4.0.0"));
  assert.ok(source.includes("Chromium") && source.includes("Firefox") && source.includes("WebKit"));
}

const profile = await read("docs/mf2-profile.mbt.md");
const profileZh = await read("docs/mf2-profile.zh-CN.mbt.md");
for (const source of [profile, profileZh]) {
  for (const token of ["77", "40", "24", "270", "67", "104", "messageformat@4.0.0", "I18N1003", "I18N1004"]) {
    assert.ok(source.includes(token), `MF2 profile docs missing release evidence: ${token}`);
  }
}

const migration = await read("docs/message-profile-migration.mbt.md");
const migrationZh = await read("docs/message-profile-migration.zh-CN.mbt.md");
for (const source of [migration, migrationZh]) {
  for (const code of ["I18N1003", "I18N1004", "I18N3003", "I18N3004"]) {
    assert.ok(source.includes(code), `migration docs missing ${code}`);
  }
  assert.ok(source.includes(":date length=medium timeZone=UTC"));
  assert.ok(source.includes("MESSAGE_PROFILE"));
}

const roadmap = await read("docs/roadmap.mbt.md");
const roadmapZh = await read("docs/roadmap.zh-CN.mbt.md");
assert.ok(roadmap.includes("Status: stable in `0.9.0`"));
assert.ok(roadmapZh.includes("状态：已在 `0.9.0` 稳定"));

const lifecycle = await read("docs/translation-lifecycle.mbt.md");
const lifecycleZh = await read("docs/translation-lifecycle.zh-CN.mbt.md");
for (const source of [lifecycle, lifecycleZh]) {
  assert.ok(source.includes("--message-profile unicode-mf2-ldml48.2-js-v2"));
  assert.ok(source.includes("message-profile-migration"));
}

const webDelivery = await read("docs/web-delivery.mbt.md");
const webDeliveryZh = await read("docs/web-delivery.zh-CN.mbt.md");
for (const source of [webDelivery, webDeliveryZh]) {
  for (const token of ["448 KiB", "128 KiB", "429 KiB", "116 KiB", "76 KiB"]) {
    assert.ok(source.includes(token), `Web size evidence missing ${token}`);
  }
}

const changelog = await read("CHANGELOG.md");
assert.ok(changelog.includes(`## [${version}] - `));
for (const code of ["I18N1003", "I18N1004", "I18N3003", "I18N3004"]) {
  assert.ok(changelog.includes(code), `CHANGELOG missing ${code}`);
}

const publicMarkdown = [
  "README.mbt.md",
  "README.zh-CN.mbt.md",
  ...pairs.flat().filter(path => path.startsWith("docs/")),
  "docs/translation-lifecycle.mbt.md",
  "docs/translation-lifecycle.zh-CN.mbt.md",
  "docs/web-delivery.mbt.md",
  "docs/web-delivery.zh-CN.mbt.md",
];
for (const path of new Set(publicMarkdown)) {
  const source = await read(path);
  for (const match of source.matchAll(/\[[^\]]+\]\(([^)]+)\)/gu)) {
    const target = match[1].split("#", 1)[0];
    if (!target || /^(?:https?:|mailto:)/u.test(target)) continue;
    const absolute = resolve(root, dirname(path), target);
    await access(absolute).catch(() => {
      assert.fail(`${path}: broken local documentation link ${match[1]}`);
    });
  }
}

process.stdout.write(
  `Documentation synchronized for ${version}: ${pairs.length} bilingual contract pairs\n`,
);
