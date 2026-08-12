# Generated i18n package · Rabbita Todo

[中文](README.zh-CN.mbt.md)

This browser example adapts Rabbita's official Todo application and shows the
complete generator-first workflow. Maintained application source imports its
own generated package; it does not import the i18n runtime.

## Generate and validate

Run from the repository root:

~~~bash
moonx lampclaw/i18n/cmd/i18n@0.1.0-rc.2 generate \
  examples/rabbita_todo/localization/config.json \
  examples/rabbita_todo/localization/schema.json \
  examples/rabbita_todo/localization/locales \
  examples/rabbita_todo/i18n \
  examples/rabbita_todo/public/i18n

moonx lampclaw/i18n/cmd/i18n@0.1.0-rc.2 check \
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
i18n/generated.mbt + moon.pkg  public/i18n/*.json
typed facade + embedded data   catalog v2 + contract hash
              │
              ▼
main/moon.pkg imports lampclaw/i18n_rabbita_todo/i18n
              │
              ▼
Rabbita model / update / view calls Translator::t
~~~

The generated facade owns locale negotiation, embedded and dynamic catalogs,
JavaScript `Intl` formatting, catalog status, and diagnostics. Business code
uses typed values such as
`@app_i18n.TodoUi(@app_i18n.ActiveCount(active))`.

Only the English fallback catalog is embedded in the JavaScript bundle. The
Chinese catalog is fetched from `/i18n/zh-CN.json` on first use, validated and
installed atomically, then reused without another request. A failed request or
invalid catalog leaves the current locale unchanged and exposes a retry state.

The small `contract/` package is a framework adapter and browser acceptance
fixture. It turns structured `MessagePart` values into Rabbita HTML and proves
number, datetime, rich-parts, fallback, and diagnostic behavior in the three
supported browser engines. Maintained business source in `main/` continues to
import only the generated facade.

## Origin and license

The UI structure is adapted from the
[official Rabbita Todo example](https://github.com/moonbit-community/rabbita/tree/main/examples/todo),
which is licensed under Apache-2.0. This adaptation and `lampclaw/i18n` are also
Apache-2.0 licensed.
