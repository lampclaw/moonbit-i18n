///|
fn runtime_catalog(locale : String, messages : Array[CatalogEntry]) -> Catalog {
  Catalog::from_generated_entries(
    locale_code=locale,
    contract_hash=TEST_CONTRACT_HASH,
    entries=messages,
  )
}

///|
fn runtime_chunk(
  locale : String,
  chunk_namespace : String,
  messages : Array[CatalogEntry],
) -> Catalog {
  Catalog::from_generated_chunk_entries(
    locale_code=locale,
    chunk_namespace~,
    contract_hash=TEST_CONTRACT_HASH,
    entries=messages,
  )
}

///|
fn test_i18n(
  fallback? : String = "en-US",
  diagnostic_capacity? : Int = 256,
) -> I18n {
  I18n::new(
    fallback_locale_code=fallback,
    contract_hash=TEST_CONTRACT_HASH,
    diagnostic_capacity~,
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
  let i18n = test_i18n()
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
  assert_eq(
    translator.try_t("auth.welcome", [
      { name: "name", value: TextValue("Luca") },
    ]),
    Ok("Bonjour Luca"),
  )
  assert_eq(translator.t("common.save", []), "Save")
  let diagnostics = i18n.take_diagnostics()
  assert_eq(diagnostics.dropped, 0)
  assert_eq(diagnostics.entries.length(), 1)
  assert_eq(diagnostics.entries[0].kind, MessageFallbackDiagnostic)
  assert_eq(diagnostics.entries[0].used_locale, "en-US")
}

///|
test "format failures continue through the locale fallback chain" {
  let i18n = test_i18n()
  install_for_test(
    i18n,
    runtime_catalog("fr", [{ id: "welcome", message: "Bonjour {$name}" }]),
  )
  install_for_test(
    i18n,
    runtime_catalog("en-US", [{ id: "welcome", message: "Welcome" }]),
  )
  assert_eq(i18n.translator("fr").try_t("welcome", []), Ok("Welcome"))
  let batch = i18n.take_diagnostics()
  assert_eq(batch.entries.length(), 2)
  assert_eq(batch.entries[0].kind, MessageFormatFailedDiagnostic)
  assert_eq(batch.entries[1].kind, MessageFallbackDiagnostic)
}

///|
test "runtime rejects stale contracts and installs transactionally" {
  let i18n = test_i18n()
  let stale = Catalog::from_generated_entries(
    locale_code="en-US",
    contract_hash="bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb",
    entries=[],
  )
  assert_true(i18n.install_generated_catalog(stale) is Err(_))
  install_for_test(
    i18n,
    runtime_catalog("en-US", [{ id: "hello", message: "Hello" }]),
  )
  let malformed = runtime_catalog("en-US", [
    { id: "hello", message: "Broken {" },
  ])
  assert_true(i18n.install_generated_catalog(malformed) is Err(_))
  assert_eq(i18n.translator("en-US").t("hello", []), "Hello")
}

///|
test "runtime validates metadata on in-memory generated catalogs" {
  let i18n = test_i18n()
  let invalid_hash = Catalog::from_generated_entries(
    locale_code="en-US",
    contract_hash="not-a-hash",
    entries=[],
  )
  assert_true(i18n.install_generated_catalog(invalid_hash) is Err(_))
  let invalid_locale = Catalog::from_generated_entries(
    locale_code="en--US",
    contract_hash=TEST_CONTRACT_HASH,
    entries=[],
  )
  assert_true(i18n.install_generated_catalog(invalid_locale) is Err(_))
  let invalid_direction = Catalog::from_generated_entries(
    locale_code="en-US",
    contract_hash=TEST_CONTRACT_HASH,
    direction="sideways",
    entries=[],
  )
  assert_true(i18n.install_generated_catalog(invalid_direction) is Err(_))
}

///|
test "runtime installs catalog JSON for a normalized locale" {
  let i18n = test_i18n(fallback="zh-CN")
  let source = runtime_catalog("en-US", [
    { id: "common.hello", message: "Hello" },
  ]).to_json_string()
  assert_true(i18n.install_catalog_source_for("en_us", source) is Ok(_))
  assert_true(i18n.has_catalog("EN-us"))
  assert_true(i18n.find_catalog("en_us") is Some(_))
  assert_true(i18n.find_catalog("en--US") is None)
  assert_eq(i18n.catalog_locale_codes(), ["en-US"])
  assert_eq(i18n.translator_from_code("en-US").t("common.hello", []), "Hello")
}

///|
test "runtime installs independent chunks and reports namespace readiness" {
  let i18n = test_i18n()
  let common = runtime_chunk("zh-CN", "common", [
    { id: "common.hello", message: "你好" },
  ])
  let account = runtime_chunk("zh-CN", "account", [
    { id: "account.title", message: "账户" },
  ])
  assert_true(
    i18n.install_catalog_chunk_source_for(
      "zh_cn",
      "common",
      common.to_json_string(),
    )
    is Ok(_),
  )
  assert_true(i18n.has_catalog("zh-CN"))
  assert_true(i18n.has_catalog_namespace("zh-CN", "common"))
  assert_false(i18n.has_catalog_namespace("zh-CN", "account"))
  assert_false(i18n.has_catalog_namespaces("zh-CN", ["account", "common"]))
  assert_eq(i18n.catalog_namespaces("zh-CN"), ["common"])
  assert_eq(i18n.translator("zh-CN").t("common.hello", []), "你好")
  assert_true(i18n.install_generated_catalog(account) is Ok(_))
  assert_true(i18n.has_catalog_namespaces("zh-CN", ["account", "common"]))
  assert_eq(i18n.catalog_namespaces("zh-CN"), ["account", "common"])
  assert_true(i18n.find_catalog("zh-CN") is None)
  assert_true(i18n.find_catalog_chunk("zh-CN", "account") is Some(_))
  assert_eq(i18n.catalog_locale_codes(), ["zh-CN"])
  assert_eq(i18n.translator("zh-CN").t("account.title", []), "账户")
}

///|
test "chunk replacement is atomic and rejects incompatible identity" {
  let i18n = test_i18n()
  let valid = runtime_chunk("fr", "common", [
    { id: "common.save", message: "Enregistrer" },
  ])
  assert_true(i18n.install_generated_catalog(valid) is Ok(_))
  let malformed = runtime_chunk("fr", "common", [
    { id: "common.save", message: "Broken {" },
  ])
  assert_true(i18n.install_generated_catalog(malformed) is Err(_))
  assert_eq(i18n.translator("fr").t("common.save", []), "Enregistrer")
  assert_true(
    i18n.install_catalog_chunk_source_for(
      "fr",
      "account",
      valid.to_json_string(),
    )
    is Err("catalog namespace mismatch: expected account, got common"),
  )
  assert_true(
    i18n.install_catalog_chunk_source_for(
      "de",
      "common",
      valid.to_json_string(),
    )
    is Err("catalog locale mismatch: expected de, got fr"),
  )
}

///|
test "whole catalogs and chunks expose complete compatibility accessors" {
  let i18n = test_i18n()
  install_for_test(
    i18n,
    runtime_catalog("fr", [
      { id: "account.title", message: "Compte" },
      { id: "common.save", message: "Sauvegarder" },
    ]),
  )
  assert_true(i18n.has_whole_catalog("fr"))
  assert_false(i18n.has_whole_catalog("bad--locale"))
  assert_true(i18n.has_catalog_namespace("fr", "account"))
  assert_false(i18n.has_catalog_namespace("fr", "missing"))
  assert_false(i18n.has_catalog_namespace("bad--locale", "common"))
  assert_eq(i18n.catalog_namespaces("fr"), ["account", "common"])
  assert_eq(i18n.catalog_namespaces("bad--locale"), [])
  install_for_test(
    i18n,
    runtime_chunk("fr", "common", [
      { id: "common.save", message: "Enregistrer" },
    ]),
  )
  install_for_test(
    i18n,
    runtime_chunk("fr", "route", [{ id: "route.title", message: "Route" }]),
  )
  assert_eq(i18n.catalog_namespaces("fr"), ["account", "common", "route"])
  assert_eq(i18n.translator("fr").t("common.save", []), "Enregistrer")
  install_for_test(
    i18n,
    runtime_catalog("fr", [
      { id: "account.title", message: "Nouveau compte" },
      { id: "common.save", message: "Base" },
    ]),
  )
  assert_eq(i18n.translator("fr").t("account.title", []), "Nouveau compte")
  assert_eq(i18n.translator("fr").t("common.save", []), "Enregistrer")
  let whole_source = runtime_catalog("fr", []).to_json_string()
  assert_true(
    i18n.install_catalog_chunk_source_for("fr", "common", whole_source)
    is Err("catalog namespace is missing: expected common"),
  )
  assert_true(
    i18n.install_catalog_chunk_source_for("bad--locale", "common", "{}")
    is Err(_),
  )
  assert_true(
    i18n.install_catalog_chunk_source_for("fr", "common", "not-json")
    is Err("invalid catalog JSON"),
  )
  assert_true(i18n.find_catalog_chunk("bad--locale", "common") is None)
}

///|
test "try_t is structured while t remains fail-soft" {
  let i18n = test_i18n()
  install_for_test(i18n, runtime_catalog("en-US", []))
  let translator = i18n.translator("en-US")
  guard translator.try_t("missing.id", []) is Err(error) else {
    fail("missing translations must be structured errors")
  }
  assert_eq(error.kind, TranslationMissing)
  assert_eq(error.message_id, "missing.id")
  assert_eq(translator.t("another.id", []), "another.id")
}

///|
test "diagnostics are deduplicated, counted, and bounded" {
  let i18n = test_i18n(diagnostic_capacity=1)
  install_for_test(i18n, runtime_catalog("en-US", []))
  let translator = i18n.translator("en-US")
  ignore(translator.t("first", []))
  ignore(translator.t("first", []))
  ignore(translator.t("second", []))
  let batch = i18n.take_diagnostics()
  assert_eq(batch.entries.length(), 1)
  assert_eq(batch.entries[0].occurrences, 2)
  assert_eq(batch.dropped, 1)
  assert_true(i18n.take_diagnostics().entries.is_empty())
}

///|
test "parts translation uses the same compiled matcher and fallback path" {
  let i18n = test_i18n()
  install_for_test(
    i18n,
    runtime_catalog("en-US", [
      { id: "rich", message: "{#strong}Hello{/strong}" },
    ]),
  )
  assert_eq(
    i18n.translator("en-US").try_t_parts("rich", []),
    Ok([Open("strong", []), Text("Hello"), Close("strong")]),
  )
}

///|
test "translator searches parent locale catalogs" {
  let i18n = test_i18n()
  install_for_test(i18n, runtime_catalog("en-US", []))
  install_for_test(
    i18n,
    runtime_catalog("zh", [{ id: "common.hello", message: "你好" }]),
  )
  assert_eq(i18n.translator("zh-Hans-CN").t("common.hello", []), "你好")
  let batch = i18n.take_diagnostics()
  assert_eq(batch.entries[0].used_locale, "zh")
}

///|
test "catalog source adapters and metadata accessors are total" {
  let i18n = test_i18n()
  assert_eq(i18n.contract_hash(), TEST_CONTRACT_HASH)
  assert_true(i18n.install_catalog_source("not-json") is Err(_))
  assert_true(i18n.install_catalog_source_for("en--US", "{}") is Err(_))
  let source = runtime_catalog("en-US", [{ id: "hello", message: "Hello" }]).to_json_string()
  assert_true(i18n.install_catalog_source(source) is Ok(_))
  assert_true(i18n.find_catalog("en-US") is Some(_))
  assert_false(i18n.has_catalog("en--US"))
  assert_true(i18n.install_catalog_source_for("fr", source) is Err(_))
}

///|
test "profile mismatch and invalid construction inputs fail safely" {
  let invalid = I18n::new(
    fallback_locale_code="bad--locale",
    contract_hash=TEST_CONTRACT_HASH,
    diagnostic_capacity=-1,
  )
  assert_eq(invalid.fallback_locale_code(), "bad--locale")
  assert_true(
    invalid.install_generated_catalog(runtime_catalog("en-US", [])) is Ok(_),
  )
  let wrong_profile = I18n::new(
    fallback_locale_code="en-US",
    contract_hash=TEST_CONTRACT_HASH,
    profile="another-profile",
  )
  assert_true(
    wrong_profile.install_generated_catalog(runtime_catalog("en-US", []))
    is Err(_),
  )
}

///|
test "structured formatting failure is returned when no fallback succeeds" {
  let i18n = test_i18n()
  install_for_test(
    i18n,
    runtime_catalog("en-US", [{ id: "welcome", message: "Hello {$name}" }]),
  )
  let translator = i18n.translator("en-US")
  guard translator.try_t("welcome", []) is Err(error) else {
    fail("format error must remain structured")
  }
  assert_eq(error.kind, TranslationFormattingFailed)
  assert_eq(error.format_errors.length(), 1)
  assert_eq(translator.translate_raw("welcome", []), None)
  assert_eq(
    translator.translate_raw("welcome", [
      { name: "name", value: TextValue("MoonBit") },
    ]),
    Some("Hello MoonBit"),
  )
}

///|
test "parts convenience paths cover success, missing, and formatting errors" {
  let i18n = test_i18n()
  install_for_test(
    i18n,
    runtime_catalog("en-US", [
      { id: "rich", message: "{#b}Hi{/b}" },
      { id: "broken", message: "Hi {$name}" },
    ]),
  )
  let translator = i18n.translator("en-US")
  assert_eq(translator.t_parts("rich", []), [
    Open("b", []),
    Text("Hi"),
    Close("b"),
  ])
  assert_eq(translator.t_parts("missing", []), [Text("missing")])
  guard translator.try_t_parts("broken", []) is Err(error) else {
    fail("parts formatting error must remain structured")
  }
  assert_eq(error.kind, TranslationFormattingFailed)
}

///|
test "zero-capacity diagnostics report drops without retaining entries" {
  let i18n = test_i18n(diagnostic_capacity=-10)
  install_for_test(i18n, runtime_catalog("en-US", []))
  ignore(i18n.translator("en-US").t("missing", []))
  let batch = i18n.take_diagnostics()
  assert_true(batch.entries.is_empty())
  assert_eq(batch.dropped, 1)
}
