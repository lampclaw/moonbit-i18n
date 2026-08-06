///|
test "typed message keys map to stable ids" {
  assert_eq(message_id(CommonHello), "common.hello")
  assert_eq(message_id(CommonSave), "common.save")
  assert_eq(message_id(AuthLogin), "auth.login")
}

///|
test "translate_key uses the runtime translator" {
  let i18n = @i18n.I18n::new(fallback_locale_code="en-US")
  i18n.install_catalog(
    @i18n.Catalog::new(locale_code="en-US", entries=[
      { id: "auth.login", message: "Log in" },
    ]),
  )
  assert_eq(translate_key(i18n.translator("en-US"), AuthLogin), Some("Log in"))
}
