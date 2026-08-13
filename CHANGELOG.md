# Changelog

All notable changes to this project are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and releases use
[Semantic Versioning](https://semver.org/).

## [Unreleased]

### Changed

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

[Unreleased]: https://github.com/lampclaw/moonbit-i18n/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/lampclaw/moonbit-i18n/compare/v0.1.0-rc.3...v0.1.0
[0.1.0-rc.3]: https://github.com/lampclaw/moonbit-i18n/compare/v0.1.0-rc.2...v0.1.0-rc.3
[0.1.0-rc.2]: https://github.com/lampclaw/moonbit-i18n/compare/v0.1.0-rc.1...v0.1.0-rc.2
[0.1.0-rc.1]: https://github.com/lampclaw/moonbit-i18n/tree/v0.1.0-rc.1
