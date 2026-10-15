# Changelog

All notable changes to this project are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and releases use
[Semantic Versioning](https://semver.org/).

## [Unreleased]

## [0.9.3] - 2026-10-15

### Changed

- Move the supported build baseline to MoonBit `0.10.15+943464bfa`
  (Moon `0.1.20261012`), parser `0.4.4`, async `0.22.4`, and
  `moonbit-community/normalization@0.5.2`. The normalization dependency retains
  the same Unicode 16.0.0 data. The example uses Rabbita `0.16.5` and Warren
  `0.4.5`; Node `26.7.0` and Playwright `1.62.1` remain pinned.
- Preserve previously implicit `Eq` and `Debug` methods with explicit exports.
  Keep the original 1.0 candidate snapshot and separately record the reviewed
  compiler representation; CI verifies both the new hashes and the original
  signatures after removing only those derived-method declarations.
- Use `.moonignore` for archive exclusions supported by the new Moon release.
  Keep benchmark packages under the excluded `benchmarks/` directory so
  extracted consumers do not inherit unused test-only imports.
- Record the approved build-migration size exception: 496,495 raw JavaScript
  bytes and 145,326 gzip bytes, with ceilings of 512 KiB / 160 KiB (formerly
  448 KiB / 128 KiB). Catalog, conformance, coverage, and performance limits
  remain unchanged. Warren now uses its bundled Evol minifier; remove the
  unused Terser development dependency.
- Replace deleted repository tag links with immutable source commits. Releases
  are identified by full source SHA, exact package version, and archive SHA-256;
  Registry smoke is dispatched manually with all three values.
- Record the verified dry-run exit-255 mismatch for Moon `0.1.20261012` with
  `mooncake-bin 0.1.20260911`. Accept it only after both archive checks and the
  exact version-specific Registry success response; real publication retains
  the single-attempt rule.

### Fixed

- Bound each application-owned catalog request to 10 seconds, including
  response-body reading. Decode strict UTF-8 incrementally, reject bytes beyond
  generated metadata or the 64 KiB chunk ceiling, and cancel failed streams.
- Ignore completions from earlier loading attempts, preserve the active locale
  and saved preference on failure, and retry only missing catalog chunks.
  Six new scenarios run in each of Chromium, Firefox, and WebKit, including
  invalid UTF-8 and same-length catalog tampering before installation.

## [0.9.2] - 2026-09-18

### Fixed

- Include locales installed only through catalog chunks when
  `I18n::translator_from_code` negotiates among installed catalogs. Locale
  normalization, parent lookup, configured fallback, and generated-facade
  locale selection retain their existing behavior.
- Enforce the existing 64 KiB MF2 output limit incrementally before appending
  each text or formatted-expression contribution, including bidi controls.
  Stop pattern evaluation on overflow, retain errors already discovered, and
  return the bounded whole-message fallback without evaluating the remaining
  pattern or allocating its combined output. This bounds core output
  accumulation, not allocations owned by callers or custom formatters, and
  introduces no new byte-size contract for structured metadata.

### Changed

- Keep development on `0.x` until MoonBit officially releases `1.0`.
  Considering `lampclaw/i18n` `1.0.0` then still requires the project's
  compatibility, conformance, and real-consumer acceptance gates; the upstream
  release does not automatically promote this library.

## [0.9.1] - 2026-08-24

### Changed

- Advanced the exact release toolchain to archive
  `0.10.9+6e6c44045` (Moon `0.1.20260819`, moonc `0.10.9`) and updated
  the direct `moonbitlang/x`, `parser`, and `async` pins to `0.5.1`,
  `0.3.18`, and `0.21.0`. This is the supported build baseline for
  `0.9.1`; `0.9.0` remains the immutable release for its older exact pin.
- Updated CI to `actions/setup-node@v7.0.0`, Warren `0.3.2`, its explicit
  browser entry/output contract, and a project-local Terser `5.50.0` pin.
  The maintained Rabbita application now pins Rabbita `0.15.4` and
  `moonbitlang/x@0.5.1`.
- Regenerated the committed Rabbita facade with the current MoonBit formatter.
  The byte-level formatting and generation-manifest checksum changed, while
  the generated API, public MoonBit interfaces, generator template, message
  profiles, catalog format, CLI surface, wire contracts, supported targets,
  and Node/browser host policy remain unchanged from the `0.9.0` candidate.

### Fixed

- Kept the Rabbita release artifact within the existing Web delivery budgets
  after the dependency upgrade by using an application-owned, same-origin
  catalog text loader instead of linking Rabbita's general-purpose HTTP stack;
  three-browser acceptance now covers HTTP/network failure and retry directly.
- Made the frozen 1.0 contract check derive the current CLI version from
  `moon.mod`, while retaining `0.9.0` as the candidate snapshot release.
- Clarified that pre-1.0 security fixes apply to the latest published `0.x`
  release rather than the obsolete `0.1.x` line.

## [0.9.0] - 2026-08-15

### Added

- An immutable standards freeze for official Unicode MessageFormat WG tag
  `LDML48.2`, CLDR 48.2, CLDR JSON 48.2.0, the 2026-08-08 IANA Language
  Subtag Registry, and the Node 26.7.0 `Intl` host policy.
- A 77-row one-to-one anchored normative requirement matrix covering syntax,
  data model, resolution, selection, fallback, bidi, errors, stable default
  functions, and all 40 stable options. Every row is passed or has a public
  not-applicable rationale; blockers and unexplained gaps are zero.
- A real browser conformance harness that executes the MoonBit parser,
  resolver, formatter, upstream fixtures, and differential cases in Chromium,
  Firefox, and WebKit instead of only testing the example UI.
- A published `docs/contracts/1.0-candidate.json` snapshot locking public
  MoonBit interface hashes, the generated facade template, profile names,
  catalog/diagnostic/manifest versions, CLI commands, diagnostic codes, and
  the Node/browser support matrix.

### Changed

- Stable authoring now uses `unicode-mf2-ldml48.2-js-v2`, containing the six
  stable functions and rejecting Draft date/time behavior. Draft `:date`,
  `:time`, and `:datetime` moved behind the separately named
  `unicode-mf2-ldml48.2-js-v2+experimental-datetime-v1` profile.
- Omitting `messageProfile` is now error `I18N1003`. Legacy standards v1 is a
  warned migration bridge with `I18N1004`; explicit compatibility authoring
  remains available.
- Standalone pseudo-locale, XLIFF, i18next, and ARB CLI commands now require
  `--message-profile`, eliminating an implicit semantics choice outside an
  application config.
- Differential evidence is split into 20 stable and 4 experimental datetime
  cases. Upstream function evidence is split into 104 stable and 20
  experimental cases; both sets remain executable, but only stable v2 belongs
  to the conformance-candidate claim.
- Rabbita explicitly selects the experimental datetime profile because its
  browser contract intentionally exercises Draft date formatting. Applications
  without those functions use stable v2.

### Fixed

- Stable numeric, offset, currency, percent, and date/time resolved values now
  inherit the formatting-context direction. This removes unnecessary FSI/PDI
  isolation around same-direction values while preserving normative isolation
  when directions differ or are unknown.

### Security

- Stable generated catalogs reject Draft, private, and unknown functions
  before installation. Every profile remains part of the catalog contract
  hash, so stable, experimental, legacy, and compatibility catalogs cannot be
  mixed accidentally.
- Browser conformance runs retain host `Intl` fingerprints, keeping CLDR/ICU
  data differences visible and separate from semantic failures.

## [0.8.0] - 2026-08-14

### Added

- Explicit `messageProfile` authoring with the aggregate
  `unicode-mf2-ldml48.2-js-v1` standards profile across config validation,
  profile-specific contract hashing, catalog-v2/chunk generation, deployment
  manifests, generated `MESSAGE_PROFILE`, and runtime installation.
- Compatibility migration diagnostics: omitted profiles continue as
  strict-v1 with warning `I18N1003`; private `:lampclaw:datetime` usage warns
  as `I18N3003` in compatibility mode and fails as `I18N3004` in standards
  mode. Human and JSON warnings are emitted on successful CLI commands.
- A machine-readable requirement matrix mapping 20 scoped normative rows,
  every stable default function, and all 40 stable options to executable
  evidence, with a checker that rejects missing or unexplained gaps.
- A Node 26-only independent differential suite pinned to
  `messageformat@4.0.0`. Its 24 cases distinguish exact/error semantics from
  host CLDR text; the accepted report has no unexplained semantic failures.
- English and Chinese message-profile migration guides covering staged
  compatibility, private datetime conversion, bidi-visible test changes, full
  regeneration, and atomic deployment.

### Changed

- New CLI scaffolds and the maintained Rabbita browser application now author
  standards-mode messages. The private datetime example uses standard `:date`;
  generated application calls and catalog wire version remain unchanged.
- Pseudo-locale, XLIFF lifecycle, i18next, and ARB tooling accept the selected
  message profile through their APIs and CLI `--message-profile` option, so
  standards-mode messages are validated end to end without weakening the
  compatibility default.
- `I18n` compiles compatibility catalogs to the legacy model and standards
  catalogs to the pinned MF2 model before an atomic install, then dispatches
  text and rich-parts formatting through the matching evaluator.
- Performance acceptance now uses the median of three process-isolated samples
  and expands only an initial over-budget result to seven samples. CI
  annotations include exact failing measurements. The structured MF2-number
  reference budget is 9 µs, covering the measured Node 26 hosted-runner
  envelope; the 1.5× regression ratio and 20 µs absolute ceiling remain
  unchanged.
- The standards-profile Rabbita bundle is measured at 429 KiB raw / 116 KiB
  gzip (76 KiB Brotli). Its checked ceilings are now 448/128 KiB because
  dynamic standards catalogs retain the complete runtime MF2 validator and
  formatter; generation-only dependencies remain unreachable.
- Release policy now treats synchronized bilingual README, profile, migration,
  roadmap, changelog, version, and API documentation as a checked pre-publish
  gate.

### Security

- Standards-mode generated and dynamic catalogs reject private or unknown
  functions before installation; profile and contract mismatches fail closed,
  so compatibility and standards catalogs cannot be mixed in one runtime.
- Whole catalogs and namespace chunks for one locale reject conflicting text
  directions before mutation, keeping bidi isolation deterministic.
- Full-model schema validation rejects undeclared variables and undeclared
  rich-markup names before generated artifacts are written.

## [0.7.0] - 2026-08-14

### Added

- Pinned `unicode-mf2-ldml48.2-default-functions-v1` registry implementing the
  stable required `:string`, `:number`, `:integer`, `:offset`, `:currency`, and
  `:percent` functions, including option inheritance, exact/cardinal/ordinal
  selection, and typed function errors.
- Roadmap-required draft `:date`, `:time`, and `:datetime` functions with
  strict ISO operands, semantic fields, explicit context time zones, and a
  separately documented non-stable status.
- Public portable `Mf2FunctionRegistry`, namespaced NFC-safe custom handlers,
  lazy operands/results, structured formatter fields, and non-fatal handler
  issues. Custom behavior is excluded from Unicode conformance claims.
- Complete Node 26 `Intl.NumberFormat`, `Intl.PluralRules`, and
  `Intl.DateTimeFormat` provider with bounded caches and host exceptions kept
  inside typed result boundaries.
- SHA-256-pinned default-function specifications and generated tests for all
  124 upstream currency, date/time, integer, number, offset, percent, and
  string cases.

### Changed

- `format_mf2_standalone` now uses the portable default registry. JavaScript
  consumers use `runtime/js.format_mf2` for the complete `Intl` provider.
- Structured expressions now retain renderer-independent number/date fields,
  while the existing generated strict-v1 catalog authoring path remains
  unchanged until the explicit `0.8.x` profile migration.

### Security

- Custom identifiers reject missing/reserved namespaces and NFC-equivalent
  collisions; platform formatting never executes renderer content, and
  malformed date/time or numeric operands fail through bounded typed errors.

## [0.6.0] - 2026-08-14

### Added

- Standalone `unicode-mf2-ldml48.2-resolution-v1` profile with source-ordered,
  at-most-once declaration resolution, normative option processing,
  multi-selector Match/BetterThan ranking, and lazy selected-pattern
  formatting.
- Best-effort `Mf2FormatResult` carrying concatenated text, safe structured
  parts, and deterministic typed errors; normative variable, literal,
  function-only, and whole-message fallback representations are preserved.
- Default Unicode bidi isolation with explicit direction metadata,
  `u:dir`/`u:id`, and an opt-out strategy for presentation layers that provide
  equivalent isolation.
- Renderer-independent markup events retaining kind, name, resolved inert
  options, attributes, and IDs without executing HTML, DOM, or callbacks.
- Strict RFC 5646 canonicalization and RFC 4647 lookup APIs generated from the
  pinned IANA Language Subtag Registry dated 2026-08-08, including
  Preferred-Value mappings, extlang handling, extension ordering, and explicit
  collision errors.
- SHA-256-pinned upstream formatting/error references and generated tests for
  all 67 fallback, pattern-selection, bidi, and Unicode-option fixtures.

### Changed

- The pre-0.6 `normalize_locale_code` and `resolve_locale_code` APIs retain
  their broad compatibility behavior; standards-facing code can opt into the
  strict typed boundary without silently invalidating existing catalogs.
- The existing generated authoring/catalog path remains on
  `lampclaw-mf2-strict-v1+lampclaw-datetime-v1`. Stable default functions and a
  public custom registry remain intentionally gated to 0.7.

### Security

- Standalone formatting enforces 64-input and 64-KiB output limits, returns a
  bounded whole-message fallback on overflow, never infers direction by
  scanning untrusted text, and never interprets localized markup as executable
  renderer source.

## [0.5.0] - 2026-08-14

### Added

- Standalone `unicode-mf2-ldml48.2-syntax-v1` parser for the complete pinned
  Unicode MessageFormat grammar, with separate well-formedness and validity
  APIs, compact complex messages, declarations, expressions, options,
  attributes, markup, selectors, variants, and quoted forms.
- Public normative interchange model with deterministic functional MF2 syntax
  serialization and deterministic JSON encode/decode. Unknown JSON extension
  fields are ignored while invalid model shapes fail closed.
- Unicode 16 NFC normalization for names and NFC-equivalent duplicate
  declaration, option, and variant detection.
- Stable machine-readable `Mf2ErrorCode` values for syntax, validity,
  resolution, formatting, and resource-limit categories.
- Vendored Unicode-licensed pinned syntax/data-model fixtures, reproducible
  SHA-256-verified sync/generation scripts, and all-target tests covering 114
  accepted syntax, 133 syntax-error, and 23 data-model cases.

### Changed

- The existing catalog, generator, and generated application workflow remains
  on `lampclaw-mf2-strict-v1+lampclaw-datetime-v1`; the new syntax profile is
  deliberately standalone until resolution and authoring-profile phases land.
- Runtime now uses `tonyfettes/normalization@0.4.0` for portable NFC behavior.

### Security

- Syntax, public models, and interchange JSON are validated before
  serialization or acceptance and retain explicit byte, nesting, declaration,
  variant, option, and pattern-part limits.

## [0.4.0] - 2026-08-14

### Added

- Independently deployable locale/namespace catalog-v2 chunks generated from
  the existing canonical locale JSON, plus a deterministic deployment manifest
  with paths, byte counts, SHA-256 digests, message counts, direction, and
  embedded-locale metadata.
- Typed generated `CatalogNamespace` and `CatalogChunkMetadata` APIs, atomic
  chunk installation, per-namespace readiness, and whole-locale completion
  checks.
- English and Chinese production Web delivery contracts with framework-neutral
  loading, HTTP cache, integrity, retry, route commit, and fallback recipes.
- Enforced raw and gzip size budgets for browser JavaScript, embedded-locale
  chunks, dynamic chunks, and the deployment manifest.

### Changed

- CLI catalog output now contains `manifest.json` and flat portable
  `<locale>--<namespace>.json` chunks. Whole-locale catalog-v2 parsing and the
  in-memory generator compatibility field remain available.
- The maintained Rabbita browser application loads `common` and `todo_ui`
  independently, verifies generated byte/SHA-256 metadata in application code,
  retries only missing chunks, and deliberately exercises fallback for an
  unloaded namespace.
- Generated `has_catalog(locale)` now reports complete generated-namespace
  readiness; route-level code can use `has_catalog_namespace`.

### Fixed

- Namespace-qualified XLIFF `subState` values are now discarded with an
  explicit loss report when their extension namespace cannot be retained,
  preventing a later state-aware export from emitting an unbound prefix.

### Security

- Chunk parsing rejects invalid namespace syntax and messages outside the
  declared namespace. Installation verifies profile, contract, locale,
  namespace, limits, and every MF2 message before atomically replacing working
  data.
- Package and browser acceptance reject corrupt and incompatible chunks,
  verify every deployment-manifest hash, and prove failed replacements preserve
  the previous translation.

## [0.3.0] - 2026-08-14

### Added

- State-aware XLIFF 2.1 import/export with a versioned exchange-state sidecar,
  source SHA-256 identity, translator notes, standard segment states, supported
  workflow metadata, and a versioned preservation/loss report.
- Explicit versioned ID rename/removal maps with collision checks and loss
  reporting; unknown identities and stale source or target payloads fail
  closed.
- Deterministic one-way importers for common i18next JSON and Flutter ARB,
  including typed placeholder conversion and per-field reports for semantics
  which cannot be represented by canonical locale JSON.
- English and Chinese translation-lifecycle contracts covering authoring,
  sidecars, metadata, migration boundaries, security limits, and the deliberate
  exclusion of PO/POT.

### Changed

- XLIFF translation state is now emitted on standard `segment@state`. The
  earlier `target@state` form remains accepted and is reported as a normalized
  compatibility input.
- `import-xliff` always writes state and report sidecars, using deterministic
  paths next to the locale output unless explicit output paths are supplied.

### Security

- XLIFF lifecycle input enforces bounded bytes, units, nesting and notes;
  rejects unsafe hierarchy, inline XML, invalid metadata, duplicate migrated
  identities and `DOCTYPE`; and reports every intentionally discarded metadata
  item.

## [0.2.1] - 2026-08-14

### Fixed

- `scaffold` now removes the two coordination locks derived from its unique
  staging paths after generation completes. The first generation at the final
  destination therefore leaves exactly one persistent lock per output instead
  of retaining two unreachable staging locks.
- Mooncakes verification now accepts every planned `0.x` version rather than
  rejecting versions outside the original `0.1.0` line.

## [0.2.0] - 2026-08-14

### Added

- Atomic `scaffold` authoring flow for a canonical English/Chinese JavaScript
  module; existing destinations are never overwritten.
- Stable structured diagnostics with codes, source paths, half-open spans,
  terminal output, versioned JSON output, and an in-memory generator API.
- Versioned deterministic generation manifests containing relative
  input/output paths, byte counts, SHA-256 hashes, the profile, and contract
  hash.

### Changed

- Unchanged generation is now a locked true no-op: it creates no stage or
  journal, preserves generated interfaces, and performs no directory swap.
- Stable release tooling, exact-version checks, and Registry smoke tag
  dispatch now accept every planned `0.x` minor instead of being hardcoded to
  `0.1.0`.
- Dry-run validation accepts the publish client's erroneous exit 255 only when
  both archive checks and the exact version-specific registry success response
  prove that no changes were made; every other non-zero result still fails.
- Post-release engineering, browser, Registry smoke, and consumer product
  gates now use Node.js 26.7.0 exclusively; the redundant Node.js 24 matrix is
  no longer maintained.

## [0.1.0] - 2026-08-13

### Added

- First stable Web/JavaScript strict-v1 baseline, promoting the complete
  runtime, typed generated facade, catalog v2, authoring CLI, XLIFF workflow,
  browser contract, packaging, and engineering gates proven by the three
  release candidates below.

### Changed

- Stable version references now use `0.1.0`. Runtime behavior, the catalog
  wire format, generated APIs, and the MF2-derived profile are unchanged from
  the human-approved `0.1.0-rc.3` candidate.

## [0.1.0-rc.3] - 2026-08-13

### Fixed

- The Rabbita Todo example now persists explicit locale choices, restores them
  after refresh through saved/browser/default negotiation, and remains usable
  when browser storage is unavailable. Dynamic catalogs are still validated
  before the restored locale is committed.

## [0.1.0-rc.2] - 2026-08-12

### Added

- Public English and Chinese product roadmaps with MoonBit-native design
  principles, ecosystem comparisons, versioned acceptance gates, and
  repository governance for future development.
- Locked Chromium, Firefox, and WebKit acceptance coverage for dynamic catalog
  loading, failure/retry behavior, number and datetime formatting, rich parts,
  fallback diagnostics, and localized application state.

### Changed

- The Rabbita Todo example now embeds only the English fallback catalog and
  installs the Chinese catalog atomically on first use; invalid catalogs keep
  the active locale unchanged and expose a retry state.

## [0.1.0-rc.1] - 2026-08-12

### Added

- Compile-on-install MF2 data model with typed text and markup-parts output.
- Catalog format v2 with a formatter profile and SHA-256 contract hash.
- Structured translation and formatter failures plus bounded diagnostics.
- Namespace-aware XLIFF 2.1, `en-XA`/`ar-XB` pseudo-locales, transactional
  generation, coverage gates, and performance regression budgets.
- Portable `moonx` CLI execution on Wasm and native desktop targets, with
  cross-process output locks, bounded strict-UTF-8 I/O, and crash recovery.
- Public API and generated-facade documentation, plus a documentation coverage
  gate that exercises the same archive shape used by mooncakes.io.

### Changed

- `DateTime` parameters are replaced by `InstantMillis`.
- Schema, locale, XLIFF, and generated-catalog indexing avoids quadratic
  validation paths at configured limits.
- XLIFF import now requires the source locale and source resource so stale
  translations can be rejected.
- Catalog installation requires an exact v2/profile/contract match; catalog v1
  and `schemaHash` are intentionally unsupported.
- Generated packages opt `generated.mbt` out of host-toolchain formatting, and
  generation uses destination-hashed user-state locks outside output trees.

### Security

- Catalog/message limits, XML `DOCTYPE` rejection, generated-directory
  ownership, and a JavaScript `Intl` exception boundary are enforced.
- CLI input is size-checked before reading and decoded as strict UTF-8;
  aggregate locale, generated source, embedded catalog, XLIFF, parameter, and
  rich-tag limits prevent bounded files from amplifying into unbounded work.
- Transaction journals and ownership manifests are size- and path-bounded,
  and unowned directories containing symlinks or non-file artifacts are never
  adopted.
- Crash recovery preserves any output directory that had not yet been backed
  up when a generation transaction was interrupted.

[Unreleased]: https://github.com/lampclaw/moonbit-i18n/compare/64f92c01c49d265cbfa02d4b7093ed1e5af58949...HEAD
[0.9.3]: https://github.com/lampclaw/moonbit-i18n/compare/53d04dddbb4e9982bba6342daa5d674ac3f328e6...64f92c01c49d265cbfa02d4b7093ed1e5af58949
[0.9.2]: https://github.com/lampclaw/moonbit-i18n/compare/26726f59e510171b0e7905a460282acda52ace0c...53d04dddbb4e9982bba6342daa5d674ac3f328e6
[0.9.1]: https://github.com/lampclaw/moonbit-i18n/compare/cc947d2224cbca74ffe2aebaf458e71fdceb4d7e...26726f59e510171b0e7905a460282acda52ace0c
[0.9.0]: https://github.com/lampclaw/moonbit-i18n/compare/232b4b31d6616ee39ab2e3e140166b5e9ec1d4ee...cc947d2224cbca74ffe2aebaf458e71fdceb4d7e
[0.8.0]: https://github.com/lampclaw/moonbit-i18n/compare/a043da698eda10fd7bddca6e56a2c1e2acf8aba7...232b4b31d6616ee39ab2e3e140166b5e9ec1d4ee
[0.7.0]: https://github.com/lampclaw/moonbit-i18n/compare/bdb9beab6432591e028c9aed3f876b520b5546c5...a043da698eda10fd7bddca6e56a2c1e2acf8aba7
[0.6.0]: https://github.com/lampclaw/moonbit-i18n/compare/e67fe243e47710743ae906d85fa359a6267ef3f5...bdb9beab6432591e028c9aed3f876b520b5546c5
[0.5.0]: https://github.com/lampclaw/moonbit-i18n/compare/b2fe8a4dfa532d0d85bf1830d8c88c5f6b6c607b...e67fe243e47710743ae906d85fa359a6267ef3f5
[0.4.0]: https://github.com/lampclaw/moonbit-i18n/compare/71f037f4fc64a95bd707358f54f67d7037cd9821...b2fe8a4dfa532d0d85bf1830d8c88c5f6b6c607b
[0.3.0]: https://github.com/lampclaw/moonbit-i18n/compare/3cf795119c56da758e3fc49def9c9071c62f26ae...71f037f4fc64a95bd707358f54f67d7037cd9821
[0.2.1]: https://github.com/lampclaw/moonbit-i18n/compare/1fb8f442d6a0fc0e7278b814dfb7d617b973234c...3cf795119c56da758e3fc49def9c9071c62f26ae
[0.2.0]: https://github.com/lampclaw/moonbit-i18n/compare/9bc0398f3f9ae5408fb61d3a431a97fbb34e8cc3...1fb8f442d6a0fc0e7278b814dfb7d617b973234c
[0.1.0]: https://github.com/lampclaw/moonbit-i18n/compare/52e7f7d07acd76c3043cb655e9989add13fdc922...9bc0398f3f9ae5408fb61d3a431a97fbb34e8cc3
[0.1.0-rc.3]: https://github.com/lampclaw/moonbit-i18n/compare/ccd10e158d48ca0a1f8168e7ca0788c916461146...52e7f7d07acd76c3043cb655e9989add13fdc922
[0.1.0-rc.2]: https://github.com/lampclaw/moonbit-i18n/compare/c6d1e32981c280c850b62d70be077d921a83c14e...ccd10e158d48ca0a1f8168e7ca0788c916461146
[0.1.0-rc.1]: https://github.com/lampclaw/moonbit-i18n/tree/c6d1e32981c280c850b62d70be077d921a83c14e
