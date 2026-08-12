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
