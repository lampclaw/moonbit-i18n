///|
pub fn all_texts() -> Array[I18nText] {
  [Common(Hello), Common(Save), Auth(Login)]
}

///|
pub fn translate_en_us(text : I18nText) -> String {
  match text {
    Common(common) =>
      match common {
        Hello => "Hello"
        Save => "Save"
      }
    Auth(auth) =>
      match auth {
        Login => "Log in"
      }
  }
}

///|
pub fn translate_zh_cn(text : I18nText) -> String {
  match text {
    Common(common) =>
      match common {
        Hello => "你好"
        Save => "保存"
      }
    Auth(auth) =>
      match auth {
        Login => "登录"
      }
  }
}

///|
pub fn translate_for_locale(locale : Locale, text : I18nText) -> String {
  match locale {
    EnUS => translate_en_us(text)
    ZhCN => translate_zh_cn(text)
  }
}
