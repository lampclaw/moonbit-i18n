///|
test "CLI exposes pseudo and XLIFF commands with explicit paths" {
  let help = usage()
  assert_true(help.contains("pseudo <schema-file> <source-locale>"))
  assert_true(help.contains("export-xliff <schema-file>"))
  assert_true(help.contains("<target.json|-> <output.xlf>"))
  assert_true(help.contains("import-xliff <schema-file>"))
  assert_eq(user_args(["node", "i18n.js", "pseudo", "schema.json"]), [
    "pseudo", "schema.json",
  ])
}
