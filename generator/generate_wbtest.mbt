///|
let generation_config =
  #|{
  #|  "sourceLocale": "en-US",
  #|  "defaultLocale": "zh-CN",
  #|  "fallbackLocale": "en-US",
  #|  "embeddedLocales": ["en-US"],
  #|  "release": { "minimumCoverage": 0.5 },
  #|  "locales": {
  #|    "en-US": { "direction": "ltr" },
  #|    "zh-CN": { "direction": "ltr" }
  #|  }
  #|}

///|
let en_generation_source =
  #|{
  #|  "common": { "save": "Save" },
  #|  "counter": { "count": "{$count :number} clicks" }
  #|}

///|
let zh_generation_source =
  #|{
  #|  "counter": { "count": "点击 {$count :number} 次" }
  #|}

///|
test "generate catalog artifacts and coverage report" {
  guard generate(generation_config, schema_source, [
      { code: "zh_CN", source: zh_generation_source },
      { code: "en-US", source: en_generation_source },
    ])
    is Ok(artifacts) else {
    fail("artifact generation should succeed")
  }
  assert_eq(artifacts.contract_hash.length(), 64)
  assert_true(artifacts.package_manifest.contains("supported_targets = \"js\""))
  assert_eq(artifacts.catalogs.length(), 2)
  assert_true(artifacts.catalogs[0].1.contains("\"catalogVersion\": 2"))
  assert_true(artifacts.catalogs[0].1.contains(artifacts.contract_hash))
  guard @runtime.parse_catalog(artifacts.catalogs[0].1) is Ok(catalog) else {
    fail("generated catalog should round-trip through the runtime parser")
  }
  assert_eq(catalog.locale_code(), "en-US")
  assert_eq(catalog.contract_hash(), artifacts.contract_hash)
  assert_eq(catalog.find("common.save"), Some("Save"))
  assert_true(artifacts.coverage_report.contains("en-US: 2/2 (100%)"))
  assert_true(artifacts.coverage_report.contains("zh-CN: 1/2 (50%)"))
}

///|
test "source and fallback locales must be complete" {
  let result = generate(generation_config, schema_source, [
    { code: "en-US", source: zh_generation_source },
    { code: "zh-CN", source: zh_generation_source },
  ])
  guard result is Err(message) else { fail("incomplete source should fail") }
  assert_true(
    message.contains("source locale is incomplete: en-US: common.save"),
  )
}

///|
test "blank source translations are incomplete" {
  let blank_source =
    #|{
    #|  "common": { "save": "   " },
    #|  "counter": { "count": "{$count :number} clicks" }
    #|}
  guard generate(generation_config, schema_source, [
      { code: "en-US", source: blank_source },
      { code: "zh-CN", source: zh_generation_source },
    ])
    is Err(message) else {
    fail("blank source translation should fail completeness")
  }
  assert_true(message.contains("source locale is incomplete"))
  assert_true(message.contains("common.save"))
}

///|
test "contract hash ignores JSON formatting, object order, and descriptions" {
  let reordered_schema =
    #|{
    #|  "descriptions": { "counter.count": "Updated translator note" },
    #|  "params": {
    #|    "counter.count": [{ "type": "Int", "name": "count" }]
    #|  },
    #|  "messages": {
    #|    "counter": ["count"],
    #|    "common": ["save"]
    #|  }
    #|}
  guard parse_schema(schema_source) is Ok(first) else {
    fail("first schema should parse")
  }
  guard parse_schema(reordered_schema) is Ok(second) else {
    fail("second schema should parse")
  }
  assert_eq(contract_hash(first), contract_hash(second))
}

///|
test "contract hash changes when the typed API changes" {
  guard parse_schema(schema_source) is Ok(original) else {
    fail("original schema should parse")
  }
  let changed_source = schema_source.replace_all(
    old="\"type\": \"Int\"",
    new="\"type\": \"Double\"",
  )
  guard parse_schema(changed_source) is Ok(changed) else {
    fail("changed schema should parse")
  }
  assert_true(contract_hash(original) != contract_hash(changed))
}

///|
test "release coverage can be enforced or reported only" {
  let strict_config = generation_config.replace_all(
    old="\"minimumCoverage\": 0.5",
    new="\"minimumCoverage\": 1.0",
  )
  let sources = [
    { code: "en-US", source: en_generation_source },
    { code: "zh-CN", source: zh_generation_source },
  ]
  guard generate(strict_config, schema_source, sources) is Err(message) else {
    fail("strict coverage should fail")
  }
  assert_true(message.contains("zh-CN is 50%, required 100%"))
  assert_true(
    generate(strict_config, schema_source, sources, enforce_coverage=false)
    is Ok(_),
  )
}

///|
test "generation rejects undeclared and duplicate locale sources" {
  guard generate(generation_config, schema_source, [
      { code: "en-US", source: en_generation_source },
      { code: "zh-CN", source: zh_generation_source },
      { code: "fr", source: "{}" },
    ])
    is Err(undeclared) else {
    fail("undeclared locale source should fail")
  }
  assert_true(undeclared.contains("not declared in config: fr"))
  guard generate(generation_config, schema_source, [
      { code: "en-US", source: en_generation_source },
      { code: "zh-CN", source: zh_generation_source },
      { code: "en_US", source: en_generation_source },
    ])
    is Err(duplicate) else {
    fail("duplicate normalized locale source should fail")
  }
  assert_true(duplicate.contains("duplicate locale source: en-US"))
}

///|
test "generation budgets use aggregate UTF-8 bytes and locale count" {
  assert_eq(
    validate_locale_source_budget(
      [{ code: "en", source: "a" }, { code: "zh", source: "界" }],
      2,
      4,
    ),
    Ok(()),
  )
  guard validate_locale_source_budget(
      [{ code: "en", source: "aa" }, { code: "zh", source: "界" }],
      2,
      4,
    )
    is Err(byte_error) else {
    fail("aggregate UTF-8 overflow should fail")
  }
  assert_true(byte_error.contains("aggregate UTF-8 limit"))
  guard validate_locale_source_budget(
      [{ code: "en", source: "" }, { code: "zh", source: "" }],
      1,
      4,
    )
    is Err(count_error) else {
    fail("locale count overflow should fail")
  }
  assert_true(count_error.contains("1-locale limit"))
  assert_eq(validate_generated_code_budget("界", 3), Ok(()))
  assert_true(validate_generated_code_budget("界a", 3) is Err(_))
}
