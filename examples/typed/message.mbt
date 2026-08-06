///|
pub(all) enum MessageKey {
  CommonHello
  CommonSave
  AuthLogin
} derive(Eq)

///|
pub fn message_id(key : MessageKey) -> String {
  match key {
    CommonHello => "common.hello"
    CommonSave => "common.save"
    AuthLogin => "auth.login"
  }
}

///|
pub fn translate_key(
  translator : @i18n.Translator,
  key : MessageKey,
) -> String? {
  translator.translate(message_id(key))
}
