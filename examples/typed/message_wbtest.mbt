///|
test "nested message enums map to stable ids" {
  assert_eq(message_id(Common(Hello)), "common.hello")
  assert_eq(message_id(Common(Save)), "common.save")
  assert_eq(message_id(Auth(Login)), "auth.login")
}

///|
test "translate_text uses the runtime translator" {
  let i18n = @i18n.I18n::new(fallback_locale_code="en-US")
  assert_true(
    i18n.install_catalog(
      @i18n.Catalog::new(locale_code="en-US", schema_hash="typed-example-v1", entries=[
        { id: "auth.login", message: "Log in" },
      ]),
    )
    is Ok(_),
  )
  assert_eq(
    translate_text(i18n.translator("en-US"), Auth(Login)),
    Some("Log in"),
  )
}
