import assert from "node:assert/strict";
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
  assert.ok(existsSync(join(app, "public", "i18n", "zh-CN.json")));
  const dynamicCatalog = readFileSync(
    join(app, "public", "i18n", "zh-CN.json"),
    "utf8",
  );

  writeFileSync(
    join(app, "main", "moon.pkg"),
    'import {\n  "smoke/scaffolded/i18n" @app_i18n,\n}\n\nsupported_targets = "js"\n\npkgtype(kind: "executable")\n',
  );
  writeFileSync(
    join(app, "main", "main.mbt"),
    `///|\nfn main {\n  let i18n = @app_i18n.I18n::new()\n  let en = i18n.translator(@app_i18n.EnUS)\n  if en.t(@app_i18n.Common(@app_i18n.Hello("MoonBit"))) != "Hello MoonBit" {\n    abort("embedded English translation failed")\n  }\n  if i18n.has_catalog(@app_i18n.ZhCN) {\n    abort("dynamic Chinese catalog was unexpectedly embedded")\n  }\n  let source = ${JSON.stringify(dynamicCatalog)}\n  match i18n.install_catalog_source(@app_i18n.ZhCN, source) {\n    Ok(_) => ()\n    Err(message) => abort("catalog rejected: \\{message}")\n  }\n  let zh = i18n.translator(@app_i18n.ZhCN)\n  if zh.t(@app_i18n.Common(@app_i18n.Hello("MoonBit"))) != "你好 MoonBit" {\n    abort("dynamic Chinese translation failed")\n  }\n  println("registry smoke: Hello MoonBit / 你好 MoonBit")\n}\n`,
  );
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
