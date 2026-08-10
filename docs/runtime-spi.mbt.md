# Runtime SPI

[中文](runtime-spi.zh-CN.mbt.md)

This document is for generator, framework, and tooling maintainers. Normal
applications should use their generated i18n package and should not import the
runtime packages directly.

## Package boundary

- `lampclaw/i18n/runtime` contains catalog parsing, locale lookup, MF2
  formatting, fallback, and diagnostics.
- `lampclaw/i18n/runtime/js` provides the JavaScript `Intl` formatter.
- Generated application packages depend on both and expose app-owned types.

The SPI is public only because generated packages are separate MoonBit
packages. Public visibility does not make it an application authoring surface.

## Intentional low-level names

- `Catalog::from_generated_entries(...)` creates embedded catalogs from
  generator-owned data.
- `I18n::install_generated_catalog(...)` installs those embedded catalogs.
- `Translator::translate_raw(...)` accepts string IDs and raw message
  arguments.
- `parse_catalog(...)` and catalog-source installation support generated
  lazy-loading adapters.

The names explicitly describe their integration role. Do not present them in
application quick starts, and do not ask users to construct `CatalogEntry`,
`MessageArg`, or `MessageValue` values.

## Compatibility contract

Catalog format version `1` is retained in the `0.1.0` development line. A
catalog is accepted only when its version is supported, its schema hash matches
the runtime contract, and its normalized locale matches the typed locale
requested by the generated facade.

The current schema hash fingerprints message IDs and parameter types. It is
deterministic but is not yet a cryptographic or complete message-contract hash.

## Diagnostics

The runtime records missing messages, per-message fallback, and formatting
failures. Generated packages convert these values into their own `Diagnostic`
type so application code never depends on runtime diagnostic constructors.

## Scope caveats

The basic formatter remains useful for runtime tests and non-JS SPI consumers,
but it does not provide full CLDR behavior. Generated authoring is JS-only in
this development round and always wires `lampclaw/i18n/runtime/js`.
