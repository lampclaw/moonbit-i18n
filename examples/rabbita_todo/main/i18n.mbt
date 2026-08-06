///|
pub struct I18n {
  runtime : @runtime.I18n
}

///|
pub struct Translator {
  runtime : @runtime.Translator
}

///|
pub fn I18n::new() -> I18n {
  let runtime = @runtime.I18n::new(
    fallback_locale_code=fallback_locale().code(),
    schema_hash=SCHEMA_HASH,
    formatter=@runtime_js.formatter(),
  )
  for catalog in embedded_catalogs() {
    match runtime.install_catalog(catalog) {
      Ok(_) => ()
      Err(message) => abort(message)
    }
  }
  { runtime, }
}

///|
pub fn I18n::fallback_locale(self : I18n) -> Locale {
  locale_from_code(self.runtime.fallback_locale_code(), fallback_locale())
}

///|
pub fn I18n::translator(self : I18n, locale : Locale) -> Translator {
  { runtime: self.runtime.translator(locale.code()) }
}

///|
pub fn I18n::translator_from_code(self : I18n, code : String) -> Translator {
  self.translator(locale_from_code(code, self.fallback_locale()))
}

///|
pub fn Translator::locale(self : Translator) -> Locale {
  locale_from_code(self.runtime.locale_code(), fallback_locale())
}

///|
pub fn Translator::t(self : Translator, text : I18nText) -> String {
  let id = message_id(text)
  match self.runtime.translate(id, message_args(text)) {
    Some(value) => value
    None => "[missing: \{id}]"
  }
}

///|
pub fn I18n::install_catalog_source(
  self : I18n,
  locale : Locale,
  source : String,
) -> Result[Unit, String] {
  self.runtime.install_catalog_source_for(locale.code(), source)
}
