# lampclaw/i18n

[中文](README.zh-CN.mbt.md)

`lampclaw/i18n` is a typed, generator-first internationalization workflow for
MoonBit. `0.1.0-rc.2` ships one module containing the runtime, generator, and a
portable `moonx` CLI. Generated application facades currently target
JavaScript and use the host's `Intl` implementation behind a `Result` boundary.

The normal authoring surface is JSON: edit a schema plus locale resources,
generate a dedicated MoonBit package, and import only that generated package
from business code. Catalog JSON is a generated deployment artifact for
embedding or lazy loading, not a second authoring format.

## Roadmap and status

`0.1.0-rc.2` is an engineering-ready release candidate for Web/JavaScript
projects, not a prototype and not a claim of complete Unicode MessageFormat 2
conformance. The public
[product roadmap](docs/roadmap.mbt.md) defines the version-gated path from the
current Web profile through authoring and delivery improvements to full MF2 on
the JavaScript backend. The
[current MF2 profile](docs/mf2-profile.mbt.md) remains the source of truth for
features shipped today; roadmap items are not yet supported behavior.
The exact toolchain, operating-system, browser, backend, and prerelease
compatibility commitments are listed in the
[support policy](docs/support-policy.mbt.md).

## Install and run the CLI

Add the library dependency to an application module:

~~~bash
moon add lampclaw/i18n@0.1.0-rc.2
~~~

Run the pinned CLI directly from the registry; no global install is required:

~~~bash
moonx lampclaw/i18n/cmd/i18n@0.1.0-rc.2 --help
~~~

`moon add --bin lampclaw/i18n@0.1.0-rc.2` is an optional project-local binary
dependency, not the primary workflow. A global command can alternatively be installed with
`moon install lampclaw/i18n/cmd/i18n@0.1.0-rc.2`; it is named `moon-i18n`.

This is intentionally a single published module. Consequently `moon add`
resolves the exact parser and async dependencies used by the CLI even when an
application imports only the runtime. They are not linked into the generated
JavaScript application unless a reachable package imports them.

## Authoring model

~~~text
app/
├── localization/
│   ├── config.json
│   ├── schema.json
│   └── locales/
│       ├── en-US.json
│       └── zh-CN.json
├── i18n/                 # fully generated MoonBit package
│   ├── generated.mbt
│   └── moon.pkg
└── main/
    ├── main.mbt
    └── moon.pkg
~~~

`localization/schema.json` defines message IDs and parameter types:

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

Supported parameter types are `String`, `Int`, `Double`, `Bool`, and
`InstantMillis`. A message listed under `parts` gets a separate typed rich-parts
API and may use only the declared MF2 markup names.

Each locale supplies MF2 source:

~~~json
{
  "common": { "hello": "Hello {$name}" },
  "cart": {
    "item_count": ".input {$count :number}\n.match $count\none {{One item}}\n* {{{$count} items}}"
  }
}
~~~

`localization/config.json` controls locale negotiation, embedding, and the
release coverage gate:

~~~json
{
  "sourceLocale": "en-US",
  "defaultLocale": "zh-CN",
  "fallbackLocale": "en-US",
  "embeddedLocales": ["en-US"],
  "release": { "minimumCoverage": 1.0 },
  "locales": {
    "en-US": { "direction": "ltr" },
    "zh-CN": { "direction": "ltr" }
  }
}
~~~

Here only English is embedded. The generated `zh-CN.json` catalog can be
downloaded later and installed dynamically.

## Generate and check

From the application module, run:

~~~bash
moonx lampclaw/i18n/cmd/i18n@0.1.0-rc.2 generate \
  localization/config.json \
  localization/schema.json \
  localization/locales \
  i18n \
  public/i18n

moonx lampclaw/i18n/cmd/i18n@0.1.0-rc.2 check \
  localization/config.json \
  localization/schema.json \
  localization/locales \
  i18n \
  public/i18n
~~~

The fourth argument is a dedicated output package directory, not a source file.
Generation validates ownership, locks both absolute destination paths, stages
both destinations, and swaps them as one recoverable transaction. It refuses
symlinks or unowned content and removes stale generated catalogs. `check` is
read-only and detects source, manifest, catalog, ownership, and file-set drift.

Commit the generated package, catalogs, and `.lampclaw-i18n.json` ownership
manifests. Persistent SHA-256-named `*.lampclaw.lock` files coordinate each
absolute destination from the user cache rather than either output tree. Set
`LAMPCLAW_I18N_STATE_DIR` to override that state location. The generated package
also tells `moon fmt` to skip `generated.mbt`, because its output is normalized
by the pinned CLI formatter.

Use `--allow-partial` while translating non-source locales below the configured
coverage threshold. Source and fallback locales always remain complete; empty
or whitespace-only messages count as untranslated.

## Application use

An application package imports only its generated package:

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

For a dynamically deployed locale, fetch its generated catalog as text and
install it before creating or using that locale's translator:

~~~moonbit
match i18n.install_catalog_source(@app_i18n.ZhCN, downloaded_catalog_json) {
  Ok(_) => ()
  Err(message) => println("catalog rejected: \{message}")
}
let zh = i18n.translator(@app_i18n.ZhCN)
~~~

The facade also provides locale negotiation, strict `try_t`/`try_t_parts`,
convenience `t`/`t_parts`, catalog status, and bounded deduplicated diagnostics.
Dynamic installation checks catalog version, formatter profile, SHA-256
contract hash, locale identity, message validity, and resource limits before
changing runtime state.

## Tooling and supported profile

The CLI also exposes `coverage`, `pseudo`, `export-xliff`, and `import-xliff`.
XLIFF 2.1 import verifies source content and both locale identities, rejects
unsafe XML and inline XML inside MF2 fields, and preserves escaped text, CDATA,
entities, and layout.

The catalog profile is `lampclaw-mf2-strict-v1+lampclaw-datetime-v1`. It
supports MF2 patterns, declarations, matching, markup parts, `:string`,
`:number`, `:integer`, and `:offset`, plus `:lampclaw:datetime` for
`InstantMillis`. It deliberately rejects unsupported optional registry
functions instead of approximating them. This is a strict project subset, not
a claim of full Unicode MessageFormat 2 conformance. Exact accepted/rejected
features and the pinned upstream snapshot are documented in
[`docs/mf2-profile.mbt.md`](docs/mf2-profile.mbt.md).

Full BCP 47 canonicalization and Unicode bidi isolation are not included in
this release candidate. Limits include 1,000 locales, 64 MiB aggregate locale
input, 64 MiB generated MoonBit, 16 MiB/100,000-message catalogs, 64 KiB per
message, and 64 parameters or declared rich tags per generated message.

## Example and low-level APIs

The source repository's
[`examples/rabbita_todo`](https://github.com/lampclaw/moonbit-i18n/tree/v0.1.0-rc.2/examples/rabbita_todo)
demonstrates the full browser workflow. Examples are intentionally excluded
from the published archive, so the registry page stays focused on the library.

Framework and generator maintainers can use the documented `runtime` and
`generator` packages; ordinary applications should prefer their generated
facade. See [`docs/runtime-spi.mbt.md`](docs/runtime-spi.mbt.md).

## License

Apache-2.0
