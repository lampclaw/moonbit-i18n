# lampclaw/i18n

[中文](README.zh-CN.mbt.md)

`lampclaw/i18n` is a typed, generator-first internationalization workflow for
MoonBit. `0.9.0` ships one module containing the runtime, generator, a portable
`moonx` CLI, and standalone pinned Unicode MF2 syntax/data-model, resolution,
stable default-function, and public registry APIs.
Generated application facades currently target JavaScript and use the host's
`Intl` implementation behind a `Result` boundary.

The normal authoring surface is JSON: edit a schema plus locale resources,
generate a dedicated MoonBit package, and import only that generated package
from business code. Catalog JSON is a generated deployment artifact for
embedding or lazy loading, not a second authoring format.

## Roadmap and status

`0.9.0` is the roadmap's Unicode MF2 conformance candidate for JavaScript. New
scaffolds use the explicit stable `unicode-mf2-ldml48.2-js-v2` profile end to
end. Draft `:date`, `:time`, and `:datetime` require the separately named
`unicode-mf2-ldml48.2-js-v2+experimental-datetime-v1` profile. Omitted
`messageProfile` is error `I18N1003`; legacy standards v1 remains a warned
migration bridge.

The release freezes official Unicode LDML 48.2 sources, a 77-row anchored
normative matrix, independent `messageformat@4.0.0` differential evidence,
and real Chromium, Firefox, and WebKit conformance runs. The public interfaces,
generated template, CLI, and wire contracts are recorded as a 1.0 candidate.
It deliberately stops short of claiming Draft functions or project-owned CLDR
formatting on every backend. The public
[product roadmap](docs/roadmap.mbt.md) defines the version-gated path from the
current Web profile through authoring and delivery improvements to full MF2 on
the JavaScript backend. The
[current MF2 profile](docs/mf2-profile.mbt.md) remains the source of truth for
features shipped today; roadmap items are not yet supported behavior.
The exact toolchain, operating-system, browser, backend, and `0.x`
compatibility commitments are listed in the
[support policy](docs/support-policy.mbt.md).

## Install and run the CLI

Add the library dependency to an application module:

~~~bash
moon add lampclaw/i18n@0.9.0
~~~

Run the pinned CLI directly from the registry; no global install is required:

~~~bash
moonx lampclaw/i18n/cmd/i18n@0.9.0 --help
~~~

`moon add --bin lampclaw/i18n@0.9.0` is an optional project-local binary
dependency, not the primary workflow. A global command can alternatively be installed with
`moon install lampclaw/i18n/cmd/i18n@0.9.0`; it is named `moon-i18n`.

Create a complete bilingual JavaScript module in a path that does not yet
exist:

~~~bash
moonx lampclaw/i18n/cmd/i18n@0.9.0 scaffold acme/hello ./hello
cd hello
moon update
moon run --target js main
~~~

The scaffold refuses every existing destination, including a non-empty or
unowned directory. It stages all source and generated files beside the final
path and publishes them with one rename.

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
│   ├── generation-manifest.json
│   └── moon.pkg
├── public/i18n/          # generated deployment manifest + namespace chunks
│   ├── manifest.json
│   ├── en-US--common.json
│   └── zh-CN--common.json
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
  "messageProfile": "unicode-mf2-ldml48.2-js-v2",
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

Here only English is embedded. The generated `zh-CN--common.json` namespace
chunk can be downloaded later, verified against `manifest.json`, and installed
independently.

## Generate and check

From the application module, run:

~~~bash
moonx lampclaw/i18n/cmd/i18n@0.9.0 generate \
  localization/config.json \
  localization/schema.json \
  localization/locales \
  i18n \
  public/i18n

moonx lampclaw/i18n/cmd/i18n@0.9.0 check \
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
When every byte and expected file already matches, `generate` returns without
creating a stage, journal, or replacement directory.

Commit the generated package, catalogs, and `.lampclaw-i18n.json` ownership
manifests. Commit `generation-manifest.json` too: its versioned contract records
relative input/output paths, byte counts, SHA-256 hashes, the message profile,
and the typed contract hash. Persistent SHA-256-named `*.lampclaw.lock` files coordinate each
absolute destination from the user cache rather than either output tree. Set
`LAMPCLAW_I18N_STATE_DIR` to override that state location. The generated package
also tells `moon fmt` to skip `generated.mbt`, because its output is normalized
by the pinned CLI formatter.

Use `--allow-partial` while translating non-source locales below the configured
coverage threshold. Source and fallback locales always remain complete; empty
or whitespace-only messages count as untranslated.

Append `--diagnostic-format=json` to any command for the versioned CI/editor
form. Generation failures otherwise use the human form
`path:line:column: error[CODE]: message`. Both forms carry stable codes,
source paths, and half-open spans. Successful generation can also emit warning
diagnostics for profile migration; warnings do not change generated bytes or
the exit status. See the
[diagnostic contract](docs/diagnostics.mbt.md).

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

For a dynamically deployed locale, select a locale/namespace entry from the
deployment manifest, verify the exact byte count and SHA-256 in application
code, and install the text before using that route:

~~~moonbit
match i18n.install_catalog_chunk_source(
  @app_i18n.ZhCN,
  @app_i18n.CatalogCommon,
  verified_catalog_json,
) {
  Ok(_) => ()
  Err(message) => println("catalog rejected: \{message}")
}
let zh = i18n.translator(@app_i18n.ZhCN)
~~~

The facade also provides locale negotiation, strict `try_t`/`try_t_parts`,
convenience `t`/`t_parts`, catalog status, and bounded deduplicated diagnostics.
Dynamic installation checks catalog version, formatter profile, SHA-256
contract hash, locale and namespace identity, message validity, and resource
limits before changing runtime state. Network, cache, integrity, retry, and
locale-commit policy remain application-owned; see the
[production Web delivery contract](docs/web-delivery.mbt.md).

## Tooling and supported profile

The CLI also exposes `coverage`, `pseudo`, state-aware `export-xliff` and
`import-xliff`, plus one-way `import-i18next` and `import-arb` migration.
Because those standalone commands do not read the application config, pass its
exact profile as `--message-profile unicode-mf2-ldml48.2-js-v2`; omission is a
CLI usage error.
XLIFF 2.1 import verifies source content and both locale identities, rejects
unsafe XML and inline XML inside MF2 fields, and returns versioned lifecycle
state and a loss report. Translator notes, reviewed/final state, supported
metadata, explicit ID renames, and removals are covered by the documented
[translation lifecycle contract](docs/translation-lifecycle.mbt.md).

New applications should explicitly select
`unicode-mf2-ldml48.2-js-v2`. It composes the pinned complete syntax/data-model,
resolution, bidi, stable default registry, and Node 26 JavaScript provider for
generated applications. The stable function repertoire is `:string`,
`:number`, `:integer`, `:offset`, `:currency`, and `:percent`. Implemented
`:date`, `:time`, and `:datetime` remain Draft and are accepted only by the
explicit experimental datetime profile.

The compatibility profile
`lampclaw-mf2-strict-v1+lampclaw-datetime-v1` remains readable for existing
projects. It preserves the private `:lampclaw:datetime` function only in that
profile. Omitted `messageProfile` is error `I18N1003`; the old standards v1
profile emits `I18N1004`. Explicit compatibility use remains available during
the pre-1.0 migration window. The step-by-step path is in the
[message-profile migration guide](docs/message-profile-migration.mbt.md).
Exact accepted/deferred features and the pinned upstream snapshot are in
[`docs/mf2-profile.mbt.md`](docs/mf2-profile.mbt.md).

Tooling may separately use `unicode-mf2-ldml48.2-syntax-v1` through
`parse_mf2_syntax`, `parse_valid_mf2_model`, `serialize_mf2_model`,
`mf2_model_to_json`, and `parse_mf2_model_json`. This profile passes every
pinned upstream syntax and data-model fixture. The separate
`unicode-mf2-ldml48.2-resolution-v1` profile adds
`Mf2FormattingContext`, `Mf2Input`, `format_mf2_standalone`, and
`format_mf2_model_standalone`; it returns best-effort text, structured parts,
and typed errors. `unicode-mf2-ldml48.2-default-functions-v1` adds the stable
required registry, Node 26 `Intl` adapter, and public namespaced custom
registry. The machine-readable requirement matrix covers 77 anchored normative
rows plus all 6 stable functions and 40 stable options; the independent suite
records 20 stable and 4 experimental cases with no unexplained semantic
failures. The same upstream suites run in Chromium, Firefox, and WebKit. See the
[syntax and interchange guide](docs/mf2-syntax-data-model.mbt.md).

Resolution, bidi, safe structured output, and strict locale boundaries are
documented in the
[resolution and formatting guide](docs/mf2-resolution-formatting.mbt.md).
Default function authoring, backend boundaries, and custom handlers are in the
[default-function guide](docs/mf2-default-functions.mbt.md).

Limits include 1,000 locales, 64 MiB aggregate locale input, 64 MiB generated
MoonBit, 16 MiB/100,000-message catalogs, 64 KiB per message and standalone
formatted output, and 64 parameters, inputs, or declared rich tags per
message.

## Example and low-level APIs

The source repository's
[`examples/rabbita_todo`](https://github.com/lampclaw/moonbit-i18n/tree/v0.9.0/examples/rabbita_todo)
demonstrates the full browser workflow. Examples are intentionally excluded
from the published archive, so the registry page stays focused on the library.

Framework and generator maintainers can use the documented `runtime` and
`generator` packages; ordinary applications should prefer their generated
facade. See [`docs/runtime-spi.mbt.md`](docs/runtime-spi.mbt.md).

## License

Apache-2.0
