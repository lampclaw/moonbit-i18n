///|
let config_source =
  #|{
  #|  "messageProfile": "lampclaw-mf2-strict-v1+lampclaw-datetime-v1",
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
  assert_eq(config.message_profile, @runtime.CATALOG_PROFILE)
  assert_true(config.message_profile_explicit)
  assert_eq(config.locales[0], { code: "ar", direction: "rtl" })
  assert_eq(config.minimum_coverage, 0.8)
}

///|
test "config accepts explicit compatibility and standards profiles" {
  let standard = config_source.replace_all(
    old=@runtime.CATALOG_PROFILE,
    new=@runtime.MF2_STANDARD_MESSAGE_PROFILE,
  )
  guard parse_config(standard) is Ok(config) else {
    fail("standards profile should parse")
  }
  assert_eq(config.message_profile, @runtime.MF2_STANDARD_MESSAGE_PROFILE)
  assert_true(config.message_profile_explicit)
  let legacy = standard.replace_all(
    old=@runtime.MF2_STANDARD_MESSAGE_PROFILE,
    new=@runtime.CATALOG_PROFILE,
  )
  guard parse_config(legacy) is Ok(legacy_config) else {
    fail("explicit compatibility profile should parse")
  }
  assert_eq(legacy_config.message_profile, @runtime.CATALOG_PROFILE)
  assert_true(legacy_config.message_profile_explicit)
  assert_config_error(
    standard.replace_all(
      old=@runtime.MF2_STANDARD_MESSAGE_PROFILE,
      new="unknown-profile",
    ),
  )
  assert_config_error(
    standard.replace_all(
      old="\"" + @runtime.MF2_STANDARD_MESSAGE_PROFILE + "\"",
      new="1",
    ),
  )
}

///|
test "config requires an explicit message profile" {
  let omitted = config_source.replace_all(
    old="  \"messageProfile\": \"lampclaw-mf2-strict-v1+lampclaw-datetime-v1\",\n",
    new="",
  )
  guard parse_config(omitted) is Err(message) else {
    fail("omitted messageProfile must fail")
  }
  assert_true(message.contains("messageProfile is required"))
}

///|
test "standards profile validates schema contracts and rejects private functions" {
  guard parse_schema(
      "{\"messages\":{\"common\":[\"value\"]},\"params\":{\"common.value\":[{\"name\":\"count\",\"type\":\"Int\"}]},\"parts\":{\"common.value\":[\"strong\"]}}",
    )
    is Ok(schema) else {
    fail("schema should parse")
  }
  assert_true(
    parse_locale(
      "en-US",
      "{\"common\":{\"value\":\"{#strong}{$count :number}{/strong}\"}}",
      schema,
      message_profile=@runtime.MF2_STANDARD_MESSAGE_PROFILE,
    )
    is Ok(_),
  )
  guard parse_locale(
      "en-US",
      "{\"common\":{\"value\":\"{$count :lampclaw:datetime}\"}}",
      schema,
      message_profile=@runtime.MF2_STANDARD_MESSAGE_PROFILE,
    )
    is Err(private_error) else {
    fail("private function must not enter standards-mode catalogs")
  }
  assert_true(private_error.contains(":lampclaw:datetime"))
  guard parse_locale(
      "en-US",
      "{\"common\":{\"value\":\"{$missing :number}\"}}",
      schema,
      message_profile=@runtime.MF2_STANDARD_MESSAGE_PROFILE,
    )
    is Err(variable_error) else {
    fail("unknown standard variable must fail the schema contract")
  }
  assert_true(variable_error.contains("not declared in schema params"))
}

///|
test "stable profile rejects Draft datetime and experimental profile accepts it" {
  guard parse_schema(
      "{\"messages\":{\"common\":[\"updated\"]},\"params\":{\"common.updated\":[{\"name\":\"when\",\"type\":\"InstantMillis\"}]}}",
    )
    is Ok(schema) else {
    fail("schema should parse")
  }
  let source = "{\"common\":{\"updated\":\"Updated {$when :date length=medium timeZone=UTC}\"}}"
  guard parse_locale(
      "en-US",
      source,
      schema,
      message_profile=@runtime.MF2_STANDARD_MESSAGE_PROFILE,
    )
    is Err(message) else {
    fail("stable profile must reject Draft datetime")
  }
  assert_true(message.contains("experimental-datetime-v1"))
  assert_true(
    parse_locale(
      "en-US",
      source,
      schema,
      message_profile=@runtime.MF2_EXPERIMENTAL_DATETIME_MESSAGE_PROFILE,
    )
    is Ok(_),
  )
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
    #|  "messageProfile": "lampclaw-mf2-strict-v1+lampclaw-datetime-v1",
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

///|
test "blank locale values are omitted from coverage input" {
  guard parse_schema(schema_source) is Ok(schema) else {
    fail("schema should parse")
  }
  let source =
    #|{
    #|  "common": { "save": "   " },
    #|  "counter": { "count": "{$count :number} clicks" }
    #|}
  guard parse_locale("en-US", source, schema) is Ok(locale) else {
    fail("blank translations should be treated as missing")
  }
  assert_eq(locale.entries.length(), 1)
  assert_eq(locale.entries[0].key, "count")
}

///|
test "locale validation checks unselected MF2 branches" {
  guard parse_schema(schema_source) is Ok(schema) else {
    fail("schema should parse")
  }
  let source =
    #|{
    #|  "counter": {
    #|    "count": ".input {$count :number}\n.match $count\none {{One}}\n* {{{$missing}}}"
    #|  }
    #|}
  guard parse_locale("en-US", source, schema) is Err(message) else {
    fail("an invalid unselected branch should fail")
  }
  assert_true(message.contains("unknown variable: missing"))
}

///|
test "locale validation requires wildcard matcher fallback" {
  guard parse_schema(schema_source) is Ok(schema) else {
    fail("schema should parse")
  }
  let source =
    #|{
    #|  "counter": {
    #|    "count": ".input {$count :number}\n.match $count\none {{One}}"
    #|  }
    #|}
  guard parse_locale("en-US", source, schema) is Err(message) else {
    fail("a matcher without a fallback should fail")
  }
  assert_true(message.contains("all-wildcard fallback"))
}

///|
test "schema bounds generated parameter and rich-tag arity" {
  let params : Array[Json] = []
  for i = 0; i <= I18N_MAX_PARAMS_PER_MESSAGE; i = i + 1 {
    params.push(
      Json::object({
        "name": Json::string("p\{i}"),
        "type": Json::string("String"),
      }),
    )
  }
  assert_true(
    parse_schema_params(
      "group.key",
      params[:I18N_MAX_PARAMS_PER_MESSAGE].to_owned(),
    )
    is Ok(_),
  )
  guard parse_schema_params("group.key", params) is Err(param_error) else {
    fail("excessive generated function arity should fail")
  }
  assert_true(param_error.contains("parameter limit"))
  let tags : Array[String] = []
  for i = 0; i <= I18N_MAX_PART_TAGS_PER_MESSAGE; i = i + 1 {
    tags.push("\"tag\{i}\"")
  }
  let schema = "{\"messages\":{\"group\":[\"key\"]},\"parts\":{\"group.key\":[" +
    tags.join(",") +
    "]}}"
  guard parse_schema(schema) is Err(tag_error) else {
    fail("excessive rich-tag arity should fail")
  }
  assert_true(tag_error.contains("tag limit"))
}

///|
fn assert_config_error(source : String) -> Unit raise {
  assert_true(parse_config(source) is Err(_), msg=source)
}

///|
fn assert_schema_error(source : String) -> Unit raise {
  assert_true(parse_schema(source) is Err(_), msg=source)
}

///|
test "config parser rejects malformed fields and invalid release policy" {
  let valid =
    #|{"messageProfile":"lampclaw-mf2-strict-v1+lampclaw-datetime-v1","sourceLocale":"en-US","defaultLocale":"en-US","fallbackLocale":"en-US","embeddedLocales":[],"locales":{"en-US":{}}}
  assert_config_error("not-json")
  assert_config_error("[]")
  assert_config_error("{}")
  assert_config_error(
    valid.replace_all(
      old="\"defaultLocale\":\"en-US\"",
      new="\"defaultLocale\":1",
    ),
  )
  assert_config_error(
    valid.replace_all(
      old="\"fallbackLocale\":\"en-US\"",
      new="\"fallbackLocale\":1",
    ),
  )
  assert_config_error(
    valid.replace_all(
      old="\"embeddedLocales\":[]",
      new="\"embeddedLocales\":{}",
    ),
  )
  assert_config_error(
    valid.replace_all(
      old="\"embeddedLocales\":[]",
      new="\"embeddedLocales\":[1]",
    ),
  )
  assert_config_error(
    valid.replace_all(
      old="\"embeddedLocales\":[]",
      new="\"embeddedLocales\":[\"en--US\"]",
    ),
  )
  assert_config_error(
    valid.replace_all(
      old="\"embeddedLocales\":[]",
      new="\"embeddedLocales\":[\"en-US\",\"en_US\"]",
    ),
  )
  assert_config_error(
    valid.replace_all(old="\"locales\":{\"en-US\":{}}", new="\"locales\":[]"),
  )
  assert_config_error(valid.replace_all(old="\"en-US\":{}", new="\"en-US\":1"))
  assert_config_error(
    valid.replace_all(
      old="\"en-US\":{}",
      new="\"en-US\":{\"direction\":\"up\"}",
    ),
  )
  assert_config_error(
    valid.replace_all(old="\"locales\":{\"en-US\":{}}", new="\"locales\":{}"),
  )
  assert_config_error(
    valid.replace_all(
      old="\"sourceLocale\":\"en-US\"",
      new="\"sourceLocale\":\"fr\"",
    ),
  )
  assert_config_error(
    valid.replace_all(
      old="\"embeddedLocales\":[]",
      new="\"embeddedLocales\":[\"fr\"]",
    ),
  )
  let without_close = valid[:valid.length() - 1].to_owned()
  assert_config_error(without_close + ",\"release\":1}")
  assert_config_error(
    without_close + ",\"release\":{\"minimumCoverage\":\"all\"}}",
  )
  assert_config_error(without_close + ",\"release\":{\"minimumCoverage\":1.1}}")
  assert_config_error("x".repeat(@runtime.CATALOG_MAX_SOURCE_BYTES + 1))
  assert_config_error(
    valid
    .replace_all(
      old="\"locales\":{\"en-US\":{}}",
      new="\"locales\":{\"en-1\":{},\"en1\":{}}",
    )
    .replace_all(old="\"en-US\"", new="\"en-1\""),
  )
}

///|
test "schema parser rejects malformed messages, metadata, params, and parts" {
  assert_schema_error("not-json")
  assert_schema_error("[]")
  assert_schema_error("{}")
  assert_schema_error("{\"messages\":[],\"params\":{}}")
  assert_schema_error("{\"messages\":{},\"params\":{}}")
  assert_schema_error("{\"messages\":{\"\":[\"x\"]}}")
  assert_schema_error("{\"messages\":{\"1group\":[\"x\"]}}")
  assert_schema_error("{\"messages\":{\"bad!\":[\"x\"]}}")
  assert_schema_error("{\"messages\":{\"common\":{}}}")
  assert_schema_error("{\"messages\":{\"common\":[1]}}")
  assert_schema_error("{\"messages\":{\"common\":[\"bad!\"]}}")
  assert_schema_error("{\"messages\":{\"common\":[\"save\",\"save\"]}}")
  assert_schema_error(
    "{\"messages\":{\"common\":[\"save\"]},\"params\":{\"common.save\":{}}}",
  )
  assert_schema_error(
    "{\"messages\":{\"common\":[\"save\"]},\"params\":{\"common.save\":[1]}}",
  )
  assert_schema_error(
    "{\"messages\":{\"common\":[\"save\"]},\"params\":{\"common.save\":[{\"type\":\"String\"}]}}",
  )
  assert_schema_error(
    "{\"messages\":{\"common\":[\"save\"]},\"params\":{\"common.save\":[{\"name\":\"Upper\",\"type\":\"String\"}]}}",
  )
  assert_schema_error(
    "{\"messages\":{\"common\":[\"save\"]},\"params\":{\"common.save\":[{\"name\":\"ok\",\"type\":\"String\"},{\"name\":\"ok\",\"type\":\"String\"}]}}",
  )
  assert_schema_error(
    "{\"messages\":{\"common\":[\"save\"]},\"params\":{\"common.save\":[{\"name\":\"ok\",\"type\":1}]}}",
  )
  assert_schema_error(
    "{\"messages\":{\"common\":[\"save\"]},\"params\":{\"common.save\":[{\"name\":\"ok\",\"type\":\"DateTime\"}]}}",
  )
  assert_schema_error(
    "{\"messages\":{\"common\":[\"save\"]},\"descriptions\":[]}",
  )
  assert_schema_error(
    "{\"messages\":{\"common\":[\"save\"]},\"descriptions\":{\"missing\":\"x\"}}",
  )
  assert_schema_error(
    "{\"messages\":{\"common\":[\"save\"]},\"descriptions\":{\"common.save\":1}}",
  )
  assert_schema_error("{\"messages\":{\"common\":[\"save\"]},\"parts\":[]}")
  assert_schema_error(
    "{\"messages\":{\"common\":[\"save\"]},\"parts\":{\"missing\":[]}}",
  )
  assert_schema_error(
    "{\"messages\":{\"common\":[\"save\"]},\"parts\":{\"common.save\":{}}}",
  )
  assert_schema_error(
    "{\"messages\":{\"common\":[\"save\"]},\"parts\":{\"common.save\":[1]}}",
  )
  assert_schema_error(
    "{\"messages\":{\"common\":[\"save\"]},\"parts\":{\"common.save\":[\"1tag\"]}}",
  )
  assert_schema_error(
    "{\"messages\":{\"common\":[\"save\"]},\"parts\":{\"common.save\":[\"bad!\"]}}",
  )
  assert_schema_error(
    "{\"messages\":{\"common\":[\"save\"]},\"parts\":{\"common.save\":[\"b\",\"b\"]}}",
  )
  assert_schema_error("{\"messages\":{\"self\":[\"value\"]}}")
  assert_schema_error("{\"messages\":{\"common\":[\"self\"]}}")
  assert_schema_error("{\"messages\":{\"common\":[\"a-b\",\"a_b\"]}}")
  assert_schema_error("x".repeat(@runtime.CATALOG_MAX_SOURCE_BYTES + 1))
}

///|
test "locale parser validates resource shapes and supports object entries with parts" {
  guard parse_schema(
      "{\"messages\":{\"common\":[\"save\"]},\"parts\":{\"common.save\":[\"b\"]}}",
    )
    is Ok(schema) else {
    fail("parts schema should parse")
  }
  assert_true(parse_locale("en--US", "{}", schema) is Err(_))
  assert_true(parse_locale("en-US", "not-json", schema) is Err(_))
  assert_true(parse_locale("en-US", "[]", schema) is Err(_))
  assert_true(parse_locale("en-US", "{\"common\":[]}", schema) is Err(_))
  assert_true(
    parse_locale("en-US", "{\"common\":{\"missing\":\"x\"}}", schema) is Err(_),
  )
  assert_true(
    parse_locale("en-US", "{\"common\":{\"save\":{}}}", schema) is Err(_),
  )
  assert_true(
    parse_locale("en-US", "{\"common\":{\"save\":1}}", schema) is Err(_),
  )
  assert_true(
    parse_locale(
      "en-US", "{\"common\":{\"save\":{\"text\":\"{#b}Save{/b}\"}}}", schema,
    )
    is Ok(_),
  )
  assert_true(
    parse_locale(
      "en-US",
      "x".repeat(@runtime.CATALOG_MAX_SOURCE_BYTES + 1),
      schema,
    )
    is Err(_),
  )
}
