///|
pub struct I18n {
  fallback_locale_code : String
  schema_hash : String
  catalogs : Array[Catalog]
  formatter : Formatter
  diagnostics : Array[Diagnostic]
}

///|
pub(all) enum Diagnostic {
  MessageFallback(String, String, String)
  MissingMessage(String, String)
  MessageFormatFailed(String, String, String)
} derive(Eq, Debug)

///|
pub struct Translator {
  i18n : I18n
  locale_code : String
}

///|
pub fn I18n::new(
  fallback_locale_code~ : String,
  schema_hash? : String = "",
  formatter? : Formatter = Formatter::basic(),
) -> I18n {
  {
    fallback_locale_code: match normalize_locale_code(fallback_locale_code) {
      Ok(value) => value
      Err(_) => fallback_locale_code
    },
    schema_hash,
    catalogs: [],
    formatter,
    diagnostics: [],
  }
}

///|
pub fn I18n::fallback_locale_code(self : I18n) -> String {
  self.fallback_locale_code
}

///|
pub fn I18n::translator(_self : I18n, locale_code : String) -> Translator {
  {
    i18n: _self,
    locale_code: match normalize_locale_code(locale_code) {
      Ok(value) => value
      Err(_) => _self.fallback_locale_code
    },
  }
}

///|
pub fn I18n::translator_from_code(
  self : I18n,
  locale_code : String,
) -> Translator {
  let supported = self.catalogs.map(catalog => catalog.locale_code)
  self.translator(
    resolve_locale_code([locale_code], supported, self.fallback_locale_code),
  )
}

///|
pub fn Translator::locale_code(self : Translator) -> String {
  self.locale_code
}

///|
pub fn I18n::install_catalog(
  self : I18n,
  catalog : Catalog,
) -> Result[Unit, String] {
  if !self.schema_hash.is_empty() && catalog.schema_hash != self.schema_hash {
    return Err(
      "catalog schema hash mismatch for \{catalog.locale_code}: expected \{self.schema_hash}, got \{catalog.schema_hash}",
    )
  }
  for i = 0; i < self.catalogs.length(); i = i + 1 {
    if self.catalogs[i].locale_code == catalog.locale_code {
      self.catalogs[i] = catalog
      return Ok(())
    }
  }
  self.catalogs.push(catalog)
  Ok(())
}

///|
pub fn I18n::install_catalog_source(
  self : I18n,
  source : String,
) -> Result[Unit, String] {
  match parse_catalog(source) {
    Ok(catalog) => self.install_catalog(catalog)
    Err(message) => Err(message)
  }
}

///|
/// Parse and install a catalog only when its normalized locale matches the
/// locale requested by the caller.
pub fn I18n::install_catalog_source_for(
  self : I18n,
  expected_locale_code : String,
  source : String,
) -> Result[Unit, String] {
  let expected = match normalize_locale_code(expected_locale_code) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let catalog = match parse_catalog(source) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  if catalog.locale_code != expected {
    return Err(
      "catalog locale mismatch: expected \{expected}, got \{catalog.locale_code}",
    )
  }
  self.install_catalog(catalog)
}

///|
pub fn I18n::has_catalog(self : I18n, locale_code : String) -> Bool {
  let normalized = match normalize_locale_code(locale_code) {
    Ok(value) => value
    Err(_) => return false
  }
  self.find_catalog(normalized) is Some(_)
}

///|
pub fn I18n::catalog_locale_codes(self : I18n) -> Array[String] {
  self.catalogs.map(catalog => catalog.locale_code)
}

///|
pub fn I18n::take_diagnostics(self : I18n) -> Array[Diagnostic] {
  let diagnostics = self.diagnostics.copy()
  self.diagnostics.clear()
  diagnostics
}

///|
pub fn I18n::find_catalog(self : I18n, locale_code : String) -> Catalog? {
  for catalog in self.catalogs {
    if catalog.locale_code == locale_code {
      return Some(catalog)
    }
  }
  None
}

///|
pub fn Translator::translate(
  self : Translator,
  id : String,
  args : Array[MessageArg],
) -> String? {
  let chain = locale_lookup_chain(self.locale_code)
  let fallback_chain = locale_lookup_chain(self.i18n.fallback_locale_code)
  for code in fallback_chain {
    if !chain.contains(code) {
      chain.push(code)
    }
  }
  for code in chain {
    match self.i18n.find_catalog(code) {
      Some(catalog) =>
        match catalog.find(id) {
          Some(message) =>
            match
              format_mf2_message(
                message,
                self.locale_code,
                args,
                self.i18n.formatter,
              ) {
              Ok(value) => {
                if code != self.locale_code {
                  self.i18n.diagnostics.push(
                    MessageFallback(self.locale_code, code, id),
                  )
                }
                return Some(value)
              }
              Err(message) => {
                self.i18n.diagnostics.push(
                  MessageFormatFailed(code, id, message),
                )
                return None
              }
            }
          None => ()
        }
      None => ()
    }
  }
  self.i18n.diagnostics.push(MissingMessage(self.locale_code, id))
  None
}
