# Generated i18n package · Rabbita Todo

[中文](README.zh-CN.mbt.md)

This browser example adapts Rabbita's official Todo application and shows the
complete generator-first workflow. Maintained application source imports its
own generated package and application-owned browser adapter; it does not
import the i18n runtime.

## Generate and validate

Run from the repository root:

~~~bash
moonx lampclaw/i18n/cmd/i18n@0.7.0 generate \
  examples/rabbita_todo/localization/config.json \
  examples/rabbita_todo/localization/schema.json \
  examples/rabbita_todo/localization/locales \
  examples/rabbita_todo/i18n \
  examples/rabbita_todo/public/i18n

moonx lampclaw/i18n/cmd/i18n@0.7.0 check \
  examples/rabbita_todo/localization/config.json \
  examples/rabbita_todo/localization/schema.json \
  examples/rabbita_todo/localization/locales \
  examples/rabbita_todo/i18n \
  examples/rabbita_todo/public/i18n
~~~

Both locales currently report `28/28 (100%)`. The generator owns the complete
`i18n/` package and catalog directory through ownership manifests. Both
directories are replaced together by a recoverable transaction; `check` is the
read-only CI drift gate.

## Run

~~~bash
cd examples/rabbita_todo
moon install moonbit-community/warren@0.2.2
warren dev
~~~

For a release build:

~~~bash
warren build --dist /tmp/moonbit-i18n-rabbita-todo
~~~

## Architecture

~~~text
localization/config.json + schema.json + locales/*.json
                         │
                         ▼
               moonx lampclaw/i18n/cmd/i18n generate
                         │
              ┌──────────┴──────────┐
              ▼                     ▼
i18n/generated.mbt + moon.pkg  public/i18n/manifest.json + chunks
typed facade + embedded data   namespace + SHA-256 + contract hash
              │
              ▼
main/moon.pkg imports generated i18n + browser_preferences
              │                         │
              ▼                         ▼
Rabbita model / update / view       localStorage / navigator
calls Translator::t                 application adapter
~~~

The generated facade owns locale negotiation, embedded and dynamic catalogs,
JavaScript `Intl` formatting, catalog status, and diagnostics. Business code
uses typed values such as
`@app_i18n.TodoUi(@app_i18n.ActiveCount(active))`.

Only the English fallback catalog is embedded in the JavaScript bundle. The
Chinese `common` and `todo_ui` namespaces are fetched independently from
`/i18n/zh-CN--common.json` and `/i18n/zh-CN--todo_ui.json` on first use. The
application compares each exact UTF-8 byte count and SHA-256 with generated
deployment metadata before asking the facade to validate and install it. A
failed request, integrity mismatch, or invalid chunk leaves the current locale
unchanged and exposes a retry state; a retry requests only missing namespaces.
The `contract` namespace is intentionally left unloaded to exercise normal
message-level English fallback.

The example keeps an explicit language choice in browser `localStorage` under
`lampclaw.i18n.rabbita-todo.locale`. On startup it negotiates in this order:
the saved choice, `navigator.languages`, then the English fallback. A restored
Chinese preference is committed only after its dynamic catalog validates, so
the application may briefly show the embedded English loading state. Browser
language inference is not saved until the user explicitly switches or retries.
Storage is best effort: blocked or unavailable storage never prevents an
in-session language change. Refreshing creates a new in-memory `I18n` instance,
so the two required Chinese chunks are installed again; normal HTTP caching may
serve them without another transfer. Todo items themselves are intentionally
not stored.

Locale detection, loading, and persistence remain application-owned adapters.
The generated facade accepts locale codes and catalog data but does not access
browser storage or perform network requests.

The small `contract/` package is a framework adapter and browser acceptance
fixture. It turns structured `MessagePart` values into Rabbita HTML and proves
number, datetime, rich-parts, fallback, and diagnostic behavior in the three
supported browser engines. Localization calls in maintained business source
continue to use only the generated facade; `browser_preferences/` separately
owns the host-specific preference boundary.

## Origin and license

The UI structure is adapted from the
[official Rabbita Todo example](https://github.com/moonbit-community/rabbita/tree/main/examples/todo),
which is licensed under Apache-2.0. This adaptation and `lampclaw/i18n` are also
Apache-2.0 licensed.
