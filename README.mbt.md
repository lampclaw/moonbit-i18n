# lampclaw/i18n

[中文](README.zh-CN.mbt.md)

`lampclaw/i18n` is a typed, generator-first internationalization workflow for
MoonBit. Version `0.1.0` is still under development and has not been released.
The current application facade targets JavaScript and uses the platform's
`Intl` implementation automatically.

Application code authors messages in JSON resources, generates a dedicated
MoonBit package, and translates typed values. It does not construct catalogs,
message arguments, or formatter objects by hand.

## Authoring model

A typical application keeps editable localization inputs separate from the
generated package:

~~~text
app/
├── localization/
│   ├── config.json
│   ├── schema.json
│   └── locales/
│       ├── en-US.json
│       └── zh-CN.json
├── i18n/                 # fully generated package
│   ├── generated.mbt
│   └── moon.pkg
└── main/
    ├── main.mbt
    └── moon.pkg
~~~

`localization/schema.json` defines the typed message contract:

~~~json
{
  "messages": {
    "common": ["hello"],
    "cart": ["item_count"]
  },
  "params": {
    "common.hello": [{ "name": "name", "type": "String" }],
    "cart.item_count": [{ "name": "count", "type": "Int" }]
  }
}
~~~

Each locale provides message text, including MF2 expressions and matchers:

~~~json
{
  "common": {
    "hello": "Hello {$name}"
  },
  "cart": {
    "item_count": ".input {$count :number}\n.match $count\none {{One item}}\n* {{{$count} items}}"
  }
}
~~~

`localization/config.json` declares locale behavior and release coverage:

~~~json
{
  "sourceLocale": "en-US",
  "defaultLocale": "zh-CN",
  "fallbackLocale": "en-US",
  "embeddedLocales": ["en-US", "zh-CN"],
  "release": { "minimumCoverage": 1.0 },
  "locales": {
    "en-US": { "direction": "ltr" },
    "zh-CN": { "direction": "ltr" }
  }
}
~~~

## Generate and check

From the module workspace, run:

~~~bash
moon run cmd/i18n -- generate \
  app/localization/config.json \
  app/localization/schema.json \
  app/localization/locales \
  app/i18n \
  app/public/i18n

moon run cmd/i18n -- check \
  app/localization/config.json \
  app/localization/schema.json \
  app/localization/locales \
  app/i18n \
  app/public/i18n
~~~

The fourth argument is an output package directory, not a single source file.
The generator owns `generated.mbt` and `moon.pkg`, marks both files, refuses to
overwrite unmarked files, and rejects additional `.mbt` files in that package.
`check` is read-only and detects source, manifest, catalog, and file-set drift.

Use `--allow-partial` while iterating when non-source locales are below the
configured coverage threshold. The source and fallback locales always have to
be complete. Empty or whitespace-only values count as missing translations.

## Application dependency and use

During local development, include the library and application modules in one
workspace:

~~~text
members = [
  ".",
  "app",
]
~~~

The application module declares the `0.1.0` dependency:

~~~text
import {
  "lampclaw/i18n@0.1.0",
}
~~~

Business packages import only their generated package:

~~~text
import {
  "acme/todo/i18n" @app_i18n,
}
~~~

Translation is typed end to end:

~~~moonbit
let i18n = @app_i18n.I18n::new()
let t = i18n.default_translator()

let greeting = t.t(
  @app_i18n.Common(@app_i18n.Hello("MoonBit")),
)
let count = t.t(
  @app_i18n.Cart(@app_i18n.ItemCount(3)),
)
~~~

The generated facade provides:

- `I18n::new()` with embedded catalogs and JavaScript `Intl` formatting;
- `default_translator()`, `translator(Locale)`, and
  `translator_from_code(String)`;
- typed `Translator::t(I18nText)`;
- `install_catalog_source(Locale, String)` for validated dynamic catalogs;
- `has_catalog(Locale)` and `installed_locales()`;
- application-level diagnostics through `take_diagnostics()`.

Locale codes are normalized for common casing and underscore differences.
Unsupported requested locales resolve to the configured default locale;
message lookup still uses the configured fallback locale.

## Catalogs are deployment artifacts

Catalog JSON is useful for lazy loading, CDN delivery, schema compatibility
checks, locale metadata, and diagnostics. It is not a second user authoring
API. Authors edit locale resources and let the generator create versioned
catalogs. Applications that lazy-load translations pass the downloaded JSON
to the generated `install_catalog_source` method.

Catalog format version `1` contains `catalogVersion`, `schemaHash`, `locale`,
`direction`, and a flat `messages` object. Installation rejects unsupported
versions, stale schema hashes, and locale mismatches.

## Validation and tooling

Generation validates every MF2 matcher branch, selector value types, variant
key counts, duplicate declarations/selectors/variant keys, and the required
all-wildcard fallback. It also checks generated identifier collisions,
normalized locale collisions, source/fallback completeness, and release
coverage.

Additional tooling includes coverage reports, `en-XA`/`ar-XB` pseudo-locales,
and XLIFF 2.1 import/export. See `moon run cmd/i18n` for command syntax.

## Example

[`examples/rabbita_todo`](examples/rabbita_todo/README.mbt.md) demonstrates the
complete package-generation workflow in a browser application. Its maintained
source imports only its own generated i18n package.

Low-level integration APIs are intentionally separated from normal authoring.
Generator and framework maintainers can read
[`docs/runtime-spi.mbt.md`](docs/runtime-spi.mbt.md).

## Current scope

The generated application facade is JS-first. Typed rich-message authoring,
full CLDR behavior on Native/Wasm, complete BCP 47 handling, catalog AST
precompilation, stronger contract hashing, and a real XML-based XLIFF parser
remain future work.

## License

Apache-2.0
