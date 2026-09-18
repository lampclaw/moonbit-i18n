# Unreleased core-maintenance verification

Date: 2026-09-18

This records local validation of the two core fixes following `0.9.1`.
It is not a release acceptance or a Registry upgrade: the module version
remains `0.9.1`, and no publication, release tag, or remote push was performed.
Development remains on `0.x` until MoonBit officially releases `1.0`, after
which this project's independent acceptance gates must still pass.

## Changes and regression evidence

- Base revision: `4b879f4`.
- Locale fix: `2b17d28` includes chunk-only installed locales in runtime
  negotiation while leaving generated-facade locale selection unchanged.
  Both added regression cases failed against the original implementation
  (`en-US` instead of `fr`, and `fr` instead of `fr-CA`) and passed after
  the change. Cases also cover parent lookup, multiple namespaces,
  per-message fallback, and rejected installation/replacement.
- Output fix: `4bde93b` checks the existing 65,536-byte limit before
  accumulating text and its associated structured parts. Seven new active
  tests per backend cover source/model entrypoints, ASCII and multibyte
  boundaries, bidi, cross-part surrogate pairs, backend-specific unpaired
  surrogate behavior, fallback bounds, and error ordering. The repeated
  1 KiB custom formatter stops after 65 resolve/render calls rather than
  evaluating all 4,096 expressions. Tail handlers are not invoked.
- Public interfaces, the generator template, message profiles, wire
  contracts, dependencies, and published resource budgets are unchanged.
  Caller allocations, custom-handler internal work, and aggregate structured
  metadata remain outside the text-output accumulation guarantee.

## Pinned Linux validation

The existing release baseline was installed in a separate temporary directory:
Moon `0.1.20260819`, moonc `0.10.9+6e6c44045`, Node `26.7.0`.
The global toolchain was not replaced. The installer checksum matched the CI
pin; the Node archive matched the official version's SHA-256 manifest.

| Gate | Result |
|---|---|
| Native frozen check/test with `--deny-warn` | 203/203 tests passed |
| Wasm frozen check/test with `--deny-warn` | 203/203 tests passed |
| Wasm-GC frozen check/test with `--deny-warn` | 181/181 tests passed |
| JavaScript frozen check/test with `--deny-warn` | 195/195 tests passed |
| Format and public-interface snapshot | Passed; three interface hashes and template unchanged |
| Public API documentation | All 213 items documented |
| Documentation, version, profile and requirement checks | Passed; 11 bilingual pairs and 77 requirement rows |
| Pinned upstream fixtures and generated tests | Passed; syntax/model, resolution, default functions and IANA registry |
| Independent differential suite | 24 cases passed; no unexplained differences |
| Chromium, Firefox and WebKit | 33/33 scenarios passed |
| Extracted-package clean-module smoke | Passed |

Coverage passed existing thresholds: runtime `3866/4273` (90.5%), generator
`1874/2170` (86.4%), CLI `955/1121` (85.2%), aggregate `6695/7564` (88.5%).

The gates use the repository's existing scripts: `check-coverage.mjs`,
`check-contract-snapshot.mjs`, `check-api-docs.mjs`, `check-doc-sync.mjs`,
`check-mf2-profile.mjs`, `check-mf2-requirements.mjs`,
`check-mf2-differential.mjs`, fixture generation/sync scripts with `--check`,
`version-contract.mjs check`, `npm run test:browser`, and `package-smoke.mjs`.

## Performance and rebuilt browser size

`check-benchmarks.mjs` passed its normal three-sample median gate without
requiring the seven-sample fallback. Values are compared with the existing
reference budgets, not claimed as a same-machine before/after speedup.

| Benchmark | Median, microseconds | Reference ratio |
|---|---:|---:|
| Compiled formatting | 0.113 | 0.45x |
| Standalone model formatting | 2.600 | 0.52x |
| 10,000-message catalog lookup | 0.020 | 0.33x |
| Cached Intl number formatting | 2.170 | 0.54x |
| MF2 default number formatting | 6.010 | 0.67x |

The freshly rebuilt Rabbita application passed `check-web-size.mjs`:

| Artifact | Bytes | Existing ceiling |
|---|---:|---:|
| JavaScript | 455,928 | 458,752 |
| JavaScript gzip | 122,607 | 131,072 |
| Embedded locale chunks | 2,068 | 8,192 |
| Largest dynamic chunk | 1,108 | 65,536 |
| Deployment manifest | 2,131 | 65,536 |

Compared with the recorded `0.9.1` artifact, the application grows by 692 raw
bytes and 316 gzip bytes. Raw headroom is 2,824 bytes. These are whole
application figures, including its framework; they are not standalone i18n
library sizes. No budget was raised.

## Additional toolchain observation

On the separately installed current toolchain, Moon `0.1.20260915` / moonc
`0.10.13` and Node `26.9.0`, the runtime JavaScript suite passed 126/126 tests.
The supplementary `--deny-warn` check failed on existing deprecated APIs,
including `StringBuilder::new()`. This does not expand the supported matrix
or replace the pinned-baseline results. Toolchain modernization remains a
separate maintenance task; warnings were not disabled in the release gates.

## Consumer validation

Consumer verification is performed in disposable copies with a workspace
override to the patched library source. The original consumers remain on their
existing exact dependencies. This is source compatibility evidence, not proof
of a new published version or a completed consumer Registry migration.

| Consumer revision | Existing `0.9.0` baseline | Patched source with original consumer dependencies |
|---|---|---|
| LampClaw `2800511` | Full `bun run test` and `build` passed; 25 consumer tests | Passed |
| APEXLS `1a9fc29` | Full `bun run check` passed; 11 Bun and 11 MoonBit consumer tests | Passed |
| Bingque `953b56b` | Full `bun run test` and `build` passed; 100 main, 4 release-doc, 7 tutorial and 1 course tests | Failed on an existing dependency migration blocker |

Bingque pins Rabbita `0.15.2`. Both the patched source and the explicitly
archived, unmodified control `4b879f40fb090de86f302abf94d7207b154b8a71`
produce the same 17 header-type diagnostics in Rabbita's HTTP package. The
`0.9.1` library's existing dependency graph selects `moonbitlang/async@0.21.0`,
whose header keys use `CaseInsensitiveString`. The two runtime fixes do not
change that graph. This prevents claiming compatibility with Bingque's
unchanged dependency set.

In a disposable Bingque copy only, changing Rabbita `0.15.2` to `0.15.4`
made the full tests and build pass. Its direct `moonbitlang/x` declaration
was not edited. This is a validated migration path, not a migration applied
to the original project.

The initial package-script checks used each consumer's published `0.9.0`
CLI with the patched runtime workspace override. A separate pass built the
local patched CLI, regenerated outputs only in disposable copies, and passed
its `generate`/`check` plus subsequent JavaScript tests and release builds.
This passed for LampClaw and APEXLS with unchanged dependencies, and for
Bingque with the explicitly noted temporary Rabbita upgrade. Repeated local
generation preserved bytes, inode, and modification time for all 36 LampClaw,
32 Bingque, and 14 APEXLS generated files. Workspace test totals include
library tests and are not reported as consumer-only counts above.

Original repositories retained clean Git status and identical tracked and
untracked nonignored file hashes. No original dependency or generated file
was changed. No consumer production deployment or consumer-browser run was
performed; browser evidence above is for this library's maintained harness.

Raw logs and structured local results were retained under
`/tmp/moonbit-i18n-core-fix.qnIy9k/`, including `quality-results.json`,
`integration-results.json`, `coverage.log`, `benchmarks.log`, and the
`consumers/` verification records. These temporary files are supplemental;
the immutable source revisions and reproducible checks above define this
record.
