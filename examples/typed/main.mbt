///|
fn required_message(translator : @i18n.Translator, id : String) -> String {
  match translator.translate(id) {
    Some(message) => message
    None => "[missing: \{id}]"
  }
}

///|
fn main {
  let i18n = @i18n.I18n::new(fallback_locale_code=EnUS.code())
  i18n.install_catalog(
    @i18n.Catalog::new(locale_code=EnUS.code(), entries=[
      { id: "common.hello", message: "Hello" },
      { id: "common.save", message: "Save" },
      { id: "auth.login", message: "Log in" },
    ]),
  )
  i18n.install_catalog(
    @i18n.Catalog::new(locale_code=ZhCN.code(), entries=[
      { id: "common.hello", message: "你好" },
      { id: "common.save", message: "保存" },
      { id: "auth.login", message: "登录" },
    ]),
  )
  let locale = ZhCN
  let translator = i18n.translator(locale.code())
  let text : I18nText = Common(Hello)
  println(
    "nested enum \{message_id(text)}: \{required_message(translator, message_id(text))}",
  )
}
