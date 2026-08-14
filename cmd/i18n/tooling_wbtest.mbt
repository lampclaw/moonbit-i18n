///|
test "CLI exposes pseudo and XLIFF commands with explicit paths" {
  let help = usage()
  assert_true(help.contains("pseudo [--message-profile <profile>]"))
  assert_true(help.contains("export-xliff [--message-profile <profile>]"))
  assert_true(help.contains("--state <exchange-state.json>"))
  assert_true(help.contains("<target.json|-> <output.xlf>"))
  assert_true(help.contains("--state-output <exchange-state.json>"))
  assert_true(help.contains("import-i18next [--message-profile <profile>]"))
  assert_true(help.contains("import-arb [--message-profile <profile>]"))
  assert_eq(user_args(["node", "i18n.js", "pseudo", "schema.json"]), [
    "pseudo", "schema.json",
  ])
}
