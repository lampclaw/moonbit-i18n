///|
const XLIFF_NAMESPACE : String = "urn:oasis:names:tc:xliff:document:2.0"

///|
const XLIFF_MAX_SOURCE_BYTES : Int = 67108864

///|
const XLIFF_MAX_UNITS : Int = 100000

///|
fn validate_generated_xliff_budget(
  source : String,
  max_bytes : Int,
) -> Result[Unit, String] {
  if @utf8.encode(source).length() > max_bytes {
    Err("generated XLIFF exceeds the \{max_bytes}-byte UTF-8 limit")
  } else {
    Ok(())
  }
}

///|
fn validate_xliff_element(
  element : @xml.NamespaceElement,
) -> Result[Unit, String] {
  if element.name.namespace_uri != Some(XLIFF_NAMESPACE) {
    Err(
      "unexpected XML namespace for XLIFF element: \{element.name.qualified_name}",
    )
  } else {
    Ok(())
  }
}

///|
fn require_xliff_attribute(
  element : @xml.NamespaceElement,
  name : String,
) -> String? {
  for attribute in element.attributes {
    if attribute.name.namespace_uri is None && attribute.name.local_name == name {
      return Some(attribute.value)
    }
  }
  None
}

///|
fn source_message(locale : LocaleResource, id : String) -> String? {
  match find_entry_by_id(locale.entries, id) {
    Some(entry) => Some(entry.text)
    None => None
  }
}

///|
/// Produces an `en-XA` or `ar-XB` pseudo-locale while preserving the selected
/// MF2 message profile.
pub fn pseudo_locale(
  schema_source : String,
  source_locale_code : String,
  source_locale_source : String,
  mode : String,
  message_profile? : String = @runtime.CATALOG_PROFILE,
) -> Result[String, String] {
  if mode != "en-XA" && mode != "ar-XB" {
    return Err("pseudo locale must be en-XA or ar-XB")
  }
  let schema = match parse_schema(schema_source) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let locale = match
    parse_locale(
      source_locale_code,
      source_locale_source,
      schema,
      message_profile~,
    ) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  match require_complete(schema, locale, "source") {
    Ok(_) => ()
    Err(message) => return Err(message)
  }
  let messages : Array[(String, String)] = []
  for entry in locale.entries {
    messages.push((message_id(entry), pseudo_message(entry.text, mode)))
  }
  let resource = locale_json(schema, messages)
  match parse_locale(mode, resource, schema, message_profile~) {
    Ok(_) => Ok(resource)
    Err(message) => Err("generated pseudo locale is invalid: \{message}")
  }
}

///|
fn locale_json(schema : Schema, translated : Array[(String, String)]) -> String {
  let root : Map[String, Json] = Map([])
  let translated_map : Map[String, String] = Map([])
  for pair in translated {
    translated_map[pair.0] = pair.1
  }
  for group in groups(schema.entries) {
    let items : Map[String, Json] = Map([])
    for entry in entries_for(schema.entries, group) {
      match translated_map.get(message_id(entry)) {
        Some(value) => items[entry.key] = Json::string(value)
        None => ()
      }
    }
    if !items.is_empty() {
      root[group] = Json::object(items)
    }
  }
  Json::object(root).stringify(indent=2)
}

///|
fn pseudo_message(source : String, mode : String) -> String {
  let trimmed = source.trim()
  if trimmed.has_prefix(".input") ||
    trimmed.has_prefix(".local") ||
    trimmed.has_prefix(".match") ||
    trimmed.has_prefix("{{") {
    pseudo_complex_message(source, mode)
  } else {
    wrap_pseudo(pseudo_pattern(source), mode)
  }
}

///|
fn pseudo_complex_message(source : String, mode : String) -> String {
  let chars = source.to_array()
  let out = StringBuilder::new()
  let mut cursor = 0
  while cursor < chars.length() {
    let open = match find_double_open(chars, cursor) {
      Some(value) => value
      None => {
        write_char_range(out, chars, cursor, chars.length())
        break
      }
    }
    write_char_range(out, chars, cursor, open + 2)
    let pattern_start = open + 2
    let close = match find_quoted_pattern_close(chars, pattern_start) {
      Some(value) => value
      None => {
        write_char_range(out, chars, pattern_start, chars.length())
        break
      }
    }
    let pattern = chars_to_string(chars, pattern_start, close)
    out.write_string(wrap_pseudo(pseudo_pattern(pattern), mode))
    out.write_string("}}")
    cursor = close + 2
  }
  out.to_string()
}

///|
fn find_double_open(chars : Array[Char], start : Int) -> Int? {
  let mut cursor = start
  while cursor + 1 < chars.length() {
    if chars[cursor] == '{' && chars[cursor + 1] == '{' {
      return Some(cursor)
    }
    cursor = cursor + 1
  }
  None
}

///|
fn find_quoted_pattern_close(chars : Array[Char], start : Int) -> Int? {
  let mut cursor = start
  while cursor < chars.length() {
    if chars[cursor] == '\\' {
      cursor = cursor + 2
    } else if chars[cursor] == '{' {
      let end = find_expression_close(chars, cursor)
      match end {
        Some(value) => cursor = value + 1
        None => return None
      }
    } else if chars[cursor] == '}' &&
      cursor + 1 < chars.length() &&
      chars[cursor + 1] == '}' {
      return Some(cursor)
    } else {
      cursor = cursor + 1
    }
  }
  None
}

///|
fn find_expression_close(chars : Array[Char], start : Int) -> Int? {
  let mut quoted = false
  let mut cursor = start + 1
  while cursor < chars.length() {
    if chars[cursor] == '\\' {
      cursor = cursor + 2
    } else if chars[cursor] == '|' {
      quoted = !quoted
      cursor = cursor + 1
    } else if chars[cursor] == '}' && !quoted {
      return Some(cursor)
    } else {
      cursor = cursor + 1
    }
  }
  None
}

///|
fn write_char_range(
  out : StringBuilder,
  chars : Array[Char],
  start : Int,
  end : Int,
) -> Unit {
  for i = start; i < end; i = i + 1 {
    out.write_char(chars[i])
  }
}

///|
fn chars_to_string(chars : Array[Char], start : Int, end : Int) -> String {
  let out : Array[Char] = []
  for i = start; i < end; i = i + 1 {
    out.push(chars[i])
  }
  String::from_array(out)
}

///|
fn wrap_pseudo(source : String, mode : String) -> String {
  if mode == "ar-XB" {
    "\u{202e}\{source}\u{202c}"
  } else {
    "[\{source} !!!]"
  }
}

///|
fn pseudo_pattern(source : String) -> String {
  let chars = source.to_array()
  let out = StringBuilder::new()
  let mut cursor = 0
  while cursor < chars.length() {
    if chars[cursor] == '\\' && cursor + 1 < chars.length() {
      out.write_char(chars[cursor])
      out.write_char(chars[cursor + 1])
      cursor = cursor + 2
    } else if chars[cursor] == '{' {
      match find_expression_close(chars, cursor) {
        Some(close) => {
          write_char_range(out, chars, cursor, close + 1)
          cursor = close + 1
        }
        None => {
          out.write_char(chars[cursor])
          cursor = cursor + 1
        }
      }
    } else {
      out.write_char(pseudo_char(chars[cursor]))
      cursor = cursor + 1
    }
  }
  out.to_string()
}

///|
fn pseudo_char(char : Char) -> Char {
  match char {
    'a' => 'á'
    'e' => 'ë'
    'i' => 'ï'
    'o' => 'õ'
    'u' => 'ü'
    'A' => 'Á'
    'E' => 'Ë'
    'I' => 'Ï'
    'O' => 'Õ'
    'U' => 'Ü'
    _ => char
  }
}

///|
fn schema_description(schema : Schema, id : String) -> String? {
  let mut low = 0
  let mut high = schema.descriptions.length()
  while low < high {
    let middle = low + (high - low) / 2
    if schema.descriptions[middle].0.lexical_compare(id) < 0 {
      low = middle + 1
    } else {
      high = middle
    }
  }
  if low < schema.descriptions.length() && schema.descriptions[low].0 == id {
    Some(schema.descriptions[low].1)
  } else {
    None
  }
}
