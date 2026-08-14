import assert from "node:assert/strict";
import { createHash } from "node:crypto";
import {
  existsSync,
  mkdtempSync,
  readdirSync,
  readFileSync,
  rmSync,
  statSync,
  writeFileSync,
} from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { spawnSync } from "node:child_process";

const version = process.argv[2];
assert.ok(version, "usage: registry-smoke.mjs <published-version>");
assert.match(version, /^\d+\.\d+\.\d+(?:-[0-9A-Za-z.-]+)?$/u);
const coordinate = `lampclaw/i18n@${version}`;
const cli = `lampclaw/i18n/cmd/i18n@${version}`;
const root = mkdtempSync(join(tmpdir(), "lampclaw-i18n-registry-"));
const state = join(root, "state");
const versionParts = version.split(".").map((part) => Number.parseInt(part, 10));
const supportsLifecycle =
  versionParts[0] > 0 || (versionParts[0] === 0 && versionParts[1] >= 3);
const supportsChunks =
  versionParts[0] > 0 || (versionParts[0] === 0 && versionParts[1] >= 4);
const supportsResolution =
  versionParts[0] > 0 || (versionParts[0] === 0 && versionParts[1] >= 6);
const supportsDefaultFunctions =
  versionParts[0] > 0 || (versionParts[0] === 0 && versionParts[1] >= 7);
const supportsMessageProfiles =
  versionParts[0] > 0 || (versionParts[0] === 0 && versionParts[1] >= 8);
const standardMessageProfile = "unicode-mf2-ldml48.2-js-v1";
const messageProfileArgs = supportsMessageProfiles
  ? ["--message-profile", standardMessageProfile]
  : [];

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

const runFailure = (command, args, options = {}) => {
  const result = spawnSync(command, args, {
    cwd: options.cwd ?? root,
    encoding: "utf8",
    env: {
      ...process.env,
      LAMPCLAW_I18N_STATE_DIR: state,
      ...options.env,
    },
    stdio: "pipe",
  });
  if (result.error) throw result.error;
  assert.notEqual(result.status, 0, `${command} unexpectedly succeeded`);
  return `${result.stdout ?? ""}\n${result.stderr ?? ""}`;
};

try {
  run("moon", [
    "new",
    "--user",
    "smoke",
    "--name",
    "app",
    "smoke/app",
  ]);
  const consumer = join(root, "smoke", "app");
  run("moon", ["add", coordinate], { cwd: consumer });
  // The pinned Moon release's `moon new` template is not byte-for-byte in the
  // form accepted by its own formatter (`[]` becomes `[ ]`, and the empty
  // root package gains a newline). Normalize the fresh scaffold before the
  // final `moon fmt --check` validates the generated application.
  run("moon", ["fmt"], { cwd: consumer });
  const versionOutput = run("moonx", [cli, "--version"], {
    cwd: consumer,
    capture: true,
  }).trim();
  assert.equal(versionOutput, `moon-i18n ${version}`);

  const app = join(root, "scaffolded");
  run("moonx", [cli, "scaffold", "smoke/scaffolded", app], {
    cwd: consumer,
  });
  run("moon", ["update"], { cwd: app });
  assert.ok(existsSync(join(app, "i18n", "generation-manifest.json")));
  assert.match(
    readFileSync(join(app, "i18n", "generation-manifest.json"), "utf8"),
    /"manifestVersion": 1/u,
  );

  writeFileSync(
    join(app, "localization", "locales", "zh-CN.json"),
    '{"common":{"hello":"你好 {$missing}"}}\n',
  );
  const diagnosticOutput = runFailure(
    "moonx",
    [
      cli,
      "check",
      "--diagnostic-format=json",
      "localization/config.json",
      "localization/schema.json",
      "localization/locales",
      "i18n",
      "public/i18n",
    ],
    { cwd: app },
  );
  assert.match(diagnosticOutput, /"code": "I18N3001"/u);
  assert.match(diagnosticOutput, /localization[/\\]locales[/\\]zh-CN\.json/u);
  writeFileSync(
    join(app, "localization", "locales", "zh-CN.json"),
    '{"common":{"hello":"你好 {$name}"}}\n',
  );

  run(
    "moonx",
    [
      cli,
      "generate",
      "localization/config.json",
      "localization/schema.json",
      "localization/locales",
      "i18n",
      "public/i18n",
    ],
    { cwd: app },
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
  const generatedBefore = statSync(join(app, "i18n", "generated.mbt"));
  const manifestBefore = statSync(
    join(app, "i18n", "generation-manifest.json"),
  );
  run(
    "moonx",
    [
      cli,
      "generate",
      "localization/config.json",
      "localization/schema.json",
      "localization/locales",
      "i18n",
      "public/i18n",
    ],
    { cwd: app },
  );
  const generatedAfter = statSync(join(app, "i18n", "generated.mbt"));
  const manifestAfter = statSync(
    join(app, "i18n", "generation-manifest.json"),
  );
  assert.equal(generatedAfter.ino, generatedBefore.ino, "no-op replaced code");
  assert.equal(
    generatedAfter.mtimeMs,
    generatedBefore.mtimeMs,
    "no-op rewrote code",
  );
  assert.equal(manifestAfter.ino, manifestBefore.ino, "no-op replaced manifest");
  assert.equal(
    manifestAfter.mtimeMs,
    manifestBefore.mtimeMs,
    "no-op rewrote manifest",
  );
  run(
    "moonx",
    [
      cli,
      "check",
      "localization/config.json",
      "localization/schema.json",
      "localization/locales",
      "i18n",
      "public/i18n",
    ],
    { cwd: app },
  );
  const dynamicCatalogName = supportsChunks
    ? "zh-CN--common.json"
    : "zh-CN.json";
  assert.ok(existsSync(join(app, "public", "i18n", dynamicCatalogName)));
  const dynamicCatalog = readFileSync(
    join(app, "public", "i18n", dynamicCatalogName),
    "utf8",
  );
  if (supportsChunks) {
    const deployment = JSON.parse(
      readFileSync(join(app, "public", "i18n", "manifest.json"), "utf8"),
    );
    const entry = deployment.chunks.find(
      (chunk) => chunk.locale === "zh-CN" && chunk.namespace === "common",
    );
    assert.ok(entry, "deployment manifest omitted the Chinese common chunk");
    assert.equal(entry.path, dynamicCatalogName);
    assert.equal(
      createHash("sha256").update(dynamicCatalog).digest("hex"),
      entry.sha256,
    );
  }
  const dynamicInstall = supportsChunks
    ? `match i18n.install_catalog_chunk_source(
    @app_i18n.ZhCN,
    @app_i18n.CatalogCommon,
    source,
  ) {
    Ok(_) => ()
    Err(message) => abort("catalog chunk rejected: \\{message}")
  }`
    : `match i18n.install_catalog_source(@app_i18n.ZhCN, source) {
    Ok(_) => ()
    Err(message) => abort("catalog rejected: \\{message}")
  }`;

  if (supportsLifecycle) {
    const xliff = join(app, "translation.xlf");
    const imported = join(app, "imported-zh-CN.json");
    const exchangeState = join(app, "translation-state.json");
    const exchangeReport = join(app, "translation-report.json");
    run(
      "moonx",
      [
        cli,
        "export-xliff",
        ...messageProfileArgs,
        "localization/schema.json",
        "en-US",
        "localization/locales/en-US.json",
        "zh-CN",
        "localization/locales/zh-CN.json",
        xliff,
      ],
      { cwd: app },
    );
    run(
      "moonx",
      [
        cli,
        "import-xliff",
        ...messageProfileArgs,
        "--state-output",
        exchangeState,
        "--report-output",
        exchangeReport,
        "localization/schema.json",
        "en-US",
        "localization/locales/en-US.json",
        "zh-CN",
        xliff,
        imported,
      ],
      { cwd: app },
    );
    assert.match(readFileSync(exchangeState, "utf8"), /"sourceSha256"/u);
    assert.match(readFileSync(exchangeReport, "utf8"), /"lossCount": 0/u);
    assert.deepEqual(
      JSON.parse(readFileSync(imported, "utf8")),
      JSON.parse(readFileSync(join(app, "localization", "locales", "zh-CN.json"), "utf8")),
    );
    const i18nextOutput = join(app, "i18next-zh-CN.json");
    const i18nextReport = join(app, "i18next-report.json");
    run(
      "moonx",
      [
        cli,
        "import-i18next",
        ...messageProfileArgs,
        "localization/schema.json",
        "zh-CN",
        "localization/locales/zh-CN.json",
        i18nextOutput,
        i18nextReport,
      ],
      { cwd: app },
    );
    assert.match(readFileSync(i18nextReport, "utf8"), /"lossCount": 0/u);
    const arb = join(app, "simple.arb");
    const arbOutput = join(app, "arb-zh-CN.json");
    const arbReport = join(app, "arb-report.json");
    writeFileSync(
      arb,
      '{"@@locale":"zh-CN","common.hello":"你好 {name}"}\n',
    );
    run(
      "moonx",
      [
        cli,
        "import-arb",
        ...messageProfileArgs,
        "localization/schema.json",
        "zh-CN",
        arb,
        arbOutput,
        arbReport,
      ],
      { cwd: app },
    );
    assert.match(readFileSync(arbOutput, "utf8"), /你好 \{\$name\}/u);
    assert.match(readFileSync(arbReport, "utf8"), /"lossCount": 0/u);
  }

  const runtimeImport = supportsResolution
    ?
      '  "lampclaw/i18n/runtime" @runtime,\n' +
      (supportsDefaultFunctions
        ? '  "lampclaw/i18n/runtime/js" @runtime_js,\n'
        : "")
    : "";
  let resolutionSmoke = supportsResolution
    ? `  if @runtime.canonicalize_locale_tag("iw-BU") != Ok("he-MM") {\n    abort("strict BCP 47 canonicalization failed")\n  }\n  let context = match @runtime.Mf2FormattingContext::new(\n    locale="en-US",\n    inputs=[\n      @runtime.Mf2Input::new("name", @runtime.TextValue("MoonBit")),\n    ],\n    bidi_isolation=@runtime.Mf2NoBidiIsolation,\n  ) {\n    Ok(value) => value\n    Err(error) => abort(error.to_string())\n  }\n  let standalone = @runtime.format_mf2_standalone(\n    "Standalone {$name}",\n    context,\n  )\n  if standalone.value != "Standalone MoonBit" || !standalone.errors.is_empty() {\n    abort("standalone MF2 resolution failed")\n  }\n`
    : "";
  const defaultFunctionSmoke = supportsDefaultFunctions
    ? `  let currency = @runtime_js.format_mf2(
    "{42 :currency currency=EUR}",
    context,
  )
  if currency.value != "€42.00" || !currency.errors.is_empty() {
    abort("default-function registry failed")
  }
`
    : "";
  resolutionSmoke = resolutionSmoke + defaultFunctionSmoke;
  const englishExpected = supportsMessageProfiles
    ? '"Hello \\u{2068}MoonBit\\u{2069}"'
    : '"Hello MoonBit"';
  const chineseExpected = supportsMessageProfiles
    ? '"你好 \\u{2068}MoonBit\\u{2069}"'
    : '"你好 MoonBit"';
  writeFileSync(
    join(app, "main", "moon.pkg"),
    `import {\n  "smoke/scaffolded/i18n" @app_i18n,\n${runtimeImport}}\n\nsupported_targets = "js"\n\npkgtype(kind: "executable")\n`,
  );
  writeFileSync(
    join(app, "main", "main.mbt"),
    `///|\nfn main {\n  let i18n = @app_i18n.I18n::new()\n  let en = i18n.translator(@app_i18n.EnUS)\n  if en.t(@app_i18n.Common(@app_i18n.Hello("MoonBit"))) != ${englishExpected} {\n    abort("embedded English translation failed")\n  }\n  if i18n.has_catalog(@app_i18n.ZhCN) {\n    abort("dynamic Chinese catalog was unexpectedly embedded")\n  }\n  let source = ${JSON.stringify(dynamicCatalog)}\n  ${dynamicInstall}\n  let zh = i18n.translator(@app_i18n.ZhCN)\n  if zh.t(@app_i18n.Common(@app_i18n.Hello("MoonBit"))) != ${chineseExpected} {\n    abort("dynamic Chinese translation failed")\n  }\n${resolutionSmoke}  println("registry smoke: Hello MoonBit / 你好 MoonBit")\n}\n`,
  );
  run("moon", ["fmt"], { cwd: app });
  run("moon", ["check", "--deny-warn", "--target", "js"], { cwd: app });
  run("moon", ["fmt", "--check"], { cwd: app });
  run("moon", ["build", "--release", "--target", "js"], { cwd: app });
  const output = run("moon", ["run", "--release", "--target", "js", "main"], {
    cwd: app,
    capture: true,
  });
  assert.match(output, /Hello MoonBit \/ 你好 MoonBit/u);

  if (process.env.LAMPCLAW_TEST_BIN === "1") {
    const binRoot = join(root, "smoke", "binary");
    run("moon", [
      "new",
      "--user",
      "smoke",
      "--name",
      "binary",
      "smoke/binary",
    ]);
    run("moon", ["add", "--bin", coordinate], { cwd: binRoot });
    const launcher = join(
      binRoot,
      "_build",
      "__moonbin__",
      process.platform === "win32" ? "moon-i18n.ps1" : "moon-i18n",
    );
    assert.ok(existsSync(launcher), `binary launcher was not installed: ${launcher}`);
    const binVersion = (process.platform === "win32"
      ? run("pwsh", ["-File", launcher, "--version"], {
          cwd: binRoot,
          capture: true,
        })
      : run(launcher, ["--version"], { cwd: binRoot, capture: true })
    ).trim();
    assert.equal(binVersion, `moon-i18n ${version}`);
  }
  console.log(`registry smoke passed for ${coordinate}`);
} finally {
  if (process.env.LAMPCLAW_KEEP_SMOKE !== "1") {
    rmSync(root, { recursive: true, force: true });
  } else {
    console.log(`kept smoke module at ${root}`);
  }
}
