///|
fn main {
  let locale = ZhCN
  let text : I18nText = Common(Hello)
  println(
    "exhaustive \{message_id(text)}: \{translate_for_locale(locale, text)}",
  )
}
