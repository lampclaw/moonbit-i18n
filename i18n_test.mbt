///|
fn catalog(locale_code : String, entries : Array[CatalogEntry]) -> Catalog {
  Catalog::new(locale_code~, schema_hash="test-schema", entries~)
}

///|
test "translator returns a message from the requested locale" {
  let i18n = I18n::new(fallback_locale_code="en-US")
  i18n.install_catalog(
    catalog("en-US", [{ id: "common.hello", message: "Hello" }]),
  )
  i18n.install_catalog(
    catalog("zh-CN", [{ id: "common.hello", message: "你好" }]),
  )
  assert_eq(i18n.translator("zh-CN").translate("common.hello"), Some("你好"))
}

///|
test "translator falls back for a missing message" {
  let i18n = I18n::new(fallback_locale_code="en-US")
  i18n.install_catalog(
    catalog("en-US", [{ id: "common.save", message: "Save" }]),
  )
  i18n.install_catalog(
    catalog("fr-FR", [{ id: "common.hello", message: "Bonjour" }]),
  )
  assert_eq(i18n.translator("fr-FR").translate("common.save"), Some("Save"))
}

///|
test "translator falls back when the requested locale is not installed" {
  let i18n = I18n::new(fallback_locale_code="en-US")
  i18n.install_catalog(
    catalog("en-US", [{ id: "common.hello", message: "Hello" }]),
  )
  assert_eq(i18n.translator("de-DE").translate("common.hello"), Some("Hello"))
}

///|
test "translator returns none when a message is unavailable" {
  let i18n = I18n::new(fallback_locale_code="en-US")
  i18n.install_catalog(catalog("en-US", []))
  assert_eq(i18n.translator("zh-CN").translate("common.missing"), None)
}

///|
test "installing a locale again replaces its catalog" {
  let i18n = I18n::new(fallback_locale_code="en-US")
  i18n.install_catalog(
    catalog("en-US", [{ id: "common.hello", message: "Hello" }]),
  )
  i18n.install_catalog(
    catalog("en-US", [{ id: "common.hello", message: "Hi" }]),
  )
  assert_eq(i18n.translator("en-US").translate("common.hello"), Some("Hi"))
}

///|
test "translator searches parent locale catalogs" {
  let i18n = I18n::new(fallback_locale_code="en-US")
  i18n.install_catalog(
    catalog("en-US", [{ id: "common.hello", message: "Hello" }]),
  )
  i18n.install_catalog(
    catalog("zh", [{ id: "common.hello", message: "你好" }]),
  )
  assert_eq(
    i18n.translator("zh-Hans-CN").translate("common.hello"),
    Some("你好"),
  )
}

///|
test "translator_from_code resolves to an installed parent locale" {
  let i18n = I18n::new(fallback_locale_code="en-US")
  i18n.install_catalog(catalog("en-US", []))
  i18n.install_catalog(catalog("fr", []))
  assert_eq(i18n.translator_from_code("fr-CA").locale_code(), "fr")
  assert_eq(i18n.translator_from_code("de-DE").locale_code(), "en-US")
}
