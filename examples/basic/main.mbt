///|
fn message_or_placeholder(translator : @i18n.Translator, id : String) -> String {
  match translator.translate(id) {
    Some(message) => message
    None => "[missing: \{id}]"
  }
}

///|
fn main {
  let i18n = @i18n.I18n::new(fallback_locale_code="en-US")
  i18n.install_catalog(
    @i18n.Catalog::new(locale_code="en-US", entries=[
      { id: "common.hello", message: "Hello" },
      { id: "common.save", message: "Save" },
    ]),
  )
  i18n.install_catalog(
    @i18n.Catalog::new(locale_code="zh-CN", entries=[
      { id: "common.hello", message: "你好" },
    ]),
  )
  let translator = i18n.translator("zh-CN")
  println(
    "zh-CN common.hello: \{message_or_placeholder(translator, "common.hello")}",
  )
  println(
    "zh-CN common.save (fallback en-US): \{message_or_placeholder(translator, "common.save")}",
  )
}
