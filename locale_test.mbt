///|
test "normalizes locale code casing and separators" {
  assert_eq(normalize_locale_code("ZH_hans_cn"), Ok("zh-Hans-CN"))
  assert_eq(normalize_locale_code("en-us"), Ok("en-US"))
  assert_eq(normalize_locale_code("es-419"), Ok("es-419"))
}

///|
test "rejects invalid locale codes" {
  assert_eq(normalize_locale_code(""), Err("locale code must not be empty"))
  assert_eq(normalize_locale_code("en--US"), Err("invalid locale code: en--US"))
  assert_eq(normalize_locale_code("en-@"), Err("invalid locale code: en-@"))
}

///|
test "runtime stores normalized locale codes" {
  let i18n = I18n::new(fallback_locale_code="EN_us")
  let catalog = Catalog::new(locale_code="ZH_cn", schema_hash="test-schema", entries=[])
  assert_true(i18n.install_catalog(catalog) is Ok(_))
  assert_eq(i18n.fallback_locale_code(), "en-US")
  assert_eq(catalog.locale_code(), "zh-CN")
  assert_eq(i18n.translator("ZH_cn").locale_code(), "zh-CN")
}

///|
test "invalid requested locale selects the configured fallback" {
  let i18n = I18n::new(fallback_locale_code="en-US")
  assert_eq(i18n.translator("en--US").locale_code(), "en-US")
}

///|
test "builds locale lookup chains from specific to general" {
  assert_eq(locale_lookup_chain("ZH_hans_cn"), ["zh-Hans-CN", "zh-Hans", "zh"])
  assert_eq(locale_lookup_chain("en--US"), [])
}

///|
test "resolves requested locales through parent and fallback" {
  assert_eq(resolve_locale_code(["zh-Hans-CN"], ["en-US", "zh"], "en-US"), "zh")
  assert_eq(
    resolve_locale_code(["fr-FR"], ["en-US", "zh-CN"], "zh-CN"),
    "zh-CN",
  )
}
