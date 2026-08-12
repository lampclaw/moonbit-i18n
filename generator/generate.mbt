///|
/// Complete output of one deterministic generator run.
pub(all) struct Artifacts {
  /// Generated MoonBit facade source before formatting.
  code : String
  /// Generated `moon.pkg` contents for the facade package.
  package_manifest : String
  /// Locale codes paired with catalog-v2 JSON.
  catalogs : Array[(String, String)]
  /// Human-readable per-locale coverage report.
  coverage_report : String
  /// SHA-256 contract hash shared by the facade and catalogs.
  contract_hash : String
} derive(Eq, Debug)

///|
/// Parses, validates, and generates typed bindings plus deployment catalogs.
pub fn generate(
  config_source : String,
  schema_source : String,
  sources : Array[LocaleSource],
  enforce_coverage? : Bool = true,
) -> Result[Artifacts, String] {
  match
    validate_locale_source_budget(
      sources,
      I18N_MAX_LOCALES,
      I18N_MAX_TOTAL_LOCALE_BYTES,
    ) {
    Ok(_) => ()
    Err(message) => return Err(message)
  }
  let config = match parse_config(config_source) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let schema = match parse_schema(schema_source) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let hash = contract_hash(schema)
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
    let catalog = @runtime.Catalog::from_generated_entries(
      locale_code=locale.locale,
      contract_hash=hash,
      entries~,
      direction=locale_direction(config, locale.locale),
    )
    let catalog_source = catalog.to_json_string()
    match @runtime.parse_catalog(catalog_source) {
      Ok(_) => catalogs.push((locale.locale, catalog_source))
      Err(message) =>
        return Err("generated catalog is outside runtime limits: \{message}")
    }
  }
  let code = generate_bindings(config, schema, locales, hash)
  match validate_generated_code_budget(code, I18N_MAX_GENERATED_CODE_BYTES) {
    Ok(_) => ()
    Err(message) => return Err(message)
  }
  Ok({
    code,
    package_manifest: generated_package_manifest(),
    catalogs,
    coverage_report: reports.join("\n"),
    contract_hash: hash,
  })
}

///|
fn validate_locale_source_budget(
  sources : Array[LocaleSource],
  max_locales : Int,
  max_total_bytes : Int,
) -> Result[Unit, String] {
  if sources.length() > max_locales {
    return Err("locale sources exceed the \{max_locales}-locale limit")
  }
  let mut total_bytes = 0
  for source in sources {
    let source_bytes = @utf8.encode(source.source).length()
    if source_bytes > max_total_bytes ||
      total_bytes > max_total_bytes - source_bytes {
      return Err(
        "locale sources exceed the \{max_total_bytes}-byte aggregate UTF-8 limit",
      )
    }
    total_bytes = total_bytes + source_bytes
  }
  Ok(())
}

///|
fn validate_generated_code_budget(
  source : String,
  max_bytes : Int,
) -> Result[Unit, String] {
  if @utf8.encode(source).length() > max_bytes {
    Err("generated MoonBit source exceeds the \{max_bytes}-byte UTF-8 limit")
  } else {
    Ok(())
  }
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
fn contract_hash(schema : Schema) -> String {
  let canonical = StringBuilder::new()
  canonical.write_string(@runtime.CATALOG_PROFILE)
  canonical.write_char('\n')
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
    canonical.write_char(')')
    let tags = schema_allowed_tags(schema, message_id(entry))
    canonical.write_char('[')
    canonical.write_string(tags.join(","))
    canonical.write_string("]\n")
  }
  @crypto.bytes_to_hex_string(
    @crypto.sha256(@utf8.encode(canonical.to_string())),
  )
}
