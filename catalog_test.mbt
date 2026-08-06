///|
test "catalog round trips through JSON" {
  let catalog = Catalog::new(locale_code="en-us", schema_hash="schema-1", entries=[
    { id: "auth.welcome", message: "Hello {$name}" },
  ])
  let parsed = parse_catalog(catalog.to_json_string())
  guard parsed is Ok(value) else { fail("expected a valid catalog") }
  assert_eq(value.locale_code(), "en-US")
  assert_eq(value.schema_hash(), "schema-1")
  assert_eq(value.direction(), "ltr")
  assert_eq(value.catalog_version(), 1)
  assert_eq(value.find("auth.welcome"), Some("Hello {$name}"))
}

///|
test "catalog reports translated coverage" {
  let catalog = Catalog::new(
    locale_code="ar",
    schema_hash="schema-1",
    direction="rtl",
    entries=[{ id: "common.save", message: "حفظ" }],
  )
  assert_eq(catalog.direction(), "rtl")
  assert_eq(catalog.coverage([]), 1.0)
  assert_eq(catalog.coverage(["common.save", "common.cancel"]), 0.5)
}

///|
test "catalog parser rejects invalid metadata" {
  assert_true(parse_catalog("not json") is Err("invalid catalog JSON"))
  assert_true(
    parse_catalog(
      (
        #|{"catalogVersion":2,"schemaHash":"s","locale":"en-US","messages":{}}
      ),
    )
    is Err("unsupported catalogVersion: 2"),
  )
  assert_true(
    parse_catalog(
      (
        #|{"catalogVersion":1,"schemaHash":"s","locale":"en-US","direction":"sideways","messages":{}}
      ),
    )
    is Err("direction must be ltr or rtl"),
  )
}
