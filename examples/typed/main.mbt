///|
fn main {
  let i18n = I18n::new(fallback_locale=EnUS)
  let locale = ZhCN
  let translator = i18n.translator(locale)
  let text : I18nText = Common(Hello)
  let message = match translate_text(translator, text) {
    Some(value) => value
    None => "[missing: \{message_id(text)}]"
  }
  println("runtime bridge \{message_id(text)}: \{message}")
}
