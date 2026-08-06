///|
pub(all) struct Artifacts {
  code : String
  catalogs : Array[(String, String)]
  coverage_report : String
  schema_hash : String
} derive(Eq, Debug)

///|
pub fn generate(
  config_source : String,
  schema_source : String,
  sources : Array[LocaleSource],
  enforce_coverage? : Bool = true,
) -> Result[Artifacts, String] {
  let config = match parse_config(config_source) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let schema = match parse_schema(schema_source) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let hash = schema_hash(schema)
  let normalized_sources = match normalize_sources(sources) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  for source in normalized_sources {
    if find_locale_config(config.locales, source.code) is None {
      return Err("locale source is not declared in config: \{source.code}")
    }
  }
  let locales : Array[LocaleResource] = []
  for locale_config in config.locales {
    let source = match find_source(normalized_sources, locale_config.code) {
      Some(value) => value
      None => return Err("missing locale source: \{locale_config.code}")
    }
    match parse_locale(locale_config.code, source, schema) {
      Ok(locale) => locales.push(locale)
      Err(message) => return Err(message)
    }
  }
  let source_locale = match find_locale(locales, config.source_locale) {
    Some(value) => value
    None => return Err("source locale not found: \{config.source_locale}")
  }
  let fallback_locale = match find_locale(locales, config.fallback_locale) {
    Some(value) => value
    None => return Err("fallback locale not found: \{config.fallback_locale}")
  }
  match require_complete(schema, source_locale, "source") {
    Ok(_) => ()
    Err(message) => return Err(message)
  }
  match require_complete(schema, fallback_locale, "fallback") {
    Ok(_) => ()
    Err(message) => return Err(message)
  }
  let reports : Array[String] = []
  let catalogs : Array[(String, String)] = []
  for locale in locales {
    let coverage = coverage(schema, locale)
    reports.push(
      "\{locale.locale}: \{translated_count(locale)}/\{schema.entries.length()} (\{coverage_percent(coverage)}%)",
    )
    if enforce_coverage && coverage < config.minimum_coverage {
      return Err(
        "locale coverage below release minimum: \{locale.locale} is \{coverage_percent(coverage)}%, required \{coverage_percent(config.minimum_coverage)}%",
      )
    }
    let entries = locale.entries.map(entry => @runtime.CatalogEntry::{
      id: message_id(entry),
      message: entry.text,
    })
    let catalog = @runtime.Catalog::new(
      locale_code=locale.locale,
      schema_hash=hash,
      entries~,
      direction=locale_direction(config, locale.locale),
    )
    catalogs.push((locale.locale, catalog.to_json_string()))
  }
  Ok({
    code: generate_bindings(config, schema, locales, hash),
    catalogs,
    coverage_report: reports.join("\n"),
    schema_hash: hash,
  })
}

///|
fn normalize_sources(
  sources : Array[LocaleSource],
) -> Result[Array[LocaleSource], String] {
  let normalized : Array[LocaleSource] = []
  for source in sources {
    let code = match normalize_locale(source.code, "locale source") {
      Ok(value) => value
      Err(message) => return Err(message)
    }
    if find_source(normalized, code) is Some(_) {
      return Err("duplicate locale source: \{code}")
    }
    normalized.push({ code, source: source.source })
  }
  Ok(normalized)
}

///|
fn find_source(sources : Array[LocaleSource], code : String) -> String? {
  for source in sources {
    if source.code == code {
      return Some(source.source)
    }
  }
  None
}

///|
fn require_complete(
  schema : Schema,
  locale : LocaleResource,
  kind : String,
) -> Result[Unit, String] {
  let missing : Array[String] = []
  for entry in schema.entries {
    if find_entry(locale.entries, entry.group, entry.key) is None {
      missing.push(message_id(entry))
    }
  }
  if missing.is_empty() {
    Ok(())
  } else {
    Err("\{kind} locale is incomplete: \{locale.locale}: \{missing.join(", ")}")
  }
}

///|
fn coverage(schema : Schema, locale : LocaleResource) -> Double {
  if schema.entries.is_empty() {
    1.0
  } else {
    translated_count(locale).to_double() / schema.entries.length().to_double()
  }
}

///|
fn translated_count(locale : LocaleResource) -> Int {
  locale.entries.length()
}

///|
fn coverage_percent(value : Double) -> Int {
  (value * 100.0).to_int()
}

///|
fn schema_hash(schema : Schema) -> String {
  let canonical = StringBuilder::new()
  for entry in schema.entries {
    canonical.write_string(message_id(entry))
    canonical.write_char('(')
    for i = 0; i < entry.params.length(); i = i + 1 {
      if i > 0 {
        canonical.write_char(',')
      }
      canonical.write_string(entry.params[i].name)
      canonical.write_char(':')
      canonical.write_string(entry.params[i].typ)
    }
    canonical.write_string(")\n")
  }
  let fingerprint = canonical.to_string()
  let mut checksum = 17
  for char in fingerprint.to_array() {
    // Keep the intermediate value inside a 32-bit Int while retaining a
    // deterministic checksum for generated catalog compatibility checks.
    checksum = (checksum * 31 + char.to_int()) % 67000003
  }
  "v1-\{schema.entries.length()}-\{checksum}"
}
