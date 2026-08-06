///|
enum Locale {
  EnUS
  ZhCN
} derive(Eq)

///|
fn Locale::code(self : Locale) -> String {
  match self {
    EnUS => "en-US"
    ZhCN => "zh-CN"
  }
}

///|
fn Locale::other(self : Locale) -> Locale {
  match self {
    EnUS => ZhCN
    ZhCN => EnUS
  }
}

///|
enum I18nText {
  Common(CommonText)
  Web(WebText)
} derive(Eq)

///|
enum CommonText {
  Hello
} derive(Eq)

///|
enum WebText {
  Description
  CurrentLanguage
  SwitchLanguage
} derive(Eq)

///|
fn message_id(text : I18nText) -> String {
  match text {
    Common(common) =>
      match common {
        Hello => "common.hello"
      }
    Web(web) =>
      match web {
        Description => "web.description"
        CurrentLanguage => "web.current_language"
        SwitchLanguage => "web.switch_language"
      }
  }
}

///|
fn all_texts() -> Array[I18nText] {
  [Common(Hello), Web(Description), Web(CurrentLanguage), Web(SwitchLanguage)]
}

///|
fn message_for(locale : Locale, text : I18nText) -> String {
  match locale {
    EnUS =>
      match text {
        Common(common) =>
          match common {
            Hello => "Hello"
          }
        Web(web) =>
          match web {
            Description => "Typed internationalization for a Rabbita Web app."
            CurrentLanguage => "Current language"
            SwitchLanguage => "Switch language"
          }
      }
    ZhCN =>
      match text {
        Common(common) =>
          match common {
            Hello => "你好"
          }
        Web(web) =>
          match web {
            Description => "Rabbita Web 应用的类型安全国际化示例。"
            CurrentLanguage => "当前语言"
            SwitchLanguage => "切换语言"
          }
      }
  }
}

///|
fn catalog_for(locale : Locale) -> @i18n.Catalog {
  let entries : Array[@i18n.CatalogEntry] = all_texts().map(text => {
    id: message_id(text),
    message: message_for(locale, text),
  })
  @i18n.Catalog::new(
    locale_code=locale.code(),
    schema_hash="rabbita-example-v1",
    entries~,
  )
}

///|
struct AppI18n {
  runtime : @i18n.I18n
}

///|
fn AppI18n::new() -> AppI18n {
  let runtime = @i18n.I18n::new(
    fallback_locale_code=EnUS.code(),
    schema_hash="rabbita-example-v1",
  )
  guard runtime.install_catalog(catalog_for(EnUS)) is Ok(_) else {
    abort("failed to install en-US catalog")
  }
  guard runtime.install_catalog(catalog_for(ZhCN)) is Ok(_) else {
    abort("failed to install zh-CN catalog")
  }
  { runtime, }
}

///|
struct Translator {
  runtime : @i18n.Translator
}

///|
fn AppI18n::translator(self : AppI18n, locale : Locale) -> Translator {
  { runtime: self.runtime.translator(locale.code()) }
}

///|
fn Translator::t(self : Translator, text : I18nText) -> String {
  let id = message_id(text)
  match self.runtime.translate(id, []) {
    Some(message) => message
    None => "[missing: \{id}]"
  }
}
