///|
pub(all) enum I18nText {
  Common(CommonText)
  Auth(AuthText)
} derive(Eq)

///|
pub(all) enum CommonText {
  Hello
  Save
} derive(Eq)

///|
pub(all) enum AuthText {
  Login
} derive(Eq)

///|
pub fn message_id(text : I18nText) -> String {
  match text {
    Common(common) =>
      match common {
        Hello => "common.hello"
        Save => "common.save"
      }
    Auth(auth) =>
      match auth {
        Login => "auth.login"
      }
  }
}

///|
pub fn translate_text(
  translator : @i18n.Translator,
  text : I18nText,
) -> String? {
  translator.translate(message_id(text))
}
