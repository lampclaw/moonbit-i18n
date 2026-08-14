import assert from "node:assert/strict";
import { createHash } from "node:crypto";
import {
  existsSync,
  mkdtempSync,
  mkdirSync,
  readdirSync,
  readFileSync,
  rmSync,
  statSync,
  writeFileSync,
} from "node:fs";
import { tmpdir } from "node:os";
import { join, resolve } from "node:path";
import { spawnSync } from "node:child_process";

const project = resolve(import.meta.dirname, "..");
const manifest = readFileSync(join(project, "moon.mod"), "utf8");
const versionMatch = manifest.match(/^version = "([^"]+)"$/mu);
assert.ok(versionMatch, "moon.mod version is missing");
const version = versionMatch[1];
const archive = join(
  project,
  "_build",
  "publish",
  `lampclaw-i18n-${version}.zip`,
);
const root = mkdtempSync(join(tmpdir(), "lampclaw-i18n-package-"));
const library = join(root, "library");
const app = join(root, "app");
const state = join(root, "state");

const run = (command, args, options = {}) => {
  const result = spawnSync(command, args, {
    cwd: options.cwd ?? root,
    encoding: "utf8",
    env: {
      ...process.env,
      LAMPCLAW_I18N_STATE_DIR: state,
      ...options.env,
    },
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

const write = (path, source) => writeFileSync(join(root, path), source);

try {
  run("moon", ["update"], { cwd: project });
  run("moon", ["check", "--deny-warn", "--target", "native"], {
    cwd: project,
  });
  run("moon", ["package", "--frozen"], {
    cwd: project,
  });
  assert.ok(existsSync(archive), `package archive is missing: ${archive}`);
  mkdirSync(library);
  mkdirSync(app);
  run("unzip", ["-q", archive, "-d", library]);

  write(
    "moon.work",
    'members = [\n  "library",\n  "app",\n]\n',
  );
  write(
    "app/moon.mod",
    `name = "smoke/app"\n\nversion = "0.1.0"\n\npreferred_target = "js"\n\nimport {\n  "lampclaw/i18n@${version}",\n}\n`,
  );
  mkdirSync(join(app, "localization", "locales"), { recursive: true });
  write(
    "app/localization/config.json",
    JSON.stringify(
      {
        sourceLocale: "en-US",
        defaultLocale: "en-US",
        fallbackLocale: "en-US",
        embeddedLocales: ["en-US"],
        release: { minimumCoverage: 1 },
        locales: {
          "en-US": { direction: "ltr" },
          "zh-CN": { direction: "ltr" },
        },
      },
      null,
      2,
    ) + "\n",
  );
  write(
    "app/localization/schema.json",
    JSON.stringify(
      {
        messages: { account: ["title"], common: ["hello"] },
        params: { "common.hello": [{ name: "name", type: "String" }] },
        descriptions: { "common.hello": "Greets a named user." },
      },
      null,
      2,
    ) + "\n",
  );
  write(
    "app/localization/locales/en-US.json",
    '{"account":{"title":"Account"},"common":{"hello":"Hello {$name}"}}\n',
  );
  write(
    "app/localization/locales/zh-CN.json",
    '{"account":{"title":"账户"},"common":{"hello":"你好 {$name}"}}\n',
  );

  const generationArgs = [
    "--target",
    "wasm",
    "cmd/i18n",
    "--",
    "generate",
    join(app, "localization", "config.json"),
    join(app, "localization", "schema.json"),
    join(app, "localization", "locales"),
    join(app, "i18n"),
    join(app, "public", "i18n"),
  ];
  run("moon", ["run", ...generationArgs], { cwd: library });
  generationArgs[generationArgs.indexOf("generate")] = "check";
  run("moon", ["run", ...generationArgs], { cwd: library });
  assert.ok(
    existsSync(join(app, "i18n", "generation-manifest.json")),
    "deterministic generation manifest was not emitted",
  );
  const generatedBefore = statSync(join(app, "i18n", "generated.mbt"));
  const manifestBefore = statSync(
    join(app, "i18n", "generation-manifest.json"),
  );
  generationArgs[generationArgs.indexOf("check")] = "generate";
  run("moon", ["run", ...generationArgs], { cwd: library });
  const generatedAfter = statSync(join(app, "i18n", "generated.mbt"));
  const manifestAfter = statSync(
    join(app, "i18n", "generation-manifest.json"),
  );
  assert.equal(generatedAfter.ino, generatedBefore.ino, "no-op replaced code");
  assert.equal(generatedAfter.mtimeMs, generatedBefore.mtimeMs, "no-op rewrote code");
  assert.equal(manifestAfter.ino, manifestBefore.ino, "no-op replaced manifest");
  assert.equal(
    manifestAfter.mtimeMs,
    manifestBefore.mtimeMs,
    "no-op rewrote manifest",
  );
  const locks = existsSync(state)
    ? readdirSync(state).filter((name) => name.endsWith(".lampclaw.lock"))
    : [];
  assert.equal(locks.length, 2, "one lock per destination was not created");
  assert.ok(
    !existsSync(join(app, "public", ".i18n.lampclaw.lock")),
    "generation lock leaked into the public asset tree",
  );
  assert.match(
    readFileSync(join(app, "i18n", "moon.pkg"), "utf8"),
    /formatter\(ignore: \[ "generated\.mbt" \]\)/u,
  );

  const xliff = join(app, "translation.xlf");
  const imported = join(app, "imported-zh-CN.json");
  const exchangeState = join(app, "translation-state.json");
  const exchangeReport = join(app, "translation-report.json");
  const cliPrefix = ["run", "--target", "wasm", "cmd/i18n", "--"];
  run(
    "moon",
    [
      ...cliPrefix,
      "export-xliff",
      join(app, "localization", "schema.json"),
      "en-US",
      join(app, "localization", "locales", "en-US.json"),
      "zh-CN",
      join(app, "localization", "locales", "zh-CN.json"),
      xliff,
    ],
    { cwd: library },
  );
  run(
    "moon",
    [
      ...cliPrefix,
      "import-xliff",
      "--state-output",
      exchangeState,
      "--report-output",
      exchangeReport,
      join(app, "localization", "schema.json"),
      "en-US",
      join(app, "localization", "locales", "en-US.json"),
      "zh-CN",
      xliff,
      imported,
    ],
    { cwd: library },
  );
  assert.match(readFileSync(exchangeState, "utf8"), /"sourceSha256"/u);
  assert.match(readFileSync(exchangeReport, "utf8"), /"lossCount": 0/u);
  assert.deepEqual(
    JSON.parse(readFileSync(imported, "utf8")),
    JSON.parse(readFileSync(join(app, "localization", "locales", "zh-CN.json"), "utf8")),
  );
  const migrationOutput = join(app, "i18next-zh-CN.json");
  const migrationReport = join(app, "i18next-report.json");
  run(
    "moon",
    [
      ...cliPrefix,
      "import-i18next",
      join(app, "localization", "schema.json"),
      "zh-CN",
      join(app, "localization", "locales", "zh-CN.json"),
      migrationOutput,
      migrationReport,
    ],
    { cwd: library },
  );
  assert.match(readFileSync(migrationReport, "utf8"), /"lossCount": 0/u);

  const deploymentManifest = JSON.parse(
    readFileSync(join(app, "public", "i18n", "manifest.json"), "utf8"),
  );
  assert.equal(deploymentManifest.manifestVersion, 1);
  assert.equal(deploymentManifest.fallbackLocale, "en-US");
  assert.deepEqual(deploymentManifest.namespaces, ["account", "common"]);
  assert.equal(deploymentManifest.chunks.length, 4);
  for (const chunk of deploymentManifest.chunks) {
    const bytes = readFileSync(join(app, "public", "i18n", chunk.path));
    assert.equal(bytes.length, chunk.bytes);
    assert.equal(createHash("sha256").update(bytes).digest("hex"), chunk.sha256);
  }
  const dynamicAccount = readFileSync(
    join(app, "public", "i18n", "zh-CN--account.json"),
    "utf8",
  );
  const dynamicCommon = readFileSync(
    join(app, "public", "i18n", "zh-CN--common.json"),
    "utf8",
  );
  mkdirSync(join(app, "cmd", "main"), { recursive: true });
  write(
    "app/cmd/main/moon.pkg",
    'import {\n  "smoke/app/i18n" @app_i18n,\n}\n\nsupported_targets = "js"\n\npkgtype(kind: "executable")\n',
  );
  write(
    "app/cmd/main/main.mbt",
    `///|\nfn main {\n  let i18n = @app_i18n.I18n::new()\n  let en = i18n.translator(@app_i18n.EnUS)\n  if en.t(@app_i18n.Common(@app_i18n.Hello("MoonBit"))) != "Hello MoonBit" {\n    abort("embedded English translation failed")\n  }\n  if i18n.has_catalog(@app_i18n.ZhCN) {\n    abort("dynamic Chinese catalog was unexpectedly embedded")\n  }\n  if i18n.install_catalog_chunk_source(\n    @app_i18n.ZhCN,\n    @app_i18n.CatalogCommon,\n    "{not valid JSON",\n  ) is Ok(_) {\n    abort("corrupt chunk was accepted")\n  }\n  let common_source = ${JSON.stringify(dynamicCommon)}\n  match i18n.install_catalog_chunk_source(\n    @app_i18n.ZhCN,\n    @app_i18n.CatalogCommon,\n    common_source,\n  ) {\n    Ok(_) => ()\n    Err(message) => abort("common chunk rejected: \\{message}")\n  }\n  if i18n.has_catalog(@app_i18n.ZhCN) {\n    abort("partially loaded locale was reported complete")\n  }\n  let zh = i18n.translator(@app_i18n.ZhCN)\n  if zh.t(@app_i18n.Common(@app_i18n.Hello("MoonBit"))) != "你好 MoonBit" {\n    abort("dynamic Chinese translation failed")\n  }\n  if zh.t(@app_i18n.Account(@app_i18n.Title)) != "Account" {\n    abort("unloaded namespace did not recover through fallback")\n  }\n  let account_source = ${JSON.stringify(dynamicAccount)}\n  match i18n.install_catalog_chunk_source(\n    @app_i18n.ZhCN,\n    @app_i18n.CatalogAccount,\n    account_source,\n  ) {\n    Ok(_) => ()\n    Err(message) => abort("account chunk rejected: \\{message}")\n  }\n  if !i18n.has_catalog(@app_i18n.ZhCN) {\n    abort("fully loaded locale was not reported complete")\n  }\n  if zh.t(@app_i18n.Account(@app_i18n.Title)) != "账户" {\n    abort("second namespace did not install independently")\n  }\n  let stale = common_source.replace_all(\n    old=@app_i18n.CONTRACT_HASH,\n    new="bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb",\n  )\n  if i18n.install_catalog_chunk_source(\n    @app_i18n.ZhCN,\n    @app_i18n.CatalogCommon,\n    stale,\n  ) is Ok(_) {\n    abort("incompatible chunk was accepted")\n  }\n  if zh.t(@app_i18n.Common(@app_i18n.Hello("MoonBit"))) != "你好 MoonBit" {\n    abort("failed replacement damaged the installed chunk")\n  }\n  println("package smoke: Hello MoonBit / 你好 MoonBit / 账户")\n}\n`,
  );
  run("moon", ["fmt"], { cwd: app });
  run("moon", ["check", "--deny-warn", "--target", "js"], { cwd: app });
  run("moon", ["fmt", "--check"], { cwd: app });
  run("moon", ["build", "--release", "--target", "js"], { cwd: app });
  const output = run(
    "moon",
    ["run", "--release", "--target", "js", "cmd/main"],
    { cwd: app, capture: true },
  );
  assert.match(output, /Hello MoonBit \/ 你好 MoonBit \/ 账户/u);

  const docs = join(root, "docs");
  run("moon", ["doc", "--target-dir", docs], {
    cwd: library,
    env: { MOON_WORK: "off" },
  });
  assert.ok(
    existsSync(
      join(
        docs,
        "doc",
        "lampclaw",
        "i18n",
        "runtime",
        "package_data.json",
      ),
    ),
    "runtime API documentation was not generated from the archive",
  );

  const installDir = join(root, "bin");
  run(
    "moon",
    ["tool", "build-binary-dep", "cmd/i18n", "--install-path", installDir],
    { cwd: library, env: { MOON_WORK: "off" } },
  );
  const launcher = join(
    installDir,
    process.platform === "win32" ? "moon-i18n.ps1" : "moon-i18n",
  );
  assert.ok(existsSync(launcher), `binary launcher is missing: ${launcher}`);
  const binVersion = (process.platform === "win32"
    ? run("pwsh", ["-File", launcher, "--version"], { capture: true })
    : run(launcher, ["--version"], { capture: true })
  ).trim();
  assert.equal(binVersion, `moon-i18n ${version}`);

  const checksum = createHash("sha256")
    .update(readFileSync(archive))
    .digest("hex");
  console.log(`package smoke passed; archive sha256 ${checksum}`);
} finally {
  if (process.env.LAMPCLAW_KEEP_SMOKE !== "1") {
    rmSync(root, { recursive: true, force: true });
  } else {
    console.log(`kept package smoke workspace at ${root}`);
  }
}
