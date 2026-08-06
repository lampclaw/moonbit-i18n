# Localized Rabbita Counter

[中文文档](README.zh-CN.mbt.md)

This standalone browser example adapts Rabbita's official Counter example to
show a hand-written typed i18n integration. The Rabbita model owns both the
counter value and locale. Views translate parameterized messages through
`t.t(...)`, including English plural selection through `Intl.PluralRules`.

~~~text
Rabbita Model(count, locale)
  -> application-owned I18nText enums
  -> typed Translator.t(I18nText)
  -> lampclaw/i18n runtime + JS Intl formatter
  -> Rabbita Val[Html]
  -> browser DOM
~~~

The example is a separate Moon workspace module, so Rabbita remains an example
dependency rather than a dependency of the core runtime.

## Requirements

- A MoonBit toolchain capable of building the repository workspace.
- Warren 0.2.2 installed as the Rabbita development and release server.

~~~bash
moon install moonbit-community/warren@0.2.2
~~~

## Run in development

From this directory:

~~~bash
warren dev
~~~

Warren serves the app at `http://127.0.0.1:4300` by default, watches the
MoonBit package, rebuilds it, and reloads the browser when files change.

The following development run was verified successfully:

~~~text
➜  rabbita_web git:(main) warren dev
08:08    [info]: Running server on http://127.0.0.1:4300
08:08  [warren]: Building...
08:08    [moon]: Finished. moon: ran 17 tasks, now up to date
08:08  [warren]: moon build succeed at /home/luca/projects/lampclaw/moonbit-hackathon/moonbit-i18n/examples/rabbita_web/main.
08:08  [warren]: Changes detected. Reloading...
~~~

The timestamp and task count are a validation snapshot; later incremental
builds may report different values.

## Browser acceptance

1. Open `http://127.0.0.1:4300` and confirm the initial locale is `zh-CN`.
2. Select Increase and Decrease and confirm the count and localized count text
   update together.
3. Select the language button and confirm the locale, button labels, title, and
   parameterized count message change to English.
4. Set the count to one and two and confirm English uses “One click” and
   “2 clicks”.
5. Change a MoonBit source file while Warren is running and confirm a successful
   rebuild reloads the browser.

## Automated verification

From the repository root or this directory:

~~~bash
moon fmt --check
moon check --target js
moon test --target js
~~~

Create a disposable release build with:

~~~bash
warren build --dist /tmp/moonbit-i18n-rabbita-counter
~~~

The build must produce `index.html`, `index.js`, and `styles.css`. The example's
`dist/` directory is ignored; generated browser artifacts are not committed.

## Implementation map

- `main/i18n.mbt` owns the example enums, parameter mapping, catalogs, runtime,
  and typed translator wrapper.
- `main/main.mbt` follows Rabbita Counter's typed message/update/view shape and
  adds locale to the model.
- `main/*_wbtest.mbt` verifies counter updates, plural messages, translations,
  and reversible locale switching.
- `public/` contains the maintained Warren HTML shell and CSS.

This example is based on the
[official Rabbita Counter example](https://github.com/moonbit-community/rabbita/tree/main/examples/counter),
which is available under Apache-2.0.
