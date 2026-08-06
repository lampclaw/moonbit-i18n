# lampclaw/i18n

[中文文档](README.zh-CN.mbt.md)

Typed internationalization for MoonBit: locale negotiation, versioned
catalogs, a practical MessageFormat 2 subset, JavaScript `Intl` formatting,
typed enum generation, coverage checks, pseudo locales, and XLIFF 2.1 exchange.

Version `0.1.0` keeps UI-framework and application data out of the core. The
browser examples use Rabbita, but `lampclaw/i18n` itself works with command-line,
server, test, and other UI packages.

## Install

Until the module is published, put this repository and the application in one
Moon workspace:

~~~toml
// moon.work
members = [
  "./moonbit-i18n",
  "./my-app",
]
~~~

~~~toml
// my-app/moon.mod
import {
  "lampclaw/i18n@0.1.0",
}
~~~

Import the runtime and, on JavaScript, its `Intl` formatter from the consuming
package:

~~~toml
// my-app/main/moon.pkg
import {
  "lampclaw/i18n" @runtime,
  "lampclaw/i18n/js" @runtime_js,
}
~~~

After publication, replace the local workspace checkout with
`moon add lampclaw/i18n`.

## Recommended typed workflow

An application owns three inputs. No application-specific locale or message
names are built into this repository.

~~~text
i18n/
  config.json
  schema.json
  locales/
    en-US.json
    zh-CN.json
~~~

`config.json` declares locale policy and the release coverage floor:

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

`schema.json` is the source of truth for message IDs and parameter types:

~~~json
{
  "messages": {
    "common": ["save"],
    "counter": ["count"]
  },
  "params": {
    "counter.count": [{ "name": "count", "type": "Int" }]
  },
  "descriptions": {
    "counter.count": "Visible click count"
  }
}
~~~

Locale files contain only translations:

~~~json
{
  "common": { "save": "Save" },
  "counter": {
    "count": ".input {$count :number}\n.match $count\none {{One click}}\n* {{{$count} clicks}}"
  }
}
~~~

Every `*.json` file in the locale directory must have a matching entry in
`config.json`; missing, duplicate-normalized, and undeclared locales fail early.

Generate typed bindings and versioned catalogs with explicit paths:

~~~bash
moon run cmd/i18n -- generate \
  i18n/config.json \
  i18n/schema.json \
  i18n/locales \
  src/i18n/generated.mbt \
  public/i18n
~~~

The generated MoonBit file provides `Locale`, `I18nText`, one enum per message
group, parameter conversion, the schema hash, and configured embedded catalogs.
The hash is derived from sorted message IDs and parameter types, so JSON
formatting and translator-description edits do not invalidate compatible
catalogs.
An application adapter can then expose the desired `t.t(...)` surface:

~~~moonbit nocheck
let i18n = I18n::new()
let t = i18n.translator(ZhCN)

t.t(Common(Save))
t.t(Counter(Count(2)))
~~~

See the generated
[Rabbita Todo example](examples/rabbita_todo/README.mbt.md) for the complete
schema-to-browser integration.

## MessageFormat 2 subset

Messages support typed variables and formatter annotations:

~~~text
Hello {$name}
Total: {$total :number}
Published: {$date :datetime year=|numeric| month=|long|}
~~~

Supported schema parameter types are `String`, `Int`, `Double`, `Bool`, and
`DateTime`; generated `DateTime` parameters use ISO date/time `String` values.
The formatter recognizes `:number`, `:integer`, and `:datetime`.
On JavaScript, pass `@runtime_js.formatter()` to use the platform's `Intl` number,
date/time, and plural rules. Other targets can use `Formatter::basic()` or
supply the same three formatter callbacks.

Declarations and selectors cover common plural and choice messages:

~~~text
.input {$count :number}
.match $count
one {{One item}}
* {{{$count} items}}
~~~

`.input`, `.local`, `.match`, exact numeric keys, plural categories, and the
wildcard fallback are validated before catalogs are generated. Invalid or
unknown variables fail generation rather than becoming runtime surprises.

Rich messages use structured parts instead of injecting markup strings:

~~~moonbit nocheck
@runtime.format_mf2_rich(
  "Read {#link href=|/guide|}the guide{/link}",
  "en-US",
  [],
  @runtime_js.formatter(),
)
~~~

The result contains `RichText`, `RichOpen`, `RichClose`, and `RichStandalone`.
Call `validate_rich_tags` with the application's allow-list before rendering.
Rich selector messages are not supported in `0.1.0`.

## Runtime and catalogs

The low-level runtime remains available when generated bindings are not needed:

~~~moonbit nocheck
let runtime = @runtime.I18n::new(
  fallback_locale_code="en-US",
  schema_hash="app-schema-v1",
  formatter=@runtime_js.formatter(),
)

runtime.install_catalog(
  @runtime.Catalog::new(
    locale_code="en-US",
    schema_hash="app-schema-v1",
    entries=[
      { id: "common.hello", message: "Hello {$name}" },
    ],
  ),
)

let t = runtime.translator("en-US")
let result = t.translate("common.hello", [
  { name: "name", value: @runtime.TextValue("MoonBit") },
])
~~~

Catalog JSON carries `catalogVersion`, `schemaHash`, normalized `locale`, text
direction, and messages. `install_catalog_source_for` parses a dynamically
loaded catalog and checks both its locale and schema hash before installation.

Locale lookup searches the requested locale and its parents, followed by the
configured fallback chain. For example, `zh-Hans-CN` resolves through
`zh-Hans-CN`, `zh-Hans`, and `zh`. `translator_from_code` first negotiates
against installed catalogs.

`take_diagnostics()` returns and clears structured events:

- `MessageFallback(requested, resolved, id)`
- `MissingMessage(locale, id)`
- `MessageFormatFailed(locale, id, reason)`

Applications decide whether to log, aggregate, or display these events.

## CLI

All commands require explicit input and output paths; there are no
application-specific defaults.

~~~text
generate [--allow-partial] <config> <schema> <locale-dir> <output.mbt> <catalog-dir>
check    [--allow-partial] <config> <schema> <locale-dir> <output.mbt> <catalog-dir>
coverage                   <config> <schema> <locale-dir>
pseudo   <schema> <source-locale> <source.json> <en-XA|ar-XB> <output.json>
export-xliff <schema> <source-locale> <source.json> <target-locale> <target.json|-> <output.xlf>
import-xliff <schema> <target-locale> <input.xlf> <output.json>
~~~

- `generate` writes formatted bindings and one catalog per configured locale.
- `check` performs the same generation in memory and fails on changed, missing,
  or unexpected catalog artifacts.
- `coverage` reports translated/total counts without enforcing the release
  floor.
- `--allow-partial` disables the release coverage floor while developing;
  source and fallback locales must still be complete.
- `pseudo` creates an accented `en-XA` or RTL-wrapped `ar-XB` resource while
  preserving MF2 expressions and selector syntax.
- XLIFF 2.1 export/import preserves message IDs, descriptions, and MF2 text.

## Examples

- [Basic](examples/basic) demonstrates string-ID lookup and fallback.
- [Typed](examples/typed) shows the smallest hand-written enum adapter.
- [Rabbita Counter](examples/rabbita_web/README.mbt.md) is a small hand-written
  typed browser integration.
- [Rabbita Todo](examples/rabbita_todo/README.mbt.md) uses generated enums,
  catalogs, parameters, coverage checks, and the complete `t.t(...)` workflow.

The Rabbita examples are standalone workspace modules, so Rabbita is not a
dependency of the core library.

## Validate this repository

~~~bash
moon info
moon fmt --check
moon check --target js
moon test --target native
moon test --target wasm
moon test --target wasm-gc
moon test --target js
moon build --target js

moon run cmd/i18n -- check \
  examples/rabbita_todo/i18n/config.json \
  examples/rabbita_todo/i18n/schema.json \
  examples/rabbita_todo/i18n/locales \
  examples/rabbita_todo/main/generated.mbt \
  examples/rabbita_todo/public/i18n
~~~

Browser release builds:

~~~bash
cd examples/rabbita_web
warren build --dist /tmp/moonbit-i18n-rabbita-counter

cd ../rabbita_todo
warren build --dist /tmp/moonbit-i18n-rabbita-todo
~~~

## Architecture

~~~text
config + schema + locale JSON
             │
             ▼
      generator / CLI ──────── coverage, pseudo, XLIFF
          │       │
          ▼       ▼
  typed bindings  catalog JSON
          │       │
          └───┬───┘
              ▼
       I18n + Translator
              │
       MF2 + Formatter
              │
              ▼
     application / UI adapter
~~~

The repository contains no application business resources, application
loaders, or legacy generator entry points. The implementation is generic and
the examples are based on upstream Rabbita examples.

## License

Apache-2.0. See [LICENSE](LICENSE).
