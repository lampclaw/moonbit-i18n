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
]);

const sourceArgument = process.argv.indexOf("--source-dir");
const sourceDir = sourceArgument >= 0 ? process.argv[sourceArgument + 1] : undefined;
if (sourceArgument >= 0 && !sourceDir) {
  throw new Error("--source-dir requires the root of a pinned message-format-wg checkout");
}

for (const [path, expected] of files) {
  const content = sourceDir
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
  const target = resolve(root, "tests/unicode-mf2/upstream", path);
  await mkdir(dirname(target), { recursive: true });
  await writeFile(target, content);
  process.stdout.write(`Synchronized ${path} (${actual})\n`);
}
