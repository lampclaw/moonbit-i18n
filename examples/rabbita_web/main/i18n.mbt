///|
enum Locale {
  EnUS
  ZhCN
} derive(Eq, Debug)

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
  Counter(CounterText)
} derive(Eq)

///|
enum CommonText {
  CurrentLanguage
  SwitchLanguage
} derive(Eq)

///|
enum CounterText {
  Title
  Count(Int)
  Increment
  Decrement
} derive(Eq)

///|
fn message_id(text : I18nText) -> String {
  match text {
    Common(common) =>
      match common {
        CurrentLanguage => "common.current_language"
        SwitchLanguage => "common.switch_language"
      }
    Counter(counter) =>
      match counter {
        Title => "counter.title"
        Count(_) => "counter.count"
        Increment => "counter.increment"
        Decrement => "counter.decrement"
      }
  }
}

///|
fn message_args(text : I18nText) -> Array[@i18n.MessageArg] {
  match text {
    Counter(Count(count)) => [{ name: "count", value: @i18n.IntValue(count) }]
    _ => []
  }
}

///|
fn all_texts() -> Array[I18nText] {
  [
    Common(CurrentLanguage),
    Common(SwitchLanguage),
    Counter(Title),
    Counter(Count(0)),
    Counter(Increment),
    Counter(Decrement),
  ]
}

///|
fn message_for(locale : Locale, text : I18nText) -> String {
  match locale {
    EnUS =>
      match text {
        Common(common) =>
          match common {
            CurrentLanguage => "Current language"
            SwitchLanguage => "中文"
          }
        Counter(counter) =>
          match counter {
            Title => "Rabbita counter"
            Count(_) =>
              ".input {$count :number}\n.match $count\none {{One click}}\n* {{{$count} clicks}}"
            Increment => "Increase"
            Decrement => "Decrease"
          }
      }
    ZhCN =>
      match text {
        Common(common) =>
          match common {
            CurrentLanguage => "当前语言"
            SwitchLanguage => "English"
          }
        Counter(counter) =>
          match counter {
            Title => "Rabbita 计数器"
            Count(_) => "已点击 {$count :number} 次"
            Increment => "增加"
            Decrement => "减少"
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
    schema_hash="rabbita-counter-v1",
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
    schema_hash="rabbita-counter-v1",
    formatter=@i18n_js.formatter(),
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
  match self.runtime.translate(id, message_args(text)) {
    Some(message) => message
    None => "[missing: \{id}]"
  }
}
