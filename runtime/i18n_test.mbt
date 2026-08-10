///|
fn runtime_catalog(locale : String, messages : Array[CatalogEntry]) -> Catalog {
  Catalog::from_generated_entries(
    locale_code=locale,
    schema_hash="schema-1",
    entries=messages,
  )
}

///|
fn install_for_test(i18n : I18n, catalog : Catalog) -> Unit {
  guard i18n.install_generated_catalog(catalog) is Ok(_) else {
    abort("catalog installation failed")
  }
}

///|
test "translator formats parameters and falls back per message" {
  let i18n = I18n::new(fallback_locale_code="en-US", schema_hash="schema-1")
  install_for_test(
    i18n,
    runtime_catalog("en-US", [
      { id: "common.save", message: "Save" },
      { id: "auth.welcome", message: "Hello {$name}" },
    ]),
  )
  install_for_test(
    i18n,
    runtime_catalog("fr", [{ id: "auth.welcome", message: "Bonjour {$name}" }]),
  )
  let translator = i18n.translator_from_code("fr-FR")
  assert_true(
    translator.translate_raw("auth.welcome", [
      { name: "name", value: TextValue("Luca") },
    ]) ==
    Some("Bonjour Luca"),
  )
  assert_eq(translator.translate_raw("common.save", []), Some("Save"))
  assert_true(
    i18n.take_diagnostics() == [MessageFallback("fr", "en-US", "common.save")],
  )
  assert_true(i18n.take_diagnostics().is_empty())
}

///|
test "runtime rejects stale and mismatched catalogs" {
  let i18n = I18n::new(fallback_locale_code="en-US", schema_hash="schema-2")
  assert_true(
    i18n.install_generated_catalog(runtime_catalog("en-US", []))
    is Err(
      "catalog schema hash mismatch for en-US: expected schema-2, got schema-1"
    ),
  )
  let matching = I18n::new(fallback_locale_code="en-US", schema_hash="schema-1")
  let source = runtime_catalog("zh-CN", []).to_json_string()
  assert_true(
    matching.install_catalog_source_for("en-us", source)
    is Err("catalog locale mismatch: expected en-US, got zh-CN"),
  )
  assert_true(!matching.has_catalog("zh-CN"))
}

///|
test "runtime installs catalog JSON for a normalized locale" {
  let i18n = I18n::new(fallback_locale_code="zh-CN", schema_hash="schema-1")
  let source = runtime_catalog("en-US", [
    { id: "common.hello", message: "Hello" },
  ]).to_json_string()
  assert_true(i18n.install_catalog_source_for("en_us", source) is Ok(_))
  assert_true(i18n.has_catalog("EN-us"))
  assert_true(i18n.find_catalog("en-US") is Some(_))
  assert_eq(i18n.catalog_locale_codes(), ["en-US"])
  assert_eq(
    i18n.translator_from_code("en-US").translate_raw("common.hello", []),
    Some("Hello"),
  )
}

///|
test "runtime rejects invalid catalog sources and locale requests" {
  let i18n = I18n::new(fallback_locale_code="en-US", schema_hash="schema-1")
  assert_true(
    i18n.install_catalog_source("not json") is Err("invalid catalog JSON"),
  )
  assert_true(
    i18n.install_catalog_source_for("bad!locale", "{}")
    is Err("invalid locale code: bad!locale"),
  )
  assert_true(!i18n.has_catalog("bad!locale"))
  install_for_test(i18n, runtime_catalog("en-US", []))
  assert_eq(i18n.translator("bad!locale").locale_code(), "en-US")
}

///|
test "installing a locale again replaces its catalog" {
  let i18n = I18n::new(fallback_locale_code="en-US", schema_hash="schema-1")
  install_for_test(
    i18n,
    runtime_catalog("en-US", [{ id: "common.hello", message: "Hello" }]),
  )
  install_for_test(
    i18n,
    runtime_catalog("en-US", [{ id: "common.hello", message: "Hi" }]),
  )
  assert_eq(
    i18n.translator("en-US").translate_raw("common.hello", []),
    Some("Hi"),
  )
}

///|
test "runtime records missing and malformed message diagnostics" {
  let i18n = I18n::new(fallback_locale_code="en-US", schema_hash="schema-1")
  install_for_test(
    i18n,
    runtime_catalog("en-US", [{ id: "auth.welcome", message: "Hello {$name}" }]),
  )
  let translator = i18n.translator("en-US")
  assert_eq(translator.translate_raw("common.missing", []), None)
  assert_eq(translator.translate_raw("auth.welcome", []), None)
  assert_true(
    i18n.take_diagnostics() ==
    [
      MissingMessage("en-US", "common.missing"),
      MessageFormatFailed("en-US", "auth.welcome", "unknown variable: name"),
    ],
  )
}

///|
test "translator searches parent locale catalogs" {
  let i18n = I18n::new(fallback_locale_code="en-US", schema_hash="schema-1")
  install_for_test(i18n, runtime_catalog("en-US", []))
  install_for_test(
    i18n,
    runtime_catalog("zh", [{ id: "common.hello", message: "你好" }]),
  )
  assert_eq(
    i18n.translator("zh-Hans-CN").translate_raw("common.hello", []),
    Some("你好"),
  )
  assert_true(
    i18n.take_diagnostics() ==
    [MessageFallback("zh-Hans-CN", "zh", "common.hello")],
  )
}
