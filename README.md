# lampclaw/i18n

A minimal internationalization runtime for MoonBit.

Version 0.0.1 provides in-memory catalogs, exact locale matching, and one
fallback locale. Messages are returned as plain strings.

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

JSON resources, locale normalization, message formatting, and code generation
are intentionally outside the first MVP.

## Example

```bash
moon run --target js examples/basic
```

```text
zh-CN common.hello: 你好
zh-CN common.save (fallback en-US): Save
```

## Development

```bash
moon info
moon fmt --check
moon test --target js
```

## License

Apache-2.0. See [LICENSE](LICENSE).
