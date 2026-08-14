# Contributing

Use toolchain archive `0.10.6+80dc50f24` (Moon `0.1.20260803`, moonc `0.10.6`)
and Node.js `26.7.0` for the engineering and product gates. Dependency versions
in `moon.mod` must stay exact.

## Roadmap and architectural changes

Before planning or implementing a public API, authoring format, MF2 profile,
catalog contract, runtime, generator, CLI, or supported-target change, read
both the [product roadmap](docs/roadmap.mbt.md) and the
[current MF2 profile](docs/mf2-profile.mbt.md).

The change description must identify the roadmap milestone and user problem,
the MoonBit package/target boundary, compatibility and migration impact, and
the acceptance gate it advances. Work outside the active milestone needs a
measured blocker or consumer requirement. A deliberate change in direction
must update `docs/roadmap.mbt.md` and
`docs/roadmap.zh-CN.mbt.md` together and synchronize the README and changelog.
Planned behavior must never be presented as implemented or conformant.

Before submitting a change, run:

```bash
moon update
moon info --frozen
moon fmt --check
moon check --frozen --deny-warn --target native
moon check --frozen --deny-warn --target wasm
moon check --frozen --deny-warn --target wasm-gc
moon check --frozen --deny-warn --target js
moon test --frozen --deny-warn --target native
moon test --frozen --deny-warn --target wasm
moon test --frozen --deny-warn --target wasm-gc
moon test --frozen --deny-warn --target js
npm ci
node scripts/check-coverage.mjs
node scripts/check-api-docs.mjs
node scripts/check-doc-sync.mjs
node scripts/check-mf2-requirements.mjs
node scripts/check-mf2-differential.mjs
node scripts/check-mf2-profile.mjs
node scripts/check-benchmarks.mjs
node scripts/package-smoke.mjs
moon run --frozen --target wasm cmd/i18n -- check \
  examples/rabbita_todo/localization/config.json \
  examples/rabbita_todo/localization/schema.json \
  examples/rabbita_todo/localization/locales \
  examples/rabbita_todo/i18n \
  examples/rabbita_todo/public/i18n
npx playwright install chromium firefox webkit
npm run test:browser
```

Tests should cover the observable success and failure contract. Do not weaken
catalog limits, ownership checks, formatter error boundaries, coverage
thresholds, or performance budgets without documenting the measured reason in
the pull request and changelog.

Generated files are updated only through `cmd/i18n`; never hand-edit a
generated facade, catalog, or ownership manifest. Run `moon info` last when a
public interface changes and commit the resulting `pkg.generated.mbti` files.

Documentation synchronization is mandatory before every release. The English
and Chinese README, profile, migration, diagnostics, support-policy, and
roadmap documents plus `CHANGELOG.md` must be updated in the release commit;
`node scripts/check-doc-sync.mjs` and `node scripts/check-api-docs.mjs` are
blocking gates, not post-publish cleanup.

After publishing a stable release, push its verified signed tag to dispatch
the `Registry smoke` workflow with the exact version. It validates `moon add`, pinned `moonx` execution,
project-local `moon add --bin`, generation, JavaScript execution, and dynamic
catalog installation on Linux, macOS, and Windows.

Moon `0.1.20260803` / `mooncake-bin 0.1.20260731` and the current publish
client used for `0.2.0` have a known dry-run exit-status mismatch. Follow the exact acceptance and no-automatic-retry
rules in the repository's release checklist; do not treat exit 255 as a
general success code. This release tracks the behavior locally and does not
require an upstream report. Maintainers should run
`node scripts/publish-dry-run.mjs`; the helper can only perform a dry run and
will reject every response that does not meet the documented conditions.
