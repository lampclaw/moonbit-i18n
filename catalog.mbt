///|
pub(all) struct CatalogEntry {
  id : String
  message : String
}

///|
pub struct Catalog {
  catalog_version : Int
  schema_hash : String
  locale_code : String
  direction : String
  entries : Array[CatalogEntry]
}

///|
pub fn Catalog::locale_code(self : Catalog) -> String {
  self.locale_code
}

///|
pub fn Catalog::direction(self : Catalog) -> String {
  self.direction
}

///|
pub fn Catalog::schema_hash(self : Catalog) -> String {
  self.schema_hash
}

///|
pub fn Catalog::catalog_version(self : Catalog) -> Int {
  self.catalog_version
}

///|
pub fn Catalog::new(
  locale_code~ : String,
  schema_hash~ : String,
  entries~ : Array[CatalogEntry],
  direction? : String = "ltr",
) -> Catalog {
  {
    catalog_version: 1,
    schema_hash,
    locale_code: match normalize_locale_code(locale_code) {
      Ok(value) => value
      Err(_) => locale_code
    },
    direction,
    entries,
  }
}

///|
pub fn Catalog::find(self : Catalog, id : String) -> String? {
  for entry in self.entries {
    if entry.id == id {
      return Some(entry.message)
    }
  }
  None
}

///|
pub fn Catalog::coverage(self : Catalog, message_ids : Array[String]) -> Double {
  if message_ids.is_empty() {
    return 1.0
  }
  let mut translated = 0
  for id in message_ids {
    if self.find(id) is Some(_) {
      translated = translated + 1
    }
  }
  translated.to_double() / message_ids.length().to_double()
}

///|
pub fn parse_catalog(source : String) -> Result[Catalog, String] {
  let json = try @json.parse(source) catch {
    _ => return Err("invalid catalog JSON")
  } noraise {
    value => value
  }
  guard json is Object(obj) else {
    return Err("catalog root must be an object")
  }
  let version = match obj.get("catalogVersion") {
    Some(Number(value, ..)) => value.to_int()
    _ => return Err("catalogVersion must be a number")
  }
  if version != 1 {
    return Err("unsupported catalogVersion: \{version}")
  }
  let schema_hash = match obj.get("schemaHash") {
    Some(String(value)) => value
    _ => return Err("schemaHash must be a string")
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
  let entries : Array[CatalogEntry] = []
  match obj.get("messages") {
    Some(Object(messages)) =>
      for pair in messages.iter() {
        let (id, raw) = pair
        match raw {
          String(message) => entries.push({ id, message })
          _ => return Err("catalog message must be a string: \{id}")
        }
      }
    _ => return Err("messages must be an object")
  }
  entries.sort_by((left, right) => left.id.lexical_compare(right.id))
  Ok({ catalog_version: version, schema_hash, locale_code, direction, entries })
}

///|
pub fn Catalog::to_json_string(self : Catalog) -> String {
  let messages : Map[String, Json] = Map([])
  for entry in self.entries {
    messages[entry.id] = Json::string(entry.message)
  }
  Json::object({
    "catalogVersion": Json::number(self.catalog_version.to_double()),
    "schemaHash": Json::string(self.schema_hash),
    "locale": Json::string(self.locale_code),
    "direction": Json::string(self.direction),
    "messages": Json::object(messages),
  }).stringify(indent=2)
}
