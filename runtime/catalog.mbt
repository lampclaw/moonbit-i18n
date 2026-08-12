///|
/// Catalog wire-format version accepted by this runtime.
pub const CATALOG_VERSION : Int = 2

///|
/// Formatter profile recorded in generated catalogs and contract hashes.
pub const CATALOG_PROFILE : String = "lampclaw-mf2-strict-v1+lampclaw-datetime-v1"

///|
/// Maximum UTF-8 size accepted for one serialized catalog.
pub const CATALOG_MAX_SOURCE_BYTES : Int = 16777216

///|
/// Maximum number of messages accepted in one catalog.
pub const CATALOG_MAX_MESSAGES : Int = 100000

///|
/// One identifier and MF2 message embedded in a generated catalog.
pub(all) struct CatalogEntry {
  /// Stable dotted message identifier.
  id : String
  /// MF2 source for the message.
  message : String
} derive(Eq, Debug)

///|
/// A validated locale catalog. Construct it from generated entries or JSON.
pub struct Catalog {
  catalog_version : Int
  profile : String
  contract_hash : String
  locale_code : String
  direction : String
  entries : Map[String, String]
  validation_error : String?
}

///|
/// Returns the normalized locale code stored by this catalog.
pub fn Catalog::locale_code(self : Catalog) -> String {
  self.locale_code
}

///|
/// Returns the catalog text direction, either `ltr` or `rtl`.
pub fn Catalog::direction(self : Catalog) -> String {
  self.direction
}

///|
/// Returns the SHA-256 contract hash required by the catalog.
pub fn Catalog::contract_hash(self : Catalog) -> String {
  self.contract_hash
}

///|
/// Returns the formatter profile declared by the catalog.
pub fn Catalog::profile(self : Catalog) -> String {
  self.profile
}

///|
/// Returns the catalog wire-format version.
pub fn Catalog::catalog_version(self : Catalog) -> Int {
  self.catalog_version
}

///|
/// Builds a catalog from code-generated entries without parsing JSON.
pub fn Catalog::from_generated_entries(
  locale_code~ : String,
  contract_hash~ : String,
  entries~ : Array[CatalogEntry],
  direction? : String = "ltr",
) -> Catalog {
  let (messages, validation_error) = generated_entries_map(
    entries,
    CATALOG_MAX_MESSAGES,
    CATALOG_MAX_SOURCE_BYTES,
  )
  {
    catalog_version: CATALOG_VERSION,
    profile: CATALOG_PROFILE,
    contract_hash,
    locale_code: match normalize_locale_code(locale_code) {
      Ok(value) => value
      Err(_) => locale_code
    },
    direction,
    entries: messages,
    validation_error,
  }
}

///|
fn generated_entries_map(
  entries : Array[CatalogEntry],
  max_messages : Int,
  max_data_bytes : Int,
) -> (Map[String, String], String?) {
  let messages : Map[String, String] = Map([])
  if entries.length() > max_messages {
    return (messages, Some("catalog exceeds the \{max_messages}-message limit"))
  }
  let mut data_bytes = 0
  for entry in entries {
    if entry.id.is_empty() {
      return (messages, Some("catalog message id must not be empty"))
    }
    if messages.contains(entry.id) {
      return (messages, Some("duplicate catalog message id: \{entry.id}"))
    }
    let message_bytes = @utf8.encode(entry.message).length()
    if message_bytes > MF2_MAX_MESSAGE_BYTES {
      return (messages, Some("catalog message exceeds size limit: \{entry.id}"))
    }
    let entry_bytes = @utf8.encode(entry.id).length() + message_bytes
    if entry_bytes > max_data_bytes || data_bytes > max_data_bytes - entry_bytes {
      return (
        messages,
        Some(
          "generated catalog exceeds the \{max_data_bytes}-byte aggregate UTF-8 data limit",
        ),
      )
    }
    data_bytes = data_bytes + entry_bytes
    messages[entry.id] = entry.message
  }
  (messages, None)
}

///|
/// Looks up raw MF2 source by stable message identifier.
pub fn Catalog::find(self : Catalog, id : String) -> String? {
  self.entries.get(id)
}

///|
/// Returns the number of messages in the catalog.
pub fn Catalog::message_count(self : Catalog) -> Int {
  self.entries.length()
}

///|
/// Calculates non-empty translation coverage for the requested identifiers.
pub fn Catalog::coverage(self : Catalog, message_ids : Array[String]) -> Double {
  if message_ids.is_empty() {
    return 1.0
  }
  let mut translated = 0
  for id in message_ids {
    match self.find(id) {
      Some(message) if !message.trim().is_empty() => translated = translated + 1
      _ => ()
    }
  }
  translated.to_double() / message_ids.length().to_double()
}

///|
/// Compiles and validates every MF2 message in this catalog.
pub fn Catalog::compile_messages(
  self : Catalog,
) -> Result[Map[String, CompiledMessage], String] {
  match self.validation_error {
    Some(message) => return Err(message)
    None => ()
  }
  if self.entries.length() > CATALOG_MAX_MESSAGES {
    return Err("catalog exceeds the \{CATALOG_MAX_MESSAGES}-message limit")
  }
  let compiled : Map[String, CompiledMessage] = Map([])
  for pair in self.entries.iter() {
    let (id, source) = pair
    if id.is_empty() {
      return Err("catalog message id must not be empty")
    }
    if @utf8.encode(source).length() > MF2_MAX_MESSAGE_BYTES {
      return Err("catalog message exceeds size limit: \{id}")
    }
    match compile_mf2_message(source, MessageContract::open()) {
      Ok(message) => compiled[id] = message
      Err(errors) =>
        return Err(
          "invalid MF2 message in catalog \{self.locale_code} at \{id}: \{errors[0].message}",
        )
    }
  }
  Ok(compiled)
}

///|
/// Parses a strict catalog-v2 JSON document without changing runtime state.
#warnings("-deprecated")
pub fn parse_catalog(source : String) -> Result[Catalog, String] {
  if @utf8.encode(source).length() > CATALOG_MAX_SOURCE_BYTES {
    return Err(
      "catalog exceeds the \{CATALOG_MAX_SOURCE_BYTES}-byte input limit",
    )
  }
  let json = try @json.parse(source, max_nesting_depth=64) catch {
    _ => return Err("invalid catalog JSON")
  } noraise {
    value => value
  }
  guard json is Object(obj) else {
    return Err("catalog root must be an object")
  }
  let version = match obj.get("catalogVersion") {
    Some(Number(value, ..)) if value == CATALOG_VERSION.to_double() =>
      CATALOG_VERSION
    Some(Number(value, ..)) =>
      return Err("unsupported catalogVersion: \{value}")
    _ => return Err("catalogVersion must be an integer")
  }
  let profile = match obj.get("profile") {
    Some(String(value)) if value == CATALOG_PROFILE => value
    Some(String(value)) => return Err("unsupported catalog profile: \{value}")
    _ => return Err("profile must be a string")
  }
  let contract_hash = match obj.get("contractHash") {
    Some(String(value)) if valid_contract_hash(value) => value
    Some(String(_)) =>
      return Err("contractHash must be a lowercase SHA-256 hex digest")
    _ => return Err("contractHash must be a string")
  }
  let locale_code = match obj.get("locale") {
    Some(String(value)) =>
      match normalize_locale_code(value) {
        Ok(normalized) => normalized
        Err(message) => return Err(message)
      }
    _ => return Err("locale must be a string")
  }
  let direction = match obj.get("direction") {
    Some(String("ltr")) => "ltr"
    Some(String("rtl")) => "rtl"
    Some(String(_)) => return Err("direction must be ltr or rtl")
    None => "ltr"
    _ => return Err("direction must be a string")
  }
  let entries : Map[String, String] = Map([])
  match obj.get("messages") {
    Some(Object(messages)) => {
      if messages.length() > CATALOG_MAX_MESSAGES {
        return Err("catalog exceeds the \{CATALOG_MAX_MESSAGES}-message limit")
      }
      for pair in messages.iter() {
        let (id, raw) = pair
        if id.is_empty() {
          return Err("catalog message id must not be empty")
        }
        match raw {
          String(message) => {
            if @utf8.encode(message).length() > MF2_MAX_MESSAGE_BYTES {
              return Err("catalog message exceeds size limit: \{id}")
            }
            entries[id] = message
          }
          _ => return Err("catalog message must be a string: \{id}")
        }
      }
    }
    _ => return Err("messages must be an object")
  }
  Ok({
    catalog_version: version,
    profile,
    contract_hash,
    locale_code,
    direction,
    entries,
    validation_error: None,
  })
}

///|
/// Serializes this catalog to deterministic catalog-v2 JSON.
pub fn Catalog::to_json_string(self : Catalog) -> String {
  let messages : Map[String, Json] = Map([])
  let sorted = self.entries.iter().collect()
  sorted.sort_by((left, right) => left.0.lexical_compare(right.0))
  for entry in sorted {
    messages[entry.0] = Json::string(entry.1)
  }
  Json::object({
    "catalogVersion": Json::number(self.catalog_version.to_double()),
    "profile": Json::string(self.profile),
    "contractHash": Json::string(self.contract_hash),
    "locale": Json::string(self.locale_code),
    "direction": Json::string(self.direction),
    "messages": Json::object(messages),
  }).stringify(indent=2)
}

///|
fn valid_contract_hash(value : String) -> Bool {
  if value.length() != 64 {
    return false
  }
  for char in value.to_array() {
    if !((char >= '0' && char <= '9') || (char >= 'a' && char <= 'f')) {
      return false
    }
  }
  true
}
