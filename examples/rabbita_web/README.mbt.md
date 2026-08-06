# Rabbita Web example

[中文文档](README.zh-CN.mbt.md)

This standalone browser example combines `lampclaw/i18n` with Rabbita. It
keeps locale and message enums in the application, builds runtime catalogs from
exhaustive translations, and renders messages through `t.t(...)`.

~~~text
Rabbita Model.locale
  -> application-owned Locale and I18nText enums
  -> typed Translator.t(I18nText)
  -> lampclaw/i18n string-ID runtime
  -> Rabbita Val[Html]
  -> browser DOM
~~~

The example is a separate Moon workspace module. Its Rabbita dependency does
not become a dependency of the core `lampclaw/i18n` module.

## Requirements

- A MoonBit toolchain capable of building the repository workspace.
- Warren installed once as the Rabbita development and release server.

~~~bash
moon install moonbit-community/warren
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

1. Open `http://127.0.0.1:4300`.
2. Confirm the initial locale is `zh-CN` and the page displays Chinese text.
3. Select the language button and confirm the locale and all messages change to
   `en-US` and English.
4. Select it again and confirm the page returns to `zh-CN`.
5. Change a MoonBit source file while Warren is running and confirm the browser
   reloads after a successful rebuild.

## Automated verification

From the repository root or this directory, the workspace gates are:

~~~bash
moon fmt --check
moon check --target js
moon test --target js
~~~

The current workspace result is:

~~~text
Total tests: 23, passed: 23, failed: 0.
~~~

Create a disposable release build with:

~~~bash
warren build --dist /tmp/moonbit-i18n-rabbita-web
~~~

The build must complete successfully and produce:

~~~text
index.html
index.js
styles.css
~~~

The example's `dist/` directory is ignored. Keep verification output in a
temporary directory rather than committing generated browser artifacts.

## Implementation map

- `main/i18n.mbt` owns the application locale/message enums, exhaustive
  translations, runtime catalog construction, and typed translator wrapper.
- `main/main.mbt` owns the Rabbita model, language-toggle message, view, and
  browser mount point.
- `main/*_wbtest.mbt` verifies both locale translations and reversible locale
  switching.
- `public/` contains the maintained HTML shell and CSS copied into a Warren
  release build.

The page begins with `ZhCN`. Each render obtains a translator for the model's
current locale, then uses expressions such as `t.t(Common(Hello))` and
`t.t(Web(SwitchLanguage))`. The button emits one typed Rabbita message; the
update function replaces the locale, and Rabbita reevaluates the view.
