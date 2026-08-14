///|
test "CLI exposes pseudo and XLIFF commands with explicit paths" {
  let help = usage()
  assert_true(help.contains("pseudo <schema-file> <source-locale>"))
  assert_true(help.contains("export-xliff [--state"))
  assert_true(help.contains("--state <exchange-state.json>"))
  assert_true(help.contains("<target.json|-> <output.xlf>"))
  assert_true(help.contains("--state-output <exchange-state.json>"))
  assert_true(help.contains("import-i18next <schema-file>"))
  assert_true(help.contains("import-arb <schema-file>"))
  assert_eq(user_args(["node", "i18n.js", "pseudo", "schema.json"]), [
    "pseudo", "schema.json",
  ])
}
