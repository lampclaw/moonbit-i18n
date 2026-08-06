# Generated i18n · Rabbita Todo

[中文](README.zh-CN.mbt.md)

This standalone browser example adapts Rabbita's official Todo application and
uses the complete `lampclaw/i18n` workflow: JSON schema and locale resources,
generated typed enums, embedded catalogs, MF2 parameters, Intl formatting, and
the application-facing `t.t(...)` API.

## Generate and validate translations

Run these commands from the repository root:

~~~bash
moon run cmd/i18n -- generate \
  examples/rabbita_todo/i18n/config.json \
  examples/rabbita_todo/i18n/schema.json \
  examples/rabbita_todo/i18n/locales \
  examples/rabbita_todo/main/generated.mbt \
  examples/rabbita_todo/public/i18n

moon run cmd/i18n -- check \
  examples/rabbita_todo/i18n/config.json \
  examples/rabbita_todo/i18n/schema.json \
  examples/rabbita_todo/i18n/locales \
  examples/rabbita_todo/main/generated.mbt \
  examples/rabbita_todo/public/i18n

moon run cmd/i18n -- coverage \
  examples/rabbita_todo/i18n/config.json \
  examples/rabbita_todo/i18n/schema.json \
  examples/rabbita_todo/i18n/locales
~~~

The current resources report `en-US: 22/22 (100%)` and
`zh-CN: 22/22 (100%)`. `check` is read-only and fails when generated bindings
or catalogs differ from the committed files.

## Run in development

~~~bash
cd examples/rabbita_todo
moon install moonbit-community/warren@0.2.2
warren dev
~~~

Open the URL printed by Warren. Add, complete, filter, and delete todos; switch
between English and Chinese; and verify that the active-item count uses the
localized parameterized message.

For a release build:

~~~bash
warren build --dist /tmp/moonbit-i18n-rabbita-todo
~~~

The verified build writes `index.html`, `index.js`, `styles.css`, and the
generated locale catalogs to the disposable output directory.

## Architecture

~~~text
i18n/config.json + schema.json + locales/*.json
                    │
                    ▼
              cmd/i18n generate
                    │
          ┌─────────┴──────────┐
          ▼                    ▼
main/generated.mbt       public/i18n/*.json
typed Locale/I18nText    versioned catalogs
          │
          ▼
main/i18n.mbt → Translator::t(I18nText)
          │
          ▼
Rabbita model / update / view
~~~

The generated file owns `Locale`, `I18nText`, message parameter conversion,
schema hash, and embedded catalogs. `main/i18n.mbt` is the small application
adapter, while `main/main.mbt` remains ordinary Rabbita code and calls APIs such
as `t.t(TodoUi(ActiveCount(active)))`.

## Origin and license

The UI structure is adapted from the
[official Rabbita Todo example](https://github.com/moonbit-community/rabbita/tree/main/examples/todo),
which is licensed under Apache-2.0. This adaptation and `lampclaw/i18n` are also
Apache-2.0 licensed.
