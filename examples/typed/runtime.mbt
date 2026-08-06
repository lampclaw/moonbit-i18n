///|
pub struct I18n {
  runtime : @i18n.I18n
}

///|
fn catalog_for_locale(locale : Locale) -> @i18n.Catalog {
  let entries : Array[@i18n.CatalogEntry] = all_texts().map(text => {
    id: message_id(text),
    message: translate_for_locale(locale, text),
  })
  @i18n.Catalog::new(locale_code=locale.code(), entries~)
}

///|
pub fn I18n::new(fallback_locale~ : Locale) -> I18n {
  let runtime = @i18n.I18n::new(fallback_locale_code=fallback_locale.code())
  runtime.install_catalog(catalog_for_locale(EnUS))
  runtime.install_catalog(catalog_for_locale(ZhCN))
  { runtime, }
}

///|
pub fn I18n::fallback_locale(self : I18n) -> Locale {
  locale_from_code(self.runtime.fallback_locale_code(), EnUS)
}

///|
pub fn I18n::translator(self : I18n, locale : Locale) -> @i18n.Translator {
  self.runtime.translator(locale.code())
}
