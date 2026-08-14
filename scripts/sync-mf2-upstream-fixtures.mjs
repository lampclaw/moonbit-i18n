import assert from "node:assert/strict";
import { createHash } from "node:crypto";
import { mkdir, readFile, writeFile } from "node:fs/promises";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const root = fileURLToPath(new URL("../", import.meta.url));
const pin = (await readFile(resolve(root, "tests/unicode-mf2/PINNED_COMMIT"), "utf8")).trim();
assert.match(pin, /^[0-9a-f]{40}$/u);

const files = new Map([
  ["LICENSE", "fbcc4d0631d6e1cb9d4a7750a6510605205a70c7bd74f957d1f998ff0f1e849d"],
  ["test/tests/syntax.json", "4311db5ee6cfc307fa0505a7484ce7cf9e326dd770cc1c85772a35b3fdbdb810"],
  ["test/tests/syntax-errors.json", "26a090b1eb1fdda98d578362c7a49184350a5f80fd919ad54a1735e00786909b"],
  ["test/tests/data-model-errors.json", "6b8d8527b5248af76bca3f61d7c58c3339c91b05555f2fc11727efc81b94e615"],
  ["test/tests/fallback.json", "9654322cdaed27660b53d91e7142795aa62ce2da87a99e7ce6a471549139c010"],
  ["test/tests/pattern-selection.json", "510a7e054f7d86eee645877bbfe8739bcd7ccabfa4290c8fbd93d64e3a89dadc"],
  ["test/tests/bidi.json", "fa3ebcd416dbdadab63731ee7a18a25b531773e4cc159dbe22da4ca1cba64afb"],
  ["test/tests/u-options.json", "6931deea81ec7c2a282e48428fee3250b3b27ee74690573e3c2ed23747d1f64a"],
  ["spec/formatting.md", "2e33a4306540ea0c153361317a8f39342fb76276beb2e7446f73c08c8579e90e"],
  ["spec/errors.md", "8d6841d956a9e2cc86c1de3d464398dfd91c46f8dfbbd8a1014e9a2e21b29587"],
  ["spec/u-namespace.md", "733e8b8d23ea5f54ea66f4580543795ea9e41e6742906d27b932f7ee8ffb7e81"],
]);

const sourceArgument = process.argv.indexOf("--source-dir");
const sourceDir = sourceArgument >= 0 ? process.argv[sourceArgument + 1] : undefined;
const check = process.argv.includes("--check");
if (sourceArgument >= 0 && !sourceDir) {
  throw new Error("--source-dir requires the root of a pinned message-format-wg checkout");
}

for (const [path, expected] of files) {
  const target = resolve(root, "tests/unicode-mf2/upstream", path);
  const content = check
    ? await readFile(target)
    : sourceDir
    ? await readFile(resolve(sourceDir, path))
    : Buffer.from(
        await (
          await fetch(
            `https://raw.githubusercontent.com/unicode-org/message-format-wg/${pin}/${path}`,
          )
        ).arrayBuffer(),
      );
  const actual = createHash("sha256").update(content).digest("hex");
  assert.equal(actual, expected, `unexpected upstream content for ${path}`);
  if (check) {
    process.stdout.write(`Verified ${path} (${actual})\n`);
  } else {
    await mkdir(dirname(target), { recursive: true });
    await writeFile(target, content);
    process.stdout.write(`Synchronized ${path} (${actual})\n`);
  }
}
