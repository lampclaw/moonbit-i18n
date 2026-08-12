# Changelog

All notable changes to this project are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and releases use
[Semantic Versioning](https://semver.org/).

## [Unreleased]

### Added

- Public English and Chinese product roadmaps with MoonBit-native design
  principles, ecosystem comparisons, versioned acceptance gates, and
  repository governance for future development.

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

[Unreleased]: https://github.com/lampclaw/moonbit-i18n/compare/v0.1.0-rc.1...HEAD
[0.1.0-rc.1]: https://github.com/lampclaw/moonbit-i18n/tree/v0.1.0-rc.1
