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
    ]),
  )
  i18n.install_catalog(
    @i18n.Catalog::new(locale_code=ZhCN.code(), entries=[
      { id: "common.hello", message: "你好" },
    ]),
  )
  let locale = ZhCN
  let translator = i18n.translator(locale.code())
  println(
    "typed locale \{locale.code()}: \{required_message(translator, "common.hello")}",
  )
}
