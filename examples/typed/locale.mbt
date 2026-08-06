///|
pub(all) enum Locale {
  EnUS
  ZhCN
} derive(Eq)

///|
pub fn Locale::code(self : Locale) -> String {
  match self {
    EnUS => "en-US"
    ZhCN => "zh-CN"
  }
}

///|
pub fn locale_from_code(code : String, fallback : Locale) -> Locale {
  match @i18n.normalize_locale_code(code) {
    Ok("en-US") => EnUS
    Ok("zh-CN") => ZhCN
    _ => fallback
  }
}
