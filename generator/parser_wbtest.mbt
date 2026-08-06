///|
let config_source =
  #|{
  #|  "sourceLocale": "en_US",
  #|  "defaultLocale": "zh-CN",
  #|  "fallbackLocale": "en-US",
  #|  "embeddedLocales": ["en-US"],
  #|  "release": { "minimumCoverage": 0.8 },
  #|  "locales": {
  #|    "en-US": { "direction": "ltr" },
  #|    "ar": { "direction": "rtl" },
  #|    "zh-CN": {}
  #|  }
  #|}

///|
let schema_source =
  #|{
  #|  "messages": {
  #|    "common": ["save"],
  #|    "counter": ["count"]
  #|  },
  #|  "params": {
  #|    "counter.count": [{ "name": "count", "type": "Int" }]
  #|  },
  #|  "descriptions": {
  #|    "counter.count": "Visible click count"
  #|  }
  #|}

///|
test "parse final i18n config" {
  guard parse_config(config_source) is Ok(config) else {
    fail("config should parse")
  }
  assert_eq(config.source_locale, "en-US")
  assert_eq(config.locales[0], { code: "ar", direction: "rtl" })
  assert_eq(config.minimum_coverage, 0.8)
}

///|
test "config rejects locale codes that cannot form MoonBit variants" {
  let source = config_source
    .replace_all(old="\"en_US\"", new="\"123\"")
    .replace_all(old="\"en-US\"", new="\"123\"")
  guard parse_config(source) is Err(message) else {
    fail("numeric language code should fail")
  }
  assert_true(message.contains("must start with an ASCII letter"))
}

///|
test "config rejects duplicate normalized locale codes" {
  let source =
    #|{
    #|  "sourceLocale": "en-US",
    #|  "defaultLocale": "en-US",
    #|  "fallbackLocale": "en-US",
    #|  "embeddedLocales": [],
    #|  "locales": { "en-US": {}, "en_US": {} }
    #|}
  guard parse_config(source) is Err(message) else {
    fail("duplicate normalized locale should fail")
  }
  assert_true(message.contains("duplicate normalized locale"))
}

///|
test "parse schema and validate a partial locale" {
  guard parse_schema(schema_source) is Ok(schema) else {
    fail("schema should parse")
  }
  assert_eq(schema.entries.length(), 2)
  assert_eq(schema.entries[1].params, [{ name: "count", typ: "Int" }])
  let locale_source =
    #|{
    #|  "counter": {
    #|    "count": ".input {$count :number}\n.match $count\none {{One click}}\n* {{{$count} clicks}}"
    #|  }
    #|}
  guard parse_locale("en_US", locale_source, schema) is Ok(locale) else {
    fail("locale should parse")
  }
  assert_eq(locale.locale, "en-US")
  assert_eq(locale.entries.length(), 1)
}

///|
test "schema rejects generated identifier collisions" {
  let source =
    #|{
    #|  "messages": {
    #|    "account-menu": ["title"],
    #|    "account_menu": ["title"]
    #|  }
    #|}
  guard parse_schema(source) is Err(message) else {
    fail("colliding group names should fail")
  }
  assert_true(message.contains("same enum variant"))
}

///|
test "schema rejects metadata for unknown messages" {
  let source =
    #|{
    #|  "messages": { "common": ["save"] },
    #|  "params": { "common.missing": [] }
    #|}
  guard parse_schema(source) is Err(message) else {
    fail("orphan schema params should fail")
  }
  assert_true(message.contains("params reference unknown message"))
}

///|
test "schema rejects names reserved by generated bindings" {
  let source =
    #|{
    #|  "messages": { "i18n": ["value"] }
    #|}
  guard parse_schema(source) is Err(message) else {
    fail("reserved generated type should fail")
  }
  assert_true(message.contains("reserved I18nText type name"))
}

///|
test "schema rejects MoonBit keywords as parameter names" {
  let source =
    #|{
    #|  "messages": { "common": ["value"] },
    #|  "params": {
    #|    "common.value": [{ "name": "match", "type": "String" }]
    #|  }
    #|}
  guard parse_schema(source) is Err(message) else {
    fail("keyword parameter should fail")
  }
  assert_true(message.contains("MoonBit keyword"))
}

///|
test "schema rejects the MoonBit wildcard as a parameter name" {
  let source =
    #|{
    #|  "messages": { "common": ["value"] },
    #|  "params": {
    #|    "common.value": [{ "name": "_", "type": "String" }]
    #|  }
    #|}
  guard parse_schema(source) is Err(message) else {
    fail("wildcard parameter should fail")
  }
  assert_true(message.contains("MoonBit wildcard"))
}

///|
test "locale rejects unknown messages and MF2 variables" {
  guard parse_schema(schema_source) is Ok(schema) else {
    fail("schema should parse")
  }
  guard parse_locale(
      "en-US", "{ \"counter\": { \"count\": \"{$missing}\" } }", schema,
    )
    is Err(message) else {
    fail("unknown variable should fail")
  }
  assert_true(message.contains("unknown variable: missing"))
}

///|
test "locale rejects an empty unknown group" {
  guard parse_schema(schema_source) is Ok(schema) else {
    fail("schema should parse")
  }
  guard parse_locale("en-US", "{ \"unknown\": {} }", schema) is Err(message) else {
    fail("unknown group should fail")
  }
  assert_true(message.contains("unknown message group"))
}
