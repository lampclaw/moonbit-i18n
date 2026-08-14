# Runtime SPI

[中文](runtime-spi.zh-CN.mbt.md)

This document is for generator, framework, and tooling maintainers. Normal
applications should use their generated i18n package and should not import the
runtime packages directly.

## Package boundary

- `lampclaw/i18n/runtime` contains catalog parsing, locale lookup, the portable
  MF2 compiler, pattern selection, parts formatting, fallback, and diagnostics.
- `lampclaw/i18n/runtime/js` provides the JavaScript `Intl` formatter and its
  bounded formatter caches.
- Generated application packages depend on both and expose app-owned types.

The SPI is public only because generated packages are separate MoonBit
packages. Public visibility does not make it an application authoring surface.

## Compilation and formatting

`compile_mf2_message(source, contract)` validates the source and returns a
`CompiledMessage`. Catalog installation compiles all entries before committing
the catalog, so normal lookup does not reparse message text.

`format_text` and `format_parts` consume a compiled message. Parts are emitted
as `Text`, `Open`, `Close`, and `Standalone`; text formatting rejects markup so
that tags cannot be flattened into an unsafe string by accident. The legacy
`format_mf2_message` and `format_mf2_rich` wrappers remain for low-level
compatibility but compile on each call.

Formatting callbacks return `Result` with `FormatterIssue`. The JS adapter
catches `Intl` constructor and invocation exceptions and converts them to
`InvalidFormatterOption` or `PlatformFormatterFailure`; no JavaScript exception
crosses this formatter boundary.

The separate standards-core path uses `parse_valid_mf2_model` followed by
`format_mf2_model_standalone`, or the convenience
`format_mf2_standalone`. Its `Mf2FormatResult` returns best-effort text,
renderer-independent structured parts, and all discovered typed errors.
`Mf2FormattingContext` requires strict BCP 47 locales and explicit value/message
direction metadata. Catalog-v2 entries with
`unicode-mf2-ldml48.2-js-v1` are parsed once into this model during atomic
installation and formatted through the pinned default registry. Compatibility
catalogs continue to use `CompiledMessage`; see
[`mf2-resolution-formatting.mbt.md`](mf2-resolution-formatting.mbt.md).

For Node 26 JavaScript, `@runtime_js.format_mf2` supplies the pinned stable
default registry and structured `Intl` fields. Frameworks can obtain
`@runtime_js.mf2_registry()`, register `Mf2FunctionHandler` values, and call
`@runtime.format_mf2`. Custom functions must be namespaced and remain outside
Unicode conformance; see
[`mf2-default-functions.mbt.md`](mf2-default-functions.mbt.md).

## Catalog compatibility contract

The `0.8.0` release accepts catalog format version `2` with either the
compatibility profile `lampclaw-mf2-strict-v1+lampclaw-datetime-v1` or the
standards authoring profile `unicode-mf2-ldml48.2-js-v1`. One `I18n` instance
requires exactly one profile; catalogs cannot be mixed. `contractHash` is the
SHA-256 digest of a canonical UTF-8 contract containing the selected profile,
message IDs, parameter types, and allowed markup names. A catalog is accepted
only when version, profile, contract hash, and normalized locale all match.

Parsing and installation are bounded: JSON source and embedded message data
are each limited to 16 MiB, a catalog to 100,000 messages, each message to 64
KiB, and each compiled message to 4,096 declarations and 4,096 variants.
Installation builds the complete compiled map first and changes runtime state
only after every entry succeeds.
Generator configuration is additionally limited to 1,000 locales, 64 MiB of
aggregate UTF-8 locale input, 64 MiB of generated MoonBit source, and 64
parameters or declared rich-part tags per generated message signature. The
low-level formatter accepts at most 64 arguments and 64 options per expression
or markup element.

## Intentional low-level names

- `Catalog::from_generated_entries(...)` creates embedded catalogs from
  generator-owned data.
- `I18n::install_generated_catalog(...)` installs those embedded catalogs.
- `Translator::translate_raw(...)` accepts string IDs and raw message
  arguments for compatibility adapters.
- `Translator::try_t(...)` and `try_t_parts(...)` preserve structured
  `TranslationError`; `t(...)` and `t_parts(...)` are lossy convenience paths.
- `parse_catalog(...)` and catalog-source installation support generated
  lazy-loading adapters.

Do not present these in application quick starts, and do not ask users to
construct `CatalogEntry`, `MessageArg`, `MessageValue`, or `MessageContract`
values. The generated facade owns those conversions.

## Fallback and diagnostics

Lookup tries the requested locale chain and then the configured fallback.
Formatting failure in one catalog does not stop the chain: a later catalog may
still produce a valid message. If no candidate succeeds, `try_t` returns all
formatting errors associated with the failed candidates.

The runtime records missing messages, per-message fallback, and formatting
failures in a bounded, deduplicated buffer (capacity 256 by default). Each
entry has an occurrence count, and `DiagnosticBatch.dropped` reports distinct
diagnostics that could not be retained. `take_diagnostics()` drains the buffer.

## Profile boundary

The compatibility profile preserves patterns, declarations, matching, legacy
markup parts, `:string`, `:number`, `:integer`, `:offset`, and private
`:lampclaw:datetime`. The standards authoring profile uses the complete pinned
model, resolution, bidi, stable default registry, and separately marked draft
date/time functions. Generated standards catalogs reject every private or
custom function. Low-level callers may still register namespaced custom
functions, but their behavior is outside generated authoring and conformance.
Neither profile name claims the final 1.0 complete Unicode MF2 contract; see
[`mf2-profile.mbt.md`](mf2-profile.mbt.md) for the pinned reference snapshot
and the compatibility matrix.
