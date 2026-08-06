///|
pub fn parse_config(source : String) -> Result[I18nConfig, String] {
  let json = try @json.parse(source) catch {
    _ => return Err("invalid i18n config JSON")
  } noraise {
    value => value
  }
  guard json is Object(obj) else {
    return Err("i18n config root must be an object")
  }
  let source_locale = match normalized_config_string(obj, "sourceLocale") {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let default_locale = match normalized_config_string(obj, "defaultLocale") {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let fallback_locale = match normalized_config_string(obj, "fallbackLocale") {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let embedded_locales : Array[String] = []
  match obj.get("embeddedLocales") {
    Some(Array(values)) =>
      for value in values {
        guard value is String(code) else {
          return Err("embeddedLocales must contain strings")
        }
        let normalized = match normalize_locale(code, "embeddedLocales") {
          Ok(value) => value
          Err(message) => return Err(message)
        }
        if embedded_locales.contains(normalized) {
          return Err("duplicate embedded locale: \{normalized}")
        }
        embedded_locales.push(normalized)
      }
    _ => return Err("embeddedLocales must be an array")
  }
  let locales : Array[LocaleConfig] = []
  match obj.get("locales") {
    Some(Object(values)) =>
      for pair in values.iter() {
        let (raw_code, raw_metadata) = pair
        let code = match normalize_locale(raw_code, "locales") {
          Ok(value) => value
          Err(message) => return Err(message)
        }
        if find_locale_config(locales, code) is Some(_) {
          return Err("duplicate normalized locale: \{code}")
        }
        guard raw_metadata is Object(metadata) else {
          return Err("locale metadata must be an object: \{raw_code}")
        }
        let direction = match metadata.get("direction") {
          Some(String("rtl")) => "rtl"
          Some(String("ltr")) | None => "ltr"
          _ => return Err("locale direction must be ltr or rtl: \{raw_code}")
        }
        locales.push({ code, direction })
      }
    _ => return Err("locales must be an object")
  }
  if locales.is_empty() {
    return Err("locales must contain at least one locale")
  }
  locales.sort_by((left, right) => left.code.lexical_compare(right.code))
  match validate_locale_identifier_collisions(locales) {
    Ok(_) => ()
    Err(message) => return Err(message)
  }
  for
    pair in [
      ("sourceLocale", source_locale),
      ("defaultLocale", default_locale),
      ("fallbackLocale", fallback_locale),
    ] {
    if find_locale_config(locales, pair.1) is None {
      return Err("\{pair.0} is not declared in locales: \{pair.1}")
    }
  }
  for code in embedded_locales {
    if find_locale_config(locales, code) is None {
      return Err("embedded locale is not declared in locales: \{code}")
    }
  }
  let minimum_coverage = match obj.get("release") {
    Some(Object(release)) =>
      match release.get("minimumCoverage") {
        Some(Number(value, ..)) => value
        None => 1.0
        _ => return Err("release.minimumCoverage must be a number")
      }
    None => 1.0
    _ => return Err("release must be an object")
  }
  if minimum_coverage < 0.0 || minimum_coverage > 1.0 {
    return Err("release.minimumCoverage must be between 0 and 1")
  }
  Ok({
    source_locale,
    default_locale,
    fallback_locale,
    embedded_locales,
    locales,
    minimum_coverage,
  })
}

///|
pub fn parse_schema(source : String) -> Result[Schema, String] {
  let json = try @json.parse(source) catch {
    _ => return Err("invalid i18n schema JSON")
  } noraise {
    value => value
  }
  guard json is Object(obj) else {
    return Err("i18n schema root must be an object")
  }
  let param_map = match obj.get("params") {
    Some(Object(value)) => value
    None => {}
    _ => return Err("schema params must be an object")
  }
  let entries : Array[Entry] = []
  match obj.get("messages") {
    Some(Object(group_map)) =>
      for pair in group_map.iter() {
        let (group, raw_keys) = pair
        match validate_resource_name("schema", "group", group) {
          Ok(_) => ()
          Err(message) => return Err(message)
        }
        guard raw_keys is Array(keys) else {
          return Err("schema message group must be an array: \{group}")
        }
        for raw_key in keys {
          guard raw_key is String(key) else {
            return Err("schema message key must be a string: \{group}")
          }
          match validate_resource_name("schema", "key", key) {
            Ok(_) => ()
            Err(message) => return Err(message)
          }
          if find_entry(entries, group, key) is Some(_) {
            return Err("duplicate schema message: \{group}.\{key}")
          }
          let id = "\{group}.\{key}"
          let params = match param_map.get(id) {
            Some(Array(values)) =>
              match parse_schema_params(id, values) {
                Ok(value) => value
                Err(message) => return Err(message)
              }
            None => []
            _ => return Err("schema params must be an array: \{id}")
          }
          entries.push({ group, key, text: "", params })
        }
      }
    _ => return Err("schema messages must be an object")
  }
  if entries.is_empty() {
    return Err("schema messages must contain at least one message")
  }
  match validate_identifier_collisions(entries) {
    Ok(_) => ()
    Err(message) => return Err(message)
  }
  for pair in param_map.iter() {
    if find_entry_by_id(entries, pair.0) is None {
      return Err("schema params reference unknown message: \{pair.0}")
    }
  }
  entries.sort_by((left, right) => {
    message_id(left).lexical_compare(message_id(right))
  })
  let descriptions : Array[(String, String)] = []
  match obj.get("descriptions") {
    Some(Object(values)) =>
      for pair in values.iter() {
        let (id, raw) = pair
        if find_entry_by_id(entries, id) is None {
          return Err("schema description references unknown message: \{id}")
        }
        match raw {
          String(value) => descriptions.push((id, value))
          _ => return Err("schema description must be a string: \{id}")
        }
      }
    None => ()
    _ => return Err("schema descriptions must be an object")
  }
  descriptions.sort_by((left, right) => left.0.lexical_compare(right.0))
  Ok({ entries, descriptions })
}

///|
pub fn parse_locale(
  locale_code : String,
  source : String,
  schema : Schema,
) -> Result[LocaleResource, String] {
  let locale = match normalize_locale(locale_code, "locale") {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let json = try @json.parse(source) catch {
    _ => return Err("invalid JSON in \{locale}")
  } noraise {
    value => value
  }
  guard json is Object(groups) else {
    return Err("locale root must be an object: \{locale}")
  }
  let entries : Array[Entry] = []
  for pair in groups.iter() {
    let (group, raw_group) = pair
    if !schema.entries.any(entry => entry.group == group) {
      return Err("unknown message group in \{locale}: \{group}")
    }
    guard raw_group is Object(items) else {
      return Err("group must be an object: \{locale}.\{group}")
    }
    for item in items.iter() {
      let (key, raw) = item
      let schema_entry = match find_entry(schema.entries, group, key) {
        Some(value) => value
        None => return Err("unknown message in \{locale}: \{group}.\{key}")
      }
      let text = match raw {
        String(value) => value
        Object(obj) =>
          match obj.get("text") {
            Some(String(value)) => value
            _ => return Err("missing text: \{locale}.\{group}.\{key}")
          }
        _ =>
          return Err(
            "entry must be a string or object: \{locale}.\{group}.\{key}",
          )
      }
      let args = schema_entry.params.map(param => @runtime.MessageArg::{
        name: param.name,
        value: dummy_value(param.typ),
      })
      match @runtime.validate_mf2_message_with_args(text, args) {
        Ok(_) => entries.push({ ..schema_entry, text, })
        Err(message) =>
          return Err(
            "invalid MF2 message: \{locale}.\{group}.\{key}: \{message}",
          )
      }
    }
  }
  entries.sort_by((left, right) => {
    message_id(left).lexical_compare(message_id(right))
  })
  Ok({ locale, entries })
}

///|
fn parse_schema_params(
  id : String,
  values : Array[Json],
) -> Result[Array[Param], String] {
  let params : Array[Param] = []
  for value in values {
    guard value is Object(obj) else {
      return Err("schema param must be an object: \{id}")
    }
    let name = match obj.get("name") {
      Some(String(value)) => value
      _ => return Err("schema param name must be a string: \{id}")
    }
    match validate_param_name(id, name) {
      Ok(_) => ()
      Err(message) => return Err(message)
    }
    if params.any(param => param.name == name) {
      return Err("duplicate schema param: \{id}.\{name}")
    }
    let typ = match obj.get("type") {
      Some(String(value)) => value
      _ => return Err("schema param type must be a string: \{id}.\{name}")
    }
    if !(typ == "String" ||
      typ == "Int" ||
      typ == "Double" ||
      typ == "Bool" ||
      typ == "DateTime") {
      return Err("unsupported schema param type: \{id}.\{name} uses \{typ}")
    }
    params.push({ name, typ })
  }
  Ok(params)
}

///|
fn normalized_config_string(
  obj : Map[String, Json],
  key : String,
) -> Result[String, String] {
  match obj.get(key) {
    Some(String(value)) => normalize_locale(value, key)
    _ => Err("\{key} must be a string")
  }
}

///|
fn normalize_locale(code : String, field : String) -> Result[String, String] {
  match @runtime.normalize_locale_code(code) {
    Ok(value) if starts_with_ascii_letter(value) => Ok(value)
    Ok(_) =>
      Err(
        "invalid locale in \{field}: locale code must start with an ASCII letter",
      )
    Err(message) => Err("invalid locale in \{field}: \{message}")
  }
}

///|
fn find_locale_config(
  locales : Array[LocaleConfig],
  code : String,
) -> LocaleConfig? {
  for locale in locales {
    if locale.code == code {
      return Some(locale)
    }
  }
  None
}

///|
fn find_entry(entries : Array[Entry], group : String, key : String) -> Entry? {
  for entry in entries {
    if entry.group == group && entry.key == key {
      return Some(entry)
    }
  }
  None
}

///|
fn find_entry_by_id(entries : Array[Entry], id : String) -> Entry? {
  for entry in entries {
    if message_id(entry) == id {
      return Some(entry)
    }
  }
  None
}

///|
fn message_id(entry : Entry) -> String {
  "\{entry.group}.\{entry.key}"
}

///|
fn dummy_value(typ : String) -> @runtime.MessageValue {
  match typ {
    "String" => @runtime.TextValue("value")
    "Int" => @runtime.IntValue(1)
    "Double" => @runtime.DoubleValue(1.0)
    "Bool" => @runtime.BoolValue(true)
    "DateTime" => @runtime.DateTimeValue("2024-01-01T00:00:00Z")
    _ => @runtime.TextValue("value")
  }
}
