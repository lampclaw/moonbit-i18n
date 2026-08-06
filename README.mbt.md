# lampclaw/i18n

[中文文档](README.zh-CN.mbt.md)

`lampclaw/i18n` is a small in-memory internationalization runtime for MoonBit.
It normalizes locale codes, resolves parent locales, searches one configured
fallback locale, and keeps the core API independent from UI frameworks and
application-specific message types.

~~~text
application message enum (optional)
  -> stable string message ID
  -> Translator.translate(id)
  -> requested locale and its parent locales
  -> fallback locale and its parent locales
  -> installed in-memory Catalog
  -> String? result
~~~

Version `0.0.1` is an unpublished pre-1.0 release. JSON resource loading,
message interpolation, plural rules, extraction, and code generation are not
part of this version.

## Use from a checkout

Until the module is published to the Moon registry, place this repository and
your application in one Moon workspace. For example:

~~~text
workspace/
  moon.work
  moonbit-i18n/
  my-app/
~~~

The common `moon.work` lists both modules:

~~~toml
members = [
  "./moonbit-i18n",
  "./my-app",
]
~~~

Add the module dependency to `my-app/moon.mod`:

~~~toml
import {
  "lampclaw/i18n@0.0.1",
}
~~~

Then import the package from each application package that uses it:

~~~toml
import {
  "lampclaw/i18n",
}
~~~

After `lampclaw/i18n` is published, the workspace checkout can be replaced by:

~~~bash
moon add lampclaw/i18n
~~~

The package import remains unchanged.

## Core runtime

Create the runtime with one fallback locale, install catalogs, and ask a
translator for a message ID:

~~~moonbit nocheck
let i18n = @i18n.I18n::new(fallback_locale_code="en-US")
i18n.install_catalog(
  @i18n.Catalog::new(
    locale_code="en-US",
    entries=[
      { id: "common.hello", message: "Hello" },
      { id: "common.save", message: "Save" },
    ],
  ),
)
i18n.install_catalog(
  @i18n.Catalog::new(
    locale_code="zh-CN",
    entries=[{ id: "common.hello", message: "你好" }],
  ),
)

let t = i18n.translator("zh-CN")
let hello = t.translate("common.hello") // Some("你好")
let save = t.translate("common.save") // Some("Save") via en-US
let missing = t.translate("common.missing") // None
~~~

`Translator::translate` returns `String?`; applications decide how to display
or report a missing message. Installing another catalog with the same
normalized locale code replaces the previous catalog.

## Locale resolution

Locale codes are normalized before storage and lookup:

~~~moonbit nocheck
@i18n.normalize_locale_code("ZH_hans_cn") // Ok("zh-Hans-CN")
@i18n.locale_lookup_chain("zh-Hans-CN") // ["zh-Hans-CN", "zh-Hans", "zh"]
~~~

Normalization lowercases the language, title-cases a four-letter script,
uppercases a two-letter or numeric region, and accepts either `_` or `-` as a
separator. Empty components and non-ASCII-alphanumeric components are
rejected.

There are two translator constructors:

- `i18n.translator(code)` keeps the normalized requested locale. Message lookup
  searches that locale, its parents, then the configured fallback chain.
- `i18n.translator_from_code(code)` negotiates against installed catalog
  locales first. It selects an installed parent locale or the configured
  fallback, which is useful when the selected locale code is shown in a UI.

`resolve_locale_code(requested, supported, fallback)` exposes the same locale
negotiation primitive for application-level preference lists.

## Typed application layer

The core runtime deliberately uses string IDs because each application owns
its locale set and message schema. Applications can place exhaustive enums in
front of the runtime:

~~~moonbit nocheck
///|
pub(all) enum I18nText {
  Common(CommonText)
  Auth(AuthText)
}

///|
pub(all) enum CommonText {
  Hello
  Save
}

///|
pub(all) enum AuthText {
  Login
}
~~~

The [typed example](examples/typed) maps every enum value to a stable string ID
and every supported locale to a message. Its application-owned wrapper exposes
the concise API:

~~~moonbit nocheck
let i18n = I18n::new(fallback_locale=EnUS)
let t = i18n.translator(ZhCN)
t.t(Common(Hello))
t.t(Auth(Login))
~~~

These `Locale`, `I18nText`, typed `I18n`, and typed `Translator` definitions
belong to the example application; importing only `lampclaw/i18n` does not
generate application enums. Exhaustive `match` expressions make a newly added
message or locale visible to the MoonBit compiler.

Run the example with:

~~~bash
moon run --target js examples/typed
~~~

~~~text
你好
登录
~~~

## Architecture

The runtime has four small responsibilities:

1. `Catalog` stores a normalized locale code and an array of ID/message pairs.
2. `I18n` owns installed catalogs and the configured fallback locale.
3. Locale helpers normalize codes, build specific-to-general lookup chains,
   and negotiate requested locales against supported locales.
4. `Translator` performs requested-chain then fallback-chain lookup and returns
   the first message found.

The core package does not know about files, JSON, browsers, Rabbita, or an
application's enums. Resource loading and typed wrappers remain at the
application boundary. This lets command-line programs, servers, tests, and UI
frameworks share the same lookup runtime.

## Examples

### Basic fallback

~~~bash
moon run --target js examples/basic
~~~

~~~text
zh-CN common.hello: 你好
zh-CN common.save (fallback en-US): Save
~~~

### Rabbita Web

The standalone [Rabbita Counter example](examples/rabbita_web/README.mbt.md)
adapts Rabbita's official Counter with a typed message schema, localized count
messages, and an `en-US`/`zh-CN` language switch. It is a separate workspace
module, so Rabbita is not a dependency of the core `lampclaw/i18n` module.

~~~bash
cd examples/rabbita_web
moon install moonbit-community/warren@0.2.2
warren dev
~~~

Open the URL printed by Warren, then change the count and switch languages. The
example README records the verified development-server output, browser checks,
and release-build workflow.

## Repository validation

From the repository root:

~~~bash
moon info && git diff --exit-code
moon fmt --check
moon check --target js
moon test --target js
moon run --target js examples/basic
moon run --target js examples/typed
~~~

The test suites cover locale resolution, catalog validation, MF2 formatting,
the typed enum layer, and the standalone Rabbita Counter integration.

Validate the browser release separately:

~~~bash
cd examples/rabbita_web
warren build --dist /tmp/moonbit-i18n-rabbita-counter
~~~

Warren produces `index.html`, `index.js`, and `styles.css`. The output directory
is disposable and is not committed.

## Repository layout

~~~text
i18n.mbt                    # Catalog, I18n, and Translator runtime
locale.mbt                  # normalization and locale resolution
examples/basic/             # smallest string-ID fallback example
examples/typed/             # application-owned typed enum layer
examples/rabbita_web/       # localized Rabbita Counter browser example
~~~

## License

Apache-2.0. See [LICENSE](LICENSE).
