# Contributing

Use toolchain archive `0.10.6+80dc50f24` (Moon `0.1.20260803`, moonc `0.10.6`)
and Node.js `24.18.1` for the release gate. Node.js `26.x` is an additional
compatibility smoke target. Dependency versions in `moon.mod` must stay exact.

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
node scripts/check-coverage.mjs
node scripts/check-api-docs.mjs
node scripts/check-mf2-profile.mjs
node scripts/check-benchmarks.mjs
node scripts/package-smoke.mjs
moon run --frozen --target wasm cmd/i18n -- check \
  examples/rabbita_todo/localization/config.json \
  examples/rabbita_todo/localization/schema.json \
  examples/rabbita_todo/localization/locales \
  examples/rabbita_todo/i18n \
  examples/rabbita_todo/public/i18n
```

Tests should cover the observable success and failure contract. Do not weaken
catalog limits, ownership checks, formatter error boundaries, coverage
thresholds, or performance budgets without documenting the measured reason in
the pull request and changelog.

Generated files are updated only through `cmd/i18n`; never hand-edit a
generated facade, catalog, or ownership manifest. Run `moon info` last when a
public interface changes and commit the resulting `pkg.generated.mbti` files.

After publishing a release candidate, dispatch the `Registry smoke` workflow
with the exact version. It validates `moon add`, pinned `moonx` execution,
project-local `moon add --bin`, generation, JavaScript execution, and dynamic
catalog installation on Linux, macOS, and Windows.

The pinned Moon `0.1.20260803` / `mooncake-bin 0.1.20260731` pair has a known
dry-run exit-status mismatch. Follow the exact acceptance and no-automatic-retry
rules in the repository's release checklist; do not treat exit 255 as a
general success code. This release tracks the behavior locally and does not
require an upstream report. Maintainers should run
`node scripts/publish-dry-run.mjs`; the helper can only perform a dry run and
will reject every response that does not meet the documented conditions.
