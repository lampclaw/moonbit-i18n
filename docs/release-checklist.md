# Release checklist

## Pinned publish-client behavior

The `0.1.0-rc.2` release uses Moon `0.1.20260803` with bundled
`mooncake-bin 0.1.20260731`. With this exact pair, `moon publish --dry-run`
can finish both archive validations, receive `202 Accepted`, and print the
registry detail `Dry run completed successfully. No changes were made.`, then
still exit 255. The outer `moon` process maps a non-zero `mooncake-bin` result
to its generic `exit(-1)` status; this is a publish-client/protocol
compatibility behavior, not a package-validation failure.

For this release candidate, track the behavior in release evidence and do not
open an upstream report. Treat the dry run as successful despite exit 255 only
when all of the following are true:

1. local package validation completed successfully;
2. validation of the extracted archive completed successfully;
3. the registry status is exactly `202 Accepted`; and
4. the registry detail explicitly says the dry run completed successfully and
   made no changes.

Any missing or different condition is a failed or inconclusive dry run. Never
globally ignore exit 255. In particular, after a real `moon publish`, do not
retry an accepted or otherwise ambiguous request: first verify whether the
exact version exists on mooncakes.io. A release is complete only after the
registry page and a clean-module installation of that exact version succeed.

Run `node scripts/publish-dry-run.mjs` to enforce this rule. The helper is
deliberately limited to `--dry-run`; it cannot perform a real publish. This
checklist and the helper script are repository release assets and are excluded
from the published archive.

## Version and public contract

- [ ] Set the same prerelease version in `moon.mod`, CLI output, README files,
      example dependency, and `CHANGELOG.md`.
- [ ] Confirm the documented strict MF2 profile and pinned Unicode snapshot;
      do not claim full Unicode MF2 conformance.
- [ ] Confirm `docs/support-policy*.mbt.md` matches the exact CI matrix and
      compatibility behavior exercised by this release.
- [ ] Review both public roadmap languages. Confirm their current-status and
      milestone statements match the implementation, README, MF2 profile, and
      changelog; planned behavior must not appear as shipped behavior.
- [ ] Run `node scripts/check-api-docs.mjs`; all exported runtime, generator,
      and formatter items must have non-empty mooncakes.io documentation.
- [ ] Confirm README metadata, repository, SPDX license, keywords, description,
      and all public links render correctly from the packaged archive.

## Quality gates

- [ ] Run the complete command list in `CONTRIBUTING.md` with the pinned
      MoonBit toolchain and Node.js 24; run the Node.js 26 smoke job.
- [ ] Run the portable CLI test matrix on Ubuntu, macOS, and Windows for both
      Wasm and native targets where supported by the runner.
- [ ] Confirm runtime coverage is at least 90%, generator and CLI coverage are
      each at least 85%, and core overall coverage is at least 85%.
- [ ] Confirm every benchmark is within 1.5× of its checked budget and below
      the 20 µs absolute ceiling on the release runner.
- [ ] Regenerate Rabbita through the CLI, run `check`, and verify no generated
      or interface drift remains.
- [ ] Build the Rabbita Todo release artifact and run the locked Playwright
      scenarios on Chromium, Firefox, and WebKit: locale switching, plural,
      number/datetime formatting, rich parts, fallback, dynamic catalog
      installation/failure/retry, and diagnostics.
- [ ] Confirm destination-hashed `*.lampclaw.lock` coordination files stay in
      user state, release artifacts contain none, and generated packages ignore
      `generated.mbt` in `moon fmt`.

## Package boundary

- [ ] Run `moon package --frozen --list`; examples, tests, generated interfaces,
      CI, scripts, local build output, benchmarks, and conformance fixtures must
      not be in the archive.
- [ ] Confirm runtime, generator, CLI, portable formatter, README, changelog,
      security policy, license, profile documents, and both public roadmap
      languages are in the archive. Confirm `AGENTS.md` remains repository-only.
- [ ] Extract the archive in a clean directory and run `moon doc` there.
- [ ] Run `node scripts/package-smoke.mjs` to exercise the actual archive as a
      clean local workspace dependency, generate a bilingual app, run its
      JavaScript output, install a dynamic catalog, and execute the Wasm binary
      launcher.
- [ ] Confirm `moon add lampclaw/i18n@0.1.0-rc.2` is the library workflow and
      `moonx lampclaw/i18n/cmd/i18n@0.1.0-rc.2` is the primary CLI workflow.
- [ ] Treat `moon add --bin lampclaw/i18n@0.1.0-rc.2` and global
      `moon install` as optional compatibility paths, not prerequisites for
      authoring.

## Publish and registry smoke

- [ ] Run frozen build/package checks, then
      `node scripts/publish-dry-run.mjs` and inspect the final archive. The
      current Moon client cannot use `--frozen` for its extracted-package
      verification because that clean directory must install dependencies.
      The helper applies the exact pinned-client acceptance rule above and
      prints the archive checksum. Record its complete output. Do not publish
      from a dirty or unreviewed worktree.
- [ ] Commit the reviewed release tree, confirm it is clean and synchronized
      with the intended remote branch, then create a signed
      `v0.1.0-rc.2` tag locally. Publish only `lampclaw/i18n` from that tagged
      commit. Keep the tag local until the exact registry version and its CLI
      asset are available so the tag-triggered Registry smoke cannot race the
      registry build.
- [ ] Capture the complete output and status of the real `moon publish`. If it
      returns non-zero after an accepted or ambiguous response, inspect
      mooncakes.io for `lampclaw/i18n@0.1.0-rc.2` before considering any retry.
- [ ] In a brand-new temporary module, run `moon add` for the exact version and
      execute the pinned CLI with `moonx`. Dispatch the `Registry smoke`
      workflow with the exact published version to repeat this on Linux,
      macOS, and Windows.
- [ ] Generate a minimal English/Chinese app with only English embedded, then
      run JS check/build and the resulting JavaScript program.
- [ ] Read generated `zh-CN.json`, install it through
      `install_catalog_source`, and verify Chinese output after installation.
- [ ] Test the optional binary installation paths separately; do not let their
      failure obscure successful library and `moonx` consumption.
- [ ] Open the mooncakes.io release page and inspect README, metadata, package
      list, roadmap links, runtime API docs, generator API docs, and formatter
      API docs.
- [ ] Record the registry URL, signed tag, release notes, archive SHA-256, and
      any known RC limitations.

## Release command sequence

Run the real publish only after the reviewed release commit is on `origin/main`
and its required CI jobs pass. The release operator should execute these
commands individually so that an ambiguous registry response cannot flow into
an automatic retry:

~~~bash
git status --short
git diff --check
git fetch origin
git rev-list --left-right --count HEAD...origin/main
moon version --all
mooncake --version
moon whoami
node scripts/publish-dry-run.mjs
~~~

`git status --short` must be empty, the divergence count must be `0 0`, the
tool versions must match the pinned versions above, and `moon whoami` must be
`lampclaw`. After required CI passes, create and verify the immutable release
reference. This release uses the existing Lampclaw ED25519 key through Git's
SSH signing backend; command-local settings avoid changing the user's global
Git configuration:

~~~bash
allowed_signers="$(mktemp)"
printf 'lampclaw@gmail.com %s\n' "$(cat ~/.ssh/id_ed25519_lampclaw_github.pub)" > "$allowed_signers"
git -c gpg.format=ssh \
  -c user.signingkey=~/.ssh/id_ed25519_lampclaw_github.pub \
  tag -s v0.1.0-rc.2 -m "lampclaw/i18n 0.1.0-rc.2"
git -c gpg.format=ssh \
  -c gpg.ssh.allowedSignersFile="$allowed_signers" \
  tag -v v0.1.0-rc.2
test "$(git rev-parse HEAD)" = "$(git rev-list -n 1 v0.1.0-rc.2)"
~~~

Then run the real command exactly once:

~~~bash
moon publish
~~~

If it returns non-zero, stop. Do not rerun it. First open
`https://mooncakes.io/docs/#/lampclaw/i18n/0.1.0-rc.2` and attempt the exact
post-publish smoke below. A successful exact-version install proves the
accepted publish completed even if the pinned client returned 255:

~~~bash
LAMPCLAW_TEST_BIN=1 node scripts/registry-smoke.mjs 0.1.0-rc.2
git push origin v0.1.0-rc.2
~~~

Pushing the verified tag automatically dispatches
`.github/workflows/registry-smoke.yml` for `0.1.0-rc.2`. The manual workflow
dispatch remains available for a later rerun. Inspect the mooncakes.io README,
metadata, package list and API docs, and record the final registry URL and
archive checksum. A `202` response alone is not the final proof; the clean
exact-version consumer smoke is.

## 0.1.0-rc.1 preparation record — 2026-08-12

Completed locally with Moon `0.1.20260803`, moonc
`0.10.6+80dc50f24`, mooncake-bin `0.1.20260731`, and the exact Node.js
`24.18.1` release gate; the JavaScript checks and tests also passed on Node.js
26:

- native, Wasm, Wasm-GC, and JavaScript checks passed with warnings denied;
- target test totals passed: native 115, Wasm 115, Wasm-GC 97, JavaScript 103;
- coverage passed: runtime 90.2%, generator 88.1%, CLI 86.9%, core 88.7%;
- all 109 public runtime, generator, and JavaScript formatter items have API
  documentation in documentation generated from the archive;
- the MF2 profile pin and feature matrix are synchronized, and all three
  benchmark ratios are below 0.5x of their budgets;
- the final archive passed clean-workspace generation, JavaScript build/run,
  dynamic `zh-CN` catalog installation, documentation generation, and CLI
  launcher construction;
- the Rabbita release build passed and contains no generation lock files;
- `node scripts/publish-dry-run.mjs` accepted the exact documented
  `202 Accepted` response and isolated the known exit 255 mismatch; and
- a fresh `moon add lampclaw/i18n@0.1.0-rc.1` probe confirmed that this exact
  version was not already present in the registry at preparation time.

Prepared archive:

~~~text
_build/publish/lampclaw-i18n-0.1.0-rc.1.zip
SHA-256 4b1a1a42700112ff8a619807eb9b3a287c368f56a9dcc8f2221dbfa0b50520fa
~~~

These preparation gates were subsequently completed in the release record
below.

## 0.1.0-rc.1 release record — 2026-08-12

Immutable release identity:

- release commit and signed tag target:
  `c6d1e32981c280c850b62d70be077d921a83c14e`;
- tag: `v0.1.0-rc.1`, verified with Lampclaw ED25519 key fingerprint
  `SHA256:YrC/9aayrFCWl773eSEhE6G3FgROFEc/VQmxTawowDA`;
- archive SHA-256:
  `4b1a1a42700112ff8a619807eb9b3a287c368f56a9dcc8f2221dbfa0b50520fa`;
- release-branch CI:
  <https://github.com/lampclaw/moonbit-i18n/actions/runs/31569675094>;
- same-commit `main` CI:
  <https://github.com/lampclaw/moonbit-i18n/actions/runs/31569886551>.

The real `moon publish` command was invoked exactly once. It started at
`2026-08-12T06:28:42Z`, completed at `2026-08-12T06:28:44Z`, exited 0, and
reported `Server status: 200 OK`. No real-publish retry was attempted.

The Mooncakes manifest subsequently reported version `0.1.0-rc.1`, build
status `success`, creation time `2026-08-12T06:28:44.180486+00:00`, and the
same archive checksum. The registry page is
<https://mooncakes.io/docs/#/lampclaw/i18n/0.1.0-rc.1>.

The source archive became immediately installable. The separately generated
portable Wasm CLI asset initially returned 404, then became available at
`2026-08-12T06:31:58Z`. This approximately three-minute asset-build window was
handled by waiting and checking the asset; the package was not republished.

After the CLI asset became available, a brand-new temporary consumer passed
all of the following against the exact registry version:

- `moon add lampclaw/i18n@0.1.0-rc.1`;
- pinned `moonx lampclaw/i18n/cmd/i18n@0.1.0-rc.1` execution;
- `moon add --bin lampclaw/i18n@0.1.0-rc.1` and its installed launcher;
- English/Chinese resource generation and read-only drift checking;
- JavaScript check, formatting, release build, and execution; and
- generated `zh-CN` catalog loading through `install_catalog_source`.

The Mooncakes assets used by the documentation SPA were also checked directly:
the module metadata and README were present, the package index listed
`cmd/i18n`, `generator`, `runtime`, and `runtime/js`, and the runtime,
generator, and formatter API data were generated successfully. The published
archive does not contain `examples/`; its README links to the tagged repository
example instead.

Finally, a copy of `examples/rabbita_todo` outside the source workspace resolved
the released dependency from Mooncakes, regenerated and checked all 22 messages
in both locales, passed four JavaScript tests, and produced a Warren release
build with its dynamic Chinese catalog.

The authenticated `Registry smoke` workflow was not dispatched from this
environment because no GitHub API credential was available. Its exact Linux,
macOS, and Windows workflow remains available for a manual post-release run;
the equivalent full exact-version smoke passed locally as recorded above.
