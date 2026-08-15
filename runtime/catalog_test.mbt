///|
const TEST_CONTRACT_HASH : String = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"

///|
test "catalog v2 round trips through JSON" {
  let catalog = Catalog::from_generated_entries(
    locale_code="en-us",
    contract_hash=TEST_CONTRACT_HASH,
    entries=[{ id: "auth.welcome", message: "Hello {$name}" }],
  )
  let parsed = parse_catalog(catalog.to_json_string())
  guard parsed is Ok(value) else { fail("expected a valid catalog") }
  assert_eq(value.locale_code(), "en-US")
  assert_eq(value.contract_hash(), TEST_CONTRACT_HASH)
  assert_eq(value.profile(), CATALOG_PROFILE)
  assert_eq(value.direction(), "ltr")
  assert_eq(value.catalog_version(), 2)
  assert_eq(value.find("auth.welcome"), Some("Hello {$name}"))
}

///|
test "catalog v2 preserves the standards-mode message profile" {
  let catalog = Catalog::from_generated_entries(
    locale_code="en-US",
    contract_hash=TEST_CONTRACT_HASH,
    profile=MF2_STANDARD_MESSAGE_PROFILE,
    entries=[{ id: "count", message: "{$count :number}" }],
  )
  guard parse_catalog(catalog.to_json_string()) is Ok(parsed) else {
    fail("expected a valid standards-mode catalog")
  }
  assert_eq(parsed.profile(), MF2_STANDARD_MESSAGE_PROFILE)
  assert_true(is_supported_message_profile(parsed.profile()))
  assert_true(
    parsed.compile_messages()
    is Err(
      "compile_messages exposes only the legacy compiled-message model; use I18n installation for profile unicode-mf2-ldml48.2-js-v2"
    ),
  )
}

///|
test "stable and experimental profiles keep Draft datetime separate" {
  let stable = Catalog::from_generated_entries(
    locale_code="en-US",
    contract_hash=TEST_CONTRACT_HASH,
    profile=MF2_STANDARD_MESSAGE_PROFILE,
    entries=[{ id: "updated", message: "{|2006-01-02| :date}" }],
  )
  let stable_runtime = I18n::new(
    fallback_locale_code="en-US",
    contract_hash=TEST_CONTRACT_HASH,
    profile=MF2_STANDARD_MESSAGE_PROFILE,
  )
  guard stable_runtime.install_generated_catalog(stable) is Err(stable_error) else {
    fail("stable profile must reject Draft datetime")
  }
  assert_true(stable_error.contains("not in the pinned default registry"))
  let experimental = Catalog::from_generated_entries(
    locale_code="en-US",
    contract_hash=TEST_CONTRACT_HASH,
    profile=MF2_EXPERIMENTAL_DATETIME_MESSAGE_PROFILE,
    entries=[{ id: "updated", message: "{|2006-01-02| :date}" }],
  )
  let experimental_runtime = I18n::new(
    fallback_locale_code="en-US",
    contract_hash=TEST_CONTRACT_HASH,
    profile=MF2_EXPERIMENTAL_DATETIME_MESSAGE_PROFILE,
  )
  assert_true(
    experimental_runtime.install_generated_catalog(experimental) is Ok(_),
  )
  let legacy = Catalog::from_generated_entries(
    locale_code="en-US",
    contract_hash=TEST_CONTRACT_HASH,
    profile=MF2_LEGACY_STANDARD_MESSAGE_PROFILE,
    entries=[{ id: "updated", message: "{|2006-01-02| :date}" }],
  )
  let legacy_runtime = I18n::new(
    fallback_locale_code="en-US",
    contract_hash=TEST_CONTRACT_HASH,
    profile=MF2_LEGACY_STANDARD_MESSAGE_PROFILE,
  )
  assert_true(legacy_runtime.install_generated_catalog(legacy) is Ok(_))
}

///|
test "catalog v2 namespace chunks round trip and enforce membership" {
  let chunk = Catalog::from_generated_chunk_entries(
    locale_code="zh-CN",
    chunk_namespace="account settings",
    contract_hash=TEST_CONTRACT_HASH,
    entries=[{ id: "account settings.title", message: "账户设置" }],
  )
  guard parse_catalog(chunk.to_json_string()) is Ok(parsed) else {
    fail("expected a valid namespace chunk")
  }
  assert_eq(parsed.chunk_namespace(), Some("account settings"))
  assert_eq(parsed.find("account settings.title"), Some("账户设置"))
  let outside = Catalog::from_generated_chunk_entries(
    locale_code="zh-CN",
    chunk_namespace="account",
    contract_hash=TEST_CONTRACT_HASH,
    entries=[{ id: "common.title", message: "标题" }],
  )
  assert_true(
    outside.compile_messages()
    is Err("catalog chunk message is outside namespace account: common.title"),
  )
}

///|
test "catalog reports translated coverage using indexed lookups" {
  let catalog = Catalog::from_generated_entries(
    locale_code="ar",
    contract_hash=TEST_CONTRACT_HASH,
    direction="rtl",
    entries=[{ id: "common.save", message: "حفظ" }],
  )
  assert_eq(catalog.direction(), "rtl")
  assert_eq(catalog.coverage([]), 1.0)
  assert_eq(catalog.coverage(["common.save", "common.cancel"]), 0.5)
}

///|
test "catalog parser rejects legacy, fractional, and mismatched metadata" {
  assert_true(parse_catalog("not json") is Err("invalid catalog JSON"))
  let base = "{\"profile\":\"" +
    CATALOG_PROFILE +
    "\",\"contractHash\":\"" +
    TEST_CONTRACT_HASH +
    "\",\"locale\":\"en-US\",\"messages\":{}}"
  assert_true(
    parse_catalog("{\"catalogVersion\":1," + base[1:].to_owned())
    is Err("unsupported catalogVersion: 1"),
  )
  assert_true(
    parse_catalog("{\"catalogVersion\":1.9," + base[1:].to_owned())
    is Err("unsupported catalogVersion: 1.9"),
  )
  assert_true(
    parse_catalog(
      "{\"catalogVersion\":2,\"profile\":\"wrong\",\"contractHash\":\"" +
      TEST_CONTRACT_HASH +
      "\",\"locale\":\"en-US\",\"messages\":{}}",
    )
    is Err("unsupported catalog profile: wrong"),
  )
  assert_true(
    parse_catalog(
      "{\"catalogVersion\":2,\"profile\":\"" +
      CATALOG_PROFILE +
      "\",\"contractHash\":\"short\",\"locale\":\"en-US\",\"messages\":{}}",
    )
    is Err("contractHash must be a lowercase SHA-256 hex digest"),
  )
}

///|
test "catalog compilation validates every message before installation" {
  let catalog = Catalog::from_generated_entries(
    locale_code="en-US",
    contract_hash=TEST_CONTRACT_HASH,
    entries=[
      { id: "good", message: "Good" },
      { id: "bad", message: "Broken {" },
    ],
  )
  guard catalog.compile_messages() is Err(message) else {
    fail("malformed catalogs must not compile")
  }
  assert_true(message.contains("at bad"))
}

///|
test "generated catalogs retain construction errors until installation" {
  let duplicate = Catalog::from_generated_entries(
    locale_code="en-US",
    contract_hash=TEST_CONTRACT_HASH,
    entries=[{ id: "same", message: "one" }, { id: "same", message: "two" }],
  )
  assert_true(
    duplicate.compile_messages() is Err("duplicate catalog message id: same"),
  )
  let oversized = Catalog::from_generated_entries(
    locale_code="en-US",
    contract_hash=TEST_CONTRACT_HASH,
    entries=[
      { id: "large", message: "界".repeat(MF2_MAX_MESSAGE_BYTES / 3 + 1) },
    ],
  )
  assert_true(
    oversized.compile_messages()
    is Err("catalog message exceeds size limit: large"),
  )
}

///|
test "catalog parser validates every v2 field and entry shape" {
  let prefix = "{\"catalogVersion\":2,\"profile\":\"" +
    CATALOG_PROFILE +
    "\",\"contractHash\":\"" +
    TEST_CONTRACT_HASH +
    "\",\"locale\":\"en-US\""
  assert_true(parse_catalog("[]") is Err("catalog root must be an object"))
  assert_true(
    parse_catalog("{\"profile\":\"x\"}")
    is Err("catalogVersion must be an integer"),
  )
  assert_true(
    parse_catalog("{\"catalogVersion\":2,\"profile\":1}")
    is Err("profile must be a string"),
  )
  assert_true(
    parse_catalog(
      "{\"catalogVersion\":2,\"profile\":\"" + CATALOG_PROFILE + "\"}",
    )
    is Err("contractHash must be a string"),
  )
  assert_true(
    parse_catalog(
      "{\"catalogVersion\":2,\"profile\":\"" +
      CATALOG_PROFILE +
      "\",\"contractHash\":\"" +
      "G".repeat(64) +
      "\"}",
    )
    is Err("contractHash must be a lowercase SHA-256 hex digest"),
  )
  assert_true(
    parse_catalog(prefix + ",\"locale\":1}") is Err("locale must be a string"),
  )
  assert_true(
    parse_catalog(
      "{\"catalogVersion\":2,\"profile\":\"" +
      CATALOG_PROFILE +
      "\",\"contractHash\":\"" +
      TEST_CONTRACT_HASH +
      "\",\"locale\":\"en--US\",\"messages\":{}}",
    )
    is Err("invalid locale code: en--US"),
  )
  assert_true(
    parse_catalog(prefix + ",\"direction\":\"sideways\",\"messages\":{}}")
    is Err("direction must be ltr or rtl"),
  )
  assert_true(
    parse_catalog(prefix + ",\"direction\":1,\"messages\":{}}")
    is Err("direction must be a string"),
  )
  assert_true(
    parse_catalog(prefix + ",\"namespace\":1,\"messages\":{}}")
    is Err("namespace must be a string"),
  )
  assert_true(
    parse_catalog(prefix + ",\"namespace\":\"bad/name\",\"messages\":{}}")
    is Err(
      "catalog namespace must contain only ASCII letters, digits, '_', '-' or spaces"
    ),
  )
  assert_true(
    parse_catalog(
      prefix + ",\"namespace\":\"common\",\"messages\":{\"other.value\":\"x\"}}",
    )
    is Err("catalog chunk message is outside namespace common: other.value"),
  )
  guard parse_catalog(prefix + ",\"direction\":\"rtl\",\"messages\":{}}")
    is Ok(rtl) else {
    fail("rtl catalog should parse")
  }
  assert_eq(rtl.direction(), "rtl")
  assert_eq(rtl.message_count(), 0)
  assert_true(
    parse_catalog(prefix + ",\"messages\":[]}")
    is Err("messages must be an object"),
  )
  assert_true(
    parse_catalog(prefix + ",\"messages\":{\"\":\"x\"}}")
    is Err("catalog message id must not be empty"),
  )
  assert_true(
    parse_catalog(prefix + ",\"messages\":{\"x\":1}}")
    is Err("catalog message must be a string: x"),
  )
  assert_true(
    parse_catalog(
      prefix +
      ",\"messages\":{\"x\":\"" +
      "a".repeat(MF2_MAX_MESSAGE_BYTES + 1) +
      "\"}}",
    )
    is Err("catalog message exceeds size limit: x"),
  )
}

///|
test "catalog input byte limit is enforced before JSON parsing" {
  assert_true(parse_catalog("x".repeat(CATALOG_MAX_SOURCE_BYTES + 1)) is Err(_))
}
