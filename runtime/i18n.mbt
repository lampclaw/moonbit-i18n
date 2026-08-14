///|
/// Kind of non-fatal translation diagnostic recorded by the runtime.
pub(all) enum DiagnosticKind {
  /// The requested locale missed and a fallback catalog supplied the message.
  MessageFallbackDiagnostic
  /// No requested or fallback catalog contained the message.
  MissingMessageDiagnostic
  /// A catalog message was found but formatting failed.
  MessageFormatFailedDiagnostic
} derive(Eq, Debug)

///|
/// Deduplicated translation diagnostic returned to application telemetry.
pub(all) struct Diagnostic {
  /// Diagnostic category.
  kind : DiagnosticKind
  /// Locale requested by the translator.
  requested_locale : String
  /// Locale that supplied the message, or an empty string when none did.
  used_locale : String
  /// Stable dotted message identifier.
  message_id : String
  /// Human-readable failure detail.
  detail : String
  /// Number of equivalent occurrences coalesced into this entry.
  occurrences : Int
} derive(Eq, Debug)

///|
/// Diagnostics drained from an `I18n` instance in one operation.
pub(all) struct DiagnosticBatch {
  /// Recorded, deduplicated entries.
  entries : Array[Diagnostic]
  /// Number of new diagnostic keys dropped after reaching capacity.
  dropped : Int
} derive(Eq, Debug)

///|
/// Stable category for a strict translation failure.
pub(all) enum TranslationErrorKind {
  /// Neither the requested nor fallback catalog contained the message.
  TranslationMissing
  /// A message was found but could not be formatted.
  TranslationFormattingFailed
} derive(Eq, Debug)

///|
/// Structured error returned by strict translation methods.
pub(all) struct TranslationError {
  /// High-level failure category.
  kind : TranslationErrorKind
  /// Locale requested by the translator.
  requested_locale : String
  /// Stable dotted message identifier.
  message_id : String
  /// MF2 validation or formatting errors, when applicable.
  format_errors : Array[Mf2Error]
} derive(Eq, Debug)

///|
/// Mutable catalog registry, compiled-message cache, formatter, and diagnostics.
pub struct I18n {
  fallback_locale_code : String
  contract_hash : String
  profile : String
  /// Whole-locale catalogs retained for catalog-v2 compatibility.
  catalogs : Map[String, Catalog]
  /// Namespace chunks keyed by normalized locale and namespace.
  catalog_chunks : Map[String, Catalog]
  /// Effective per-locale messages after whole catalogs and chunks are merged.
  compiled_catalogs : Map[String, Map[String, CompiledMessage]]
  formatter : Formatter
  diagnostics : Array[Diagnostic]
  diagnostic_capacity : Int
  mut diagnostic_dropped : Int
}

///|
/// Locale-bound view over an `I18n` registry.
pub struct Translator {
  i18n : I18n
  locale_code : String
}

///|
/// Creates an empty registry with a fallback locale and formatter contract.
pub fn I18n::new(
  fallback_locale_code~ : String,
  contract_hash? : String = "",
  profile? : String = CATALOG_PROFILE,
  formatter? : Formatter = Formatter::basic(),
  diagnostic_capacity? : Int = 256,
) -> I18n {
  {
    fallback_locale_code: match normalize_locale_code(fallback_locale_code) {
      Ok(value) => value
      Err(_) => fallback_locale_code
    },
    contract_hash,
    profile,
    catalogs: Map([]),
    catalog_chunks: Map([]),
    compiled_catalogs: Map([]),
    formatter,
    diagnostics: [],
    diagnostic_capacity: if diagnostic_capacity < 0 {
      0
    } else {
      diagnostic_capacity
    },
    diagnostic_dropped: 0,
  }
}

///|
/// Returns the normalized fallback locale code.
pub fn I18n::fallback_locale_code(self : I18n) -> String {
  self.fallback_locale_code
}

///|
/// Returns the contract hash required of dynamically installed catalogs.
pub fn I18n::contract_hash(self : I18n) -> String {
  self.contract_hash
}

///|
/// Creates a translator for a locale, falling back on invalid locale syntax.
pub fn I18n::translator(self : I18n, locale_code : String) -> Translator {
  {
    i18n: self,
    locale_code: match normalize_locale_code(locale_code) {
      Ok(value) => value
      Err(_) => self.fallback_locale_code
    },
  }
}

///|
/// Negotiates one requested locale against currently installed catalogs.
pub fn I18n::translator_from_code(
  self : I18n,
  locale_code : String,
) -> Translator {
  let supported : Array[String] = self.catalogs.keys().collect()
  self.translator(
    resolve_locale_code([locale_code], supported, self.fallback_locale_code),
  )
}

///|
/// Returns the locale code bound to this translator.
pub fn Translator::locale_code(self : Translator) -> String {
  self.locale_code
}

///|
/// Validates, compiles, and atomically installs an in-memory catalog.
pub fn I18n::install_generated_catalog(
  self : I18n,
  catalog : Catalog,
) -> Result[Unit, String] {
  if catalog.catalog_version != CATALOG_VERSION {
    return Err(
      "unsupported catalogVersion: \{catalog.catalog_version.to_double()}",
    )
  }
  if catalog.profile != self.profile {
    return Err(
      "catalog profile mismatch for \{catalog.locale_code}: expected \{self.profile}, got \{catalog.profile}",
    )
  }
  if !valid_contract_hash(catalog.contract_hash) {
    return Err(
      "invalid catalog contract hash for \{catalog.locale_code}: expected a lowercase SHA-256 hex digest",
    )
  }
  let normalized_locale = match normalize_locale_code(catalog.locale_code) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  if normalized_locale != catalog.locale_code {
    return Err(
      "catalog locale must be normalized: expected \{normalized_locale}, got \{catalog.locale_code}",
    )
  }
  if !(catalog.direction == "ltr" || catalog.direction == "rtl") {
    return Err("direction must be ltr or rtl")
  }
  if !self.contract_hash.is_empty() &&
    catalog.contract_hash != self.contract_hash {
    return Err(
      "catalog contract hash mismatch for \{catalog.locale_code}: expected \{self.contract_hash}, got \{catalog.contract_hash}",
    )
  }
  // Compilation is deliberately completed before either map is mutated so a
  // malformed replacement cannot partially overwrite a working locale.
  let compiled = match catalog.compile_messages() {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let merged = self.merged_catalog_for_install(catalog, compiled)
  match catalog.chunk_namespace {
    Some(chunk_namespace) =>
      self.catalog_chunks[chunk_catalog_key(
        catalog.locale_code,
        chunk_namespace,
      )] = catalog
    None => self.catalogs[catalog.locale_code] = catalog
  }
  self.compiled_catalogs[catalog.locale_code] = merged
  Ok(())
}

///|
fn chunk_catalog_key(locale_code : String, chunk_namespace : String) -> String {
  locale_code + "\n" + chunk_namespace
}

///|
fn merge_compiled_messages(
  destination : Map[String, CompiledMessage],
  source : Map[String, CompiledMessage],
) -> Unit {
  for pair in source.iter() {
    destination[pair.0] = pair.1
  }
}

///|
fn I18n::merged_catalog_for_install(
  self : I18n,
  candidate : Catalog,
  candidate_compiled : Map[String, CompiledMessage],
) -> Map[String, CompiledMessage] {
  let merged : Map[String, CompiledMessage] = Map([])
  match candidate.chunk_namespace {
    Some(candidate_namespace) => {
      match self.catalogs.get(candidate.locale_code) {
        Some(base) =>
          match base.compile_messages() {
            Ok(compiled) => merge_compiled_messages(merged, compiled)
            Err(_) => ()
          }
        None => ()
      }
      let candidate_key = chunk_catalog_key(
        candidate.locale_code,
        candidate_namespace,
      )
      for pair in self.catalog_chunks.iter() {
        if pair.0 != candidate_key &&
          pair.1.locale_code == candidate.locale_code {
          match pair.1.compile_messages() {
            Ok(compiled) => merge_compiled_messages(merged, compiled)
            Err(_) => ()
          }
        }
      }
      merge_compiled_messages(merged, candidate_compiled)
    }
    None => {
      merge_compiled_messages(merged, candidate_compiled)
      for pair in self.catalog_chunks.iter() {
        if pair.1.locale_code == candidate.locale_code {
          match pair.1.compile_messages() {
            Ok(compiled) => merge_compiled_messages(merged, compiled)
            Err(_) => ()
          }
        }
      }
    }
  }
  merged
}

///|
/// Parses and installs catalog JSON using the locale declared by the catalog.
pub fn I18n::install_catalog_source(
  self : I18n,
  source : String,
) -> Result[Unit, String] {
  match parse_catalog(source) {
    Ok(catalog) => self.install_generated_catalog(catalog)
    Err(message) => Err(message)
  }
}

///|
/// Parses and installs catalog JSON only when it declares the expected locale.
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
  self.install_generated_catalog(catalog)
}

///|
/// Parses and atomically installs one catalog chunk only when its locale and
/// namespace match the expected deployment-manifest entry.
pub fn I18n::install_catalog_chunk_source_for(
  self : I18n,
  expected_locale_code : String,
  expected_namespace : String,
  source : String,
) -> Result[Unit, String] {
  let expected_locale = match normalize_locale_code(expected_locale_code) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let catalog = match parse_catalog(source) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  if catalog.locale_code != expected_locale {
    return Err(
      "catalog locale mismatch: expected \{expected_locale}, got \{catalog.locale_code}",
    )
  }
  match catalog.chunk_namespace {
    Some(value) if value == expected_namespace => ()
    Some(value) =>
      return Err(
        "catalog namespace mismatch: expected \{expected_namespace}, got \{value}",
      )
    None =>
      return Err("catalog namespace is missing: expected \{expected_namespace}")
  }
  self.install_generated_catalog(catalog)
}

///|
/// Returns whether a normalized locale catalog is currently installed.
pub fn I18n::has_catalog(self : I18n, locale_code : String) -> Bool {
  let normalized = match normalize_locale_code(locale_code) {
    Ok(value) => value
    Err(_) => return false
  }
  if self.catalogs.contains(normalized) {
    return true
  }
  for pair in self.catalog_chunks.iter() {
    if pair.1.locale_code == normalized {
      return true
    }
  }
  false
}

///|
/// Returns whether a whole-locale catalog is installed, excluding namespace
/// chunks.
pub fn I18n::has_whole_catalog(self : I18n, locale_code : String) -> Bool {
  match normalize_locale_code(locale_code) {
    Ok(value) => self.catalogs.contains(value)
    Err(_) => false
  }
}

///|
/// Returns whether data for one namespace is installed for a locale.
pub fn I18n::has_catalog_namespace(
  self : I18n,
  locale_code : String,
  expected_namespace : String,
) -> Bool {
  let normalized = match normalize_locale_code(locale_code) {
    Ok(value) => value
    Err(_) => return false
  }
  if self.catalog_chunks.contains(
      chunk_catalog_key(normalized, expected_namespace),
    ) {
    return true
  }
  match self.catalogs.get(normalized) {
    Some(catalog) => {
      let prefix = expected_namespace + "."
      for pair in catalog.entries.iter() {
        if pair.0.has_prefix(prefix) {
          return true
        }
      }
      false
    }
    None => false
  }
}

///|
/// Returns whether every requested namespace is installed for a locale.
pub fn I18n::has_catalog_namespaces(
  self : I18n,
  locale_code : String,
  expected_namespaces : Array[String],
) -> Bool {
  for expected_namespace in expected_namespaces {
    if !self.has_catalog_namespace(locale_code, expected_namespace) {
      return false
    }
  }
  true
}

///|
/// Returns installed namespaces for one locale in deterministic lexical
/// order.
pub fn I18n::catalog_namespaces(
  self : I18n,
  locale_code : String,
) -> Array[String] {
  let normalized = match normalize_locale_code(locale_code) {
    Ok(value) => value
    Err(_) => return []
  }
  let result : Array[String] = []
  let seen : Map[String, Bool] = Map([])
  match self.catalogs.get(normalized) {
    Some(catalog) =>
      for pair in catalog.entries.iter() {
        let pieces : Array[String] = pair.0
          .split(".")
          .map(piece => piece.to_owned())
          .collect()
        if !pieces.is_empty() && !seen.contains(pieces[0]) {
          seen[pieces[0]] = true
          result.push(pieces[0])
        }
      }
    None => ()
  }
  for pair in self.catalog_chunks.iter() {
    if pair.1.locale_code == normalized {
      match pair.1.chunk_namespace {
        Some(value) if !seen.contains(value) => {
          seen[value] = true
          result.push(value)
        }
        _ => ()
      }
    }
  }
  result.sort_by((left, right) => left.lexical_compare(right))
  result
}

///|
/// Returns installed locale codes in deterministic lexical order.
pub fn I18n::catalog_locale_codes(self : I18n) -> Array[String] {
  let result : Array[String] = self.catalogs.keys().collect()
  for pair in self.catalog_chunks.iter() {
    if !result.contains(pair.1.locale_code) {
      result.push(pair.1.locale_code)
    }
  }
  result.sort_by((left, right) => left.lexical_compare(right))
  result
}

///|
/// Drains all recorded diagnostics and resets the dropped-entry count.
pub fn I18n::take_diagnostics(self : I18n) -> DiagnosticBatch {
  let batch = {
    entries: self.diagnostics.copy(),
    dropped: self.diagnostic_dropped,
  }
  self.diagnostics.clear()
  self.diagnostic_dropped = 0
  batch
}

///|
/// Returns the catalog selected for a locale, including fallback lookup.
pub fn I18n::find_catalog(self : I18n, locale_code : String) -> Catalog? {
  match normalize_locale_code(locale_code) {
    Ok(value) => self.catalogs.get(value)
    Err(_) => None
  }
}

///|
/// Returns an installed namespace chunk without applying locale fallback.
pub fn I18n::find_catalog_chunk(
  self : I18n,
  locale_code : String,
  expected_namespace : String,
) -> Catalog? {
  match normalize_locale_code(locale_code) {
    Ok(value) =>
      self.catalog_chunks.get(chunk_catalog_key(value, expected_namespace))
    Err(_) => None
  }
}

///|
/// Strictly translates one message to text and returns structured failures.
pub fn Translator::try_t(
  self : Translator,
  id : String,
  args : Array[MessageArg],
) -> Result[String, TranslationError] {
  let format_errors : Array[Mf2Error] = []
  for code in self.lookup_chain() {
    match self.i18n.compiled_catalogs.get(code) {
      Some(messages) =>
        match messages.get(id) {
          Some(compiled) =>
            match
              format_text(compiled, self.locale_code, args, self.i18n.formatter) {
              Ok(value) => {
                if code != self.locale_code {
                  self.i18n.record_diagnostic(
                    MessageFallbackDiagnostic,
                    self.locale_code,
                    code,
                    id,
                    "",
                  )
                }
                return Ok(value)
              }
              Err(error) => {
                format_errors.push(error)
                self.i18n.record_diagnostic(
                  MessageFormatFailedDiagnostic,
                  self.locale_code,
                  code,
                  id,
                  error.message,
                )
              }
            }
          None => ()
        }
      None => ()
    }
  }
  if format_errors.is_empty() {
    self.i18n.record_diagnostic(
      MissingMessageDiagnostic,
      self.locale_code,
      "",
      id,
      "",
    )
    Err({
      kind: TranslationMissing,
      requested_locale: self.locale_code,
      message_id: id,
      format_errors,
    })
  } else {
    Err({
      kind: TranslationFormattingFailed,
      requested_locale: self.locale_code,
      message_id: id,
      format_errors,
    })
  }
}

///|
/// Translates one message to text, returning the message ID on failure.
pub fn Translator::t(
  self : Translator,
  id : String,
  args : Array[MessageArg],
) -> String {
  match self.try_t(id, args) {
    Ok(value) => value
    Err(_) => id
  }
}

///|
/// Strictly translates one message to text and markup parts.
pub fn Translator::try_t_parts(
  self : Translator,
  id : String,
  args : Array[MessageArg],
) -> Result[Array[MessagePart], TranslationError] {
  let format_errors : Array[Mf2Error] = []
  for code in self.lookup_chain() {
    match self.i18n.compiled_catalogs.get(code) {
      Some(messages) =>
        match messages.get(id) {
          Some(compiled) =>
            match
              format_parts(
                compiled,
                self.locale_code,
                args,
                self.i18n.formatter,
              ) {
              Ok(value) => {
                if code != self.locale_code {
                  self.i18n.record_diagnostic(
                    MessageFallbackDiagnostic,
                    self.locale_code,
                    code,
                    id,
                    "",
                  )
                }
                return Ok(value)
              }
              Err(error) => {
                format_errors.push(error)
                self.i18n.record_diagnostic(
                  MessageFormatFailedDiagnostic,
                  self.locale_code,
                  code,
                  id,
                  error.message,
                )
              }
            }
          None => ()
        }
      None => ()
    }
  }
  if format_errors.is_empty() {
    self.i18n.record_diagnostic(
      MissingMessageDiagnostic,
      self.locale_code,
      "",
      id,
      "",
    )
    Err({
      kind: TranslationMissing,
      requested_locale: self.locale_code,
      message_id: id,
      format_errors,
    })
  } else {
    Err({
      kind: TranslationFormattingFailed,
      requested_locale: self.locale_code,
      message_id: id,
      format_errors,
    })
  }
}

///|
/// Translates one message to parts, returning the message ID as text on failure.
pub fn Translator::t_parts(
  self : Translator,
  id : String,
  args : Array[MessageArg],
) -> Array[MessagePart] {
  match self.try_t_parts(id, args) {
    Ok(value) => value
    Err(_) => [Text(id)]
  }
}

///|
/// Returns a translated string when available, otherwise `None`.
pub fn Translator::translate_raw(
  self : Translator,
  id : String,
  args : Array[MessageArg],
) -> String? {
  match self.try_t(id, args) {
    Ok(value) => Some(value)
    Err(_) => None
  }
}

///|
fn Translator::lookup_chain(self : Translator) -> Array[String] {
  let chain = locale_lookup_chain(self.locale_code)
  let fallback_chain = locale_lookup_chain(self.i18n.fallback_locale_code)
  for code in fallback_chain {
    if !chain.contains(code) {
      chain.push(code)
    }
  }
  chain
}

///|
fn I18n::record_diagnostic(
  self : I18n,
  kind : DiagnosticKind,
  requested_locale : String,
  used_locale : String,
  message_id : String,
  detail : String,
) -> Unit {
  for i = 0; i < self.diagnostics.length(); i = i + 1 {
    let existing = self.diagnostics[i]
    if existing.kind == kind &&
      existing.requested_locale == requested_locale &&
      existing.used_locale == used_locale &&
      existing.message_id == message_id &&
      existing.detail == detail {
      self.diagnostics[i] = {
        ..existing,
        occurrences: existing.occurrences + 1,
      }
      return
    }
  }
  if self.diagnostics.length() >= self.diagnostic_capacity {
    self.diagnostic_dropped = self.diagnostic_dropped + 1
    return
  }
  self.diagnostics.push({
    kind,
    requested_locale,
    used_locale,
    message_id,
    detail,
    occurrences: 1,
  })
}
