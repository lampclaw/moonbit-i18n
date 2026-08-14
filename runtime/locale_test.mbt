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
  let catalog = Catalog::from_generated_entries(
    locale_code="ZH_cn",
    contract_hash=TEST_CONTRACT_HASH,
    entries=[],
  )
  assert_true(i18n.install_generated_catalog(catalog) is Ok(_))
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

///|
test "locale negotiation handles invalid and empty supported sets" {
  assert_eq(
    normalize_locale_code("abcdef-abcde-A1b23"),
    Ok("abcdef-abcde-a1b23"),
  )
  assert_eq(
    resolve_locale_code(["de-DE"], ["bad--tag", "EN_us"], "fr-FR"),
    "en-US",
  )
  assert_eq(resolve_locale_code([], [], "fallback_value"), "fallback_value")
  assert_eq(resolve_locale_code([], ["en-US"], "bad--tag"), "en-US")
  assert_eq(normalize_locale_code("en-12a"), Ok("en-12a"))
}

///|
test "strict BCP 47 canonicalization applies pinned IANA mappings" {
  assert_eq(canonicalize_locale_tag("iw-BU"), Ok("he-MM"))
  assert_eq(canonicalize_locale_tag("zh-cmn-Hant"), Ok("cmn-Hant"))
  assert_eq(canonicalize_locale_tag("zh-yue-HK"), Ok("yue-HK"))
  assert_eq(canonicalize_locale_tag("i-klingon"), Ok("tlh"))
  assert_eq(canonicalize_locale_tag("I-DEFAULT"), Ok("i-default"))
  assert_eq(BCP47_REGISTRY_DATE, "2026-08-08")
  assert_eq(
    BCP47_REGISTRY_SHA256,
    "be21e91b6851f750a7b1a687f11209d46ad5a8471d6b10a1efc8d1dac4c8a926",
  )
}

///|
test "strict BCP 47 canonicalization sorts extensions and regularizes case" {
  assert_eq(
    canonicalize_locale_tag("EN-b-FOO-a-Bar-X-Baz"),
    Ok("en-a-bar-b-foo-x-baz"),
  )
  assert_eq(canonicalize_locale_tag("x-COMPANY-App"), Ok("x-company-app"))
}

///|
test "strict BCP 47 rejects compatibility and ambiguous syntax" {
  guard canonicalize_locale_tag("en_US") is Err(separator) else {
    fail("expected strict separator error")
  }
  assert_eq(separator.code, LocaleSyntaxCode)
  guard canonicalize_locale_tag("sl-rozaj-ROZAJ") is Err(variant) else {
    fail("expected duplicate variant")
  }
  assert_eq(variant.code, LocaleDuplicateVariantCode)
  guard canonicalize_locale_tag("en-a-foo-A-bar") is Err(extension) else {
    fail("expected duplicate extension")
  }
  assert_eq(extension.code, LocaleDuplicateExtensionCode)
  guard canonicalize_locale_tag("en-qaa") is Err(extlang) else {
    fail("expected invalid extlang")
  }
  assert_eq(extlang.code, LocaleInvalidExtlangCode)
  assert_true(canonicalize_locale_tag("en-u") is Err(_))
  assert_true(canonicalize_locale_tag("en-x") is Err(_))
}

///|
test "strict locale lookup follows RFC 4647 singleton truncation" {
  assert_eq(
    strict_locale_lookup_chain("zh-Hant-CN-x-private1-private2"),
    Ok([
      "zh-Hant-CN-x-private1-private2", "zh-Hant-CN-x-private1", "zh-Hant-CN", "zh-Hant",
      "zh",
    ]),
  )
  assert_eq(
    strict_locale_lookup_chain("en-US-u-ca-gregory"),
    Ok(["en-US-u-ca-gregory", "en-US-u-ca", "en-US", "en"]),
  )
}

///|
test "strict locale negotiation exposes configuration failures" {
  assert_eq(
    negotiate_locale_code(["iw-IL"], ["en", "he"], fallback=Some("fr")),
    Ok(Some("he")),
  )
  assert_eq(
    negotiate_locale_code(["*"], ["en"], fallback=Some("fr-FR")),
    Ok(Some("fr-FR")),
  )
  assert_eq(negotiate_locale_code(["fr"], ["en"]), Ok(None))
  guard negotiate_locale_code([], ["iw", "he"]) is Err(duplicate) else {
    fail("expected canonical supported-locale collision")
  }
  assert_eq(duplicate.code, LocaleDuplicateSupportedCode)
}
