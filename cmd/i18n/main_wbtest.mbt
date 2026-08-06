///|
test "CLI finds arguments after Moon's separator" {
  assert_eq(
    user_args([
      "moon", "run", "cmd/i18n", "--", "coverage", "config.json", "schema.json",
      "locales",
    ]),
    ["coverage", "config.json", "schema.json", "locales"],
  )
}

///|
test "CLI accepts direct command arguments" {
  assert_eq(
    user_args(["node", "i18n.js", "check", "--allow-partial", "config"]),
    ["check", "--allow-partial", "config"],
  )
  assert_eq(without_allow_partial(["generate", "--allow-partial", "config"]), [
    "generate", "config",
  ])
}

///|
test "CLI usage documents explicit input and output paths" {
  let help = usage()
  assert_true(help.contains("<config-file> <schema-file> <locale-dir>"))
  assert_true(help.contains("<output.mbt> <catalog-dir>"))
}
