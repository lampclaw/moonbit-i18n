///|
/// One immutable, independently deployable locale/namespace catalog chunk.
pub(all) struct CatalogChunkArtifact {
  /// Normalized locale code carried by the chunk.
  locale : String
  /// Canonical schema group used as the chunk namespace.
  chunk_namespace : String
  /// Portable relative filename referenced by the deployment manifest.
  path : String
  /// Exact UTF-8 catalog-v2 JSON bytes, including the final newline.
  source : String
  /// Lowercase SHA-256 of `source` for application-owned integrity checks.
  sha256 : String
  /// UTF-8 byte length of `source`.
  bytes : Int
  /// Number of translated messages carried by this chunk.
  message_count : Int
} derive(Eq, Debug)

///|
/// Complete output of one deterministic generator run.
pub(all) struct Artifacts {
  /// Generated MoonBit facade source before formatting.
  code : String
  /// Generated `moon.pkg` contents for the facade package.
  package_manifest : String
  /// Whole-locale catalog-v2 JSON retained for generator API compatibility.
  catalogs : Array[(String, String)]
  /// Independently deployable locale/namespace chunks.
  catalog_chunks : Array[CatalogChunkArtifact]
  /// Deterministic deployment manifest for `catalog_chunks`.
  deployment_manifest : String
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
  let catalog_chunks : Array[CatalogChunkArtifact] = []
  let schema_namespaces = groups(schema.entries)
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
    for chunk_namespace in schema_namespaces {
      let chunk_entries = entries_for(locale.entries, chunk_namespace).map(entry => @runtime.CatalogEntry::{
        id: message_id(entry),
        message: entry.text,
      })
      let chunk = @runtime.Catalog::from_generated_chunk_entries(
        locale_code=locale.locale,
        chunk_namespace~,
        contract_hash=hash,
        entries=chunk_entries,
        direction=locale_direction(config, locale.locale),
      )
      let chunk_source = chunk.to_json_string() + "\n"
      match @runtime.parse_catalog(chunk_source) {
        Ok(_) => ()
        Err(message) =>
          return Err(
            "generated catalog chunk is outside runtime limits: \{message}",
          )
      }
      catalog_chunks.push({
        locale: locale.locale,
        chunk_namespace,
        path: catalog_chunk_path(locale.locale, chunk_namespace),
        source: chunk_source,
        sha256: sha256_source(chunk_source),
        bytes: @utf8.encode(chunk_source).length(),
        message_count: chunk_entries.length(),
      })
    }
  }
  let deployment_manifest = deployment_manifest(
    config, schema_namespaces, catalog_chunks, hash,
  )
  let code = generate_bindings(config, schema, locales, hash, catalog_chunks~)
  match validate_generated_code_budget(code, I18N_MAX_GENERATED_CODE_BYTES) {
    Ok(_) => ()
    Err(message) => return Err(message)
  }
  Ok({
    code,
    package_manifest: generated_package_manifest(),
    catalogs,
    catalog_chunks,
    deployment_manifest,
    coverage_report: reports.join("\n"),
    contract_hash: hash,
  })
}

///|
fn catalog_chunk_path(locale : String, chunk_namespace : String) -> String {
  locale + "--" + chunk_namespace.replace_all(old=" ", new="_") + ".json"
}

///|
fn sha256_source(source : String) -> String {
  @crypto.bytes_to_hex_string(@crypto.sha256(@utf8.encode(source)))
}

///|
fn deployment_manifest(
  config : I18nConfig,
  schema_namespaces : Array[String],
  chunks : Array[CatalogChunkArtifact],
  hash : String,
) -> String {
  let namespace_values = schema_namespaces.map(value => Json::string(value))
  let embedded_values = config.embedded_locales.map(value => Json::string(value))
  let chunk_values : Array[Json] = []
  for chunk in chunks {
    chunk_values.push(
      Json::object({
        "locale": Json::string(chunk.locale),
        "namespace": Json::string(chunk.chunk_namespace),
        "path": Json::string(chunk.path),
        "sha256": Json::string(chunk.sha256),
        "bytes": Json::number(chunk.bytes.to_double()),
        "messageCount": Json::number(chunk.message_count.to_double()),
        "direction": Json::string(locale_direction(config, chunk.locale)),
        "embeddedLocale": Json::boolean(
          config.embedded_locales.contains(chunk.locale),
        ),
      }),
    )
  }
  Json::object({
    "manifestVersion": Json::number(1.0),
    "generator": Json::string("lampclaw/i18n"),
    "catalogVersion": Json::number(@runtime.CATALOG_VERSION.to_double()),
    "profile": Json::string(@runtime.CATALOG_PROFILE),
    "contractHash": Json::string(hash),
    "fallbackLocale": Json::string(config.fallback_locale),
    "embeddedLocales": Json::array(embedded_values),
    "namespaces": Json::array(namespace_values),
    "chunks": Json::array(chunk_values),
  }).stringify(indent=2) +
  "\n"
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
