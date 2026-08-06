///|
pub(all) struct CatalogEntry {
  id : String
  message : String
}

///|
pub struct Catalog {
  locale_code : String
  entries : Array[CatalogEntry]
}

///|
pub fn Catalog::new(
  locale_code~ : String,
  entries~ : Array[CatalogEntry],
) -> Catalog {
  { locale_code, entries }
}

///|
pub fn Catalog::locale_code(self : Catalog) -> String {
  self.locale_code
}

///|
fn Catalog::find(self : Catalog, id : String) -> String? {
  for entry in self.entries {
    if entry.id == id {
      return Some(entry.message)
    }
  }
  None
}

///|
pub struct I18n {
  fallback_locale_code : String
  catalogs : Array[Catalog]
}

///|
pub fn I18n::new(fallback_locale_code~ : String) -> I18n {
  { fallback_locale_code, catalogs: [] }
}

///|
pub fn I18n::fallback_locale_code(self : I18n) -> String {
  self.fallback_locale_code
}

///|
pub fn I18n::install_catalog(self : I18n, catalog : Catalog) -> Unit {
  for i = 0; i < self.catalogs.length(); i = i + 1 {
    if self.catalogs[i].locale_code == catalog.locale_code {
      self.catalogs[i] = catalog
      return ()
    }
  }
  self.catalogs.push(catalog)
}

///|
fn I18n::find_message(
  self : I18n,
  locale_code : String,
  id : String,
) -> String? {
  for catalog in self.catalogs {
    if catalog.locale_code == locale_code {
      return catalog.find(id)
    }
  }
  None
}

///|
pub struct Translator {
  i18n : I18n
  locale_code : String
}

///|
pub fn I18n::translator(self : I18n, locale_code : String) -> Translator {
  { i18n: self, locale_code }
}

///|
pub fn Translator::locale_code(self : Translator) -> String {
  self.locale_code
}

///|
pub fn Translator::translate(self : Translator, id : String) -> String? {
  match self.i18n.find_message(self.locale_code, id) {
    Some(message) => Some(message)
    None =>
      if self.locale_code == self.i18n.fallback_locale_code {
        None
      } else {
        self.i18n.find_message(self.i18n.fallback_locale_code, id)
      }
  }
}
