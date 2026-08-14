///|
test "structured diagnostics expose stable human and JSON contracts" {
  let result = generate_with_diagnostics(
    "{",
    "{}",
    [],
    config_path="localization/config.json",
    schema_path="localization/schema.json",
    locale_directory="localization/locales",
  )
  guard result is Err([diagnostic]) else { fail("expected one diagnostic") }
  assert_eq(diagnostic.code, "I18N1001")
  assert_eq(diagnostic.path, "localization/config.json")
  assert_eq(diagnostic.span.start.line, 1)
  assert_eq(diagnostic.span.start.column, 1)
  assert_true(diagnostic.span.end.byte_offset > 0)
  assert_true(diagnostic.to_human_string().contains("error[I18N1001]"))
  let json = diagnostic.to_json_string()
  assert_true(json.contains("\"diagnosticVersion\": 1"))
  assert_true(json.contains("\"byteOffset\""))
}

///|
test "locale and MF2 failures retain locale source identity" {
  let config =
    #|{"sourceLocale":"en-US","defaultLocale":"en-US","fallbackLocale":"en-US","embeddedLocales":["en-US"],"locales":{"en-US":{}}}
  let schema =
    #|{"messages":{"common":["hello"]}}
  let locale =
    #|{"common":{"hello":"Hello {$missing}"}}
  let result = generate_with_diagnostics(
    config,
    schema,
    [{ code: "en-US", source: locale }],
    config_path="config.json",
    schema_path="schema.json",
    locale_directory="locales",
  )
  guard result is Err([diagnostic]) else { fail("expected one diagnostic") }
  assert_eq(diagnostic.code, "I18N3001")
  assert_eq(diagnostic.path, "locales/en-US.json")
}

///|
test "configuration diagnostics do not point at locale resources" {
  let config =
    #|{"sourceLocale":"bad locale","defaultLocale":"en-US","fallbackLocale":"en-US","embeddedLocales":["en-US"],"locales":{"en-US":{}}}
  let result = generate_with_diagnostics(
    config,
    "{}",
    [],
    config_path="config.json",
    schema_path="schema.json",
    locale_directory="locales",
  )
  guard result is Err([diagnostic]) else { fail("expected one diagnostic") }
  assert_eq(diagnostic.code, "I18N1002")
  assert_eq(diagnostic.path, "config.json")
}

///|
test "omitted profile and legacy datetime emit path-aware migration warnings" {
  let config =
    #|{"sourceLocale":"en-US","defaultLocale":"en-US","fallbackLocale":"en-US","embeddedLocales":["en-US"],"locales":{"en-US":{}}}
  let schema =
    #|{"messages":{"common":["updated"]},"params":{"common.updated":[{"name":"when","type":"InstantMillis"}]}}
  let locale =
    #|{"common":{"updated":"Updated {$when :lampclaw:datetime}"}}
  guard generate_with_diagnostics(
      config,
      schema,
      [{ code: "en-US", source: locale }],
      config_path="localization/config.json",
      schema_path="localization/schema.json",
      locale_directory="localization/locales",
    )
    is Ok(artifacts) else {
    fail("legacy generation should remain compatible")
  }
  assert_eq(artifacts.diagnostics.length(), 2)
  assert_eq(artifacts.diagnostics[0].code, "I18N1003")
  assert_eq(artifacts.diagnostics[0].severity, Warning)
  assert_eq(artifacts.diagnostics[0].path, "localization/config.json")
  assert_eq(artifacts.diagnostics[1].code, "I18N3003")
  assert_eq(artifacts.diagnostics[1].path, "localization/locales/en-US.json")
}

///|
test "standards profile rejects private datetime with a stable diagnostic" {
  let config =
    #|{"messageProfile":"unicode-mf2-ldml48.2-js-v1","sourceLocale":"en-US","defaultLocale":"en-US","fallbackLocale":"en-US","embeddedLocales":["en-US"],"locales":{"en-US":{}}}
  let schema =
    #|{"messages":{"common":["updated"]},"params":{"common.updated":[{"name":"when","type":"InstantMillis"}]}}
  let locale =
    #|{"common":{"updated":"Updated {$when :lampclaw:datetime}"}}
  guard generate_with_diagnostics(
      config,
      schema,
      [{ code: "en-US", source: locale }],
      config_path="config.json",
      schema_path="schema.json",
      locale_directory="locales",
    )
    is Err([diagnostic]) else {
    fail("private extension must fail standards-mode generation")
  }
  assert_eq(diagnostic.code, "I18N3004")
  assert_eq(diagnostic.path, "locales/en-US.json")
}
