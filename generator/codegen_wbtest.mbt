///|
test "generate typed bindings and embedded catalogs" {
  guard parse_config(config_source) is Ok(config) else {
    fail("config should parse")
  }
  guard parse_schema(schema_source) is Ok(schema) else {
    fail("schema should parse")
  }
  let en_source =
    #|{
    #|  "common": { "save": "Save" },
    #|  "counter": { "count": "{$count :number} clicks" }
    #|}
  guard parse_locale("en-US", en_source, schema) is Ok(en) else {
    fail("locale should parse")
  }
  let code = generate_bindings(config, schema, [en], "v1-test")
  assert_true(code.contains("pub const SCHEMA_HASH : String = \"v1-test\""))
  assert_true(code.contains("pub(all) enum I18nText"))
  assert_true(code.contains("Counter(CounterText)"))
  assert_true(code.contains("Count(Int)"))
  assert_true(code.contains("@runtime.IntValue(count)"))
  assert_true(code.contains("fn embedded_catalogs()"))
  assert_true(code.contains("message: \"{$count :number} clicks\""))
}

///|
test "generated bindings are stable regardless of schema JSON order" {
  let first =
    #|{
    #|  "messages": { "zebra": ["last"], "alpha": ["first"] }
    #|}
  let second =
    #|{
    #|  "messages": { "alpha": ["first"], "zebra": ["last"] }
    #|}
  guard parse_config(config_source) is Ok(config) else {
    fail("config should parse")
  }
  guard parse_schema(first) is Ok(first_schema) else {
    fail("first schema should parse")
  }
  guard parse_schema(second) is Ok(second_schema) else {
    fail("second schema should parse")
  }
  assert_eq(
    generate_bindings(config, first_schema, [], "same"),
    generate_bindings(config, second_schema, [], "same"),
  )
}

///|
test "DateTime schema parameters use ISO strings in generated MoonBit" {
  let source =
    #|{
    #|  "messages": { "article": ["published"] },
    #|  "params": {
    #|    "article.published": [
    #|      { "name": "published_at", "type": "DateTime" }
    #|    ]
    #|  }
    #|}
  guard parse_config(config_source) is Ok(config) else {
    fail("config should parse")
  }
  guard parse_schema(source) is Ok(schema) else { fail("schema should parse") }
  let code = generate_bindings(config, schema, [], "datetime")
  assert_true(code.contains("Published(String)"))
  assert_true(code.contains("@runtime.DateTimeValue(published_at)"))
}

///|
test "message IDs handle constructors with multiple parameters" {
  let source =
    #|{
    #|  "messages": { "account": ["greeting"] },
    #|  "params": {
    #|    "account.greeting": [
    #|      { "name": "name", "type": "String" },
    #|      { "name": "count", "type": "Int" }
    #|    ]
    #|  }
    #|}
  guard parse_config(config_source) is Ok(config) else {
    fail("config should parse")
  }
  guard parse_schema(source) is Ok(schema) else { fail("schema should parse") }
  let code = generate_bindings(config, schema, [], "multi")
  assert_true(code.contains("Greeting(String, Int)"))
  assert_true(code.contains("Greeting(_, _) => \"account.greeting\""))
  assert_true(code.contains("Greeting(name, count) => ["))
}
