# lampclaw/i18n

A minimal internationalization runtime for MoonBit.

Version 0.0.1 provides in-memory catalogs, normalized locale lookup, parent
locale matching, and one fallback locale. The core runtime uses string message
IDs, while applications can put a typed enum layer in front of it.

```moonbit
let i18n = @i18n.I18n::new(fallback_locale_code="en-US")
i18n.install_catalog(
  @i18n.Catalog::new(
    locale_code="en-US",
    entries=[{ id: "common.hello", message: "Hello" }],
  ),
)
let message = i18n.translator("en-US").translate("common.hello")
```

JSON resources, message formatting, and code generation are intentionally
outside this MVP.

## Example

```bash
moon run --target js examples/basic
```

```text
zh-CN common.hello: 你好
zh-CN common.save (fallback en-US): Save
```

The typed example defines application-owned locale and message enums, then
bridges their exhaustive translations into the runtime:

```moonbit
let i18n = I18n::new(fallback_locale=EnUS)
let t = i18n.translator(ZhCN)
t.t(Common(Hello))
t.t(Auth(Login))
```

```bash
moon run --target js examples/typed
```

```text
你好
登录
```

## Rabbita Web example

The standalone browser example adds a language switcher without making
Rabbita a dependency of the core module:

```bash
cd examples/rabbita_web
warren dev
```

See [examples/rabbita_web/README.md](examples/rabbita_web/README.md) for setup
and build commands.

## Development

```bash
moon info
moon fmt --check
moon test --target js
```

## License

Apache-2.0. See [LICENSE](LICENSE).
