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

## Development

```bash
moon info
moon fmt --check
moon test --target js
```

## License

Apache-2.0. See [LICENSE](LICENSE).
