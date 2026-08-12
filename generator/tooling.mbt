///|
const XLIFF_NAMESPACE : String = "urn:oasis:names:tc:xliff:document:2.0"

///|
const XLIFF_MAX_SOURCE_BYTES : Int = 67108864

///|
const XLIFF_MAX_UNITS : Int = 100000

///|
priv struct ImportedUnit {
  id : String
  target : String
}

///|
/// Exports schema-ordered translation units as namespace-aware XLIFF 2.1.
pub fn export_xliff(
  schema_source : String,
  source_locale_code : String,
  source_locale_source : String,
  target_locale_code : String,
  target_locale_source : String?,
) -> Result[String, String] {
  let schema = match parse_schema(schema_source) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let source_locale = match
    parse_locale(source_locale_code, source_locale_source, schema) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  match require_complete(schema, source_locale, "source") {
    Ok(_) => ()
    Err(message) => return Err(message)
  }
  let target_code = match
    normalize_locale(target_locale_code, "target locale") {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let target_locale = match target_locale_source {
    Some(source) =>
      match parse_locale(target_code, source, schema) {
        Ok(value) => Some(value)
        Err(message) => return Err(message)
      }
    None => None
  }
  let writer = @xml.Writer::new()
  let body = try {
    writer.start_element("xliff", [
      ("xmlns", XLIFF_NAMESPACE),
      ("version", "2.1"),
      ("srcLang", source_locale.locale),
      ("trgLang", target_code),
    ])
    writer.start_element("file", [("id", "messages")])
    for schema_entry in schema.entries {
      let id = message_id(schema_entry)
      let source_message = match
        find_entry(source_locale.entries, schema_entry.group, schema_entry.key) {
        Some(value) => value.text
        None => return Err("missing source message: \{id}")
      }
      let target_message = match target_locale {
        Some(locale) =>
          match
            find_entry(locale.entries, schema_entry.group, schema_entry.key) {
            Some(value) => value.text
            None => ""
          }
        None => ""
      }
      let state = if target_message.trim().is_empty() {
        "initial"
      } else {
        "translated"
      }
      writer.start_element("unit", [("id", id)])
      match schema_description(schema, id) {
        Some(description) => {
          writer.start_element("notes", [])
          writer.start_element("note", [])
          writer.text(description)
          writer.end_element("note")
          writer.end_element("notes")
        }
        None => ()
      }
      writer.start_element("segment", [])
      writer.start_element("source", [])
      writer.text(source_message)
      writer.end_element("source")
      writer.start_element("target", [("state", state)])
      writer.text(target_message)
      writer.end_element("target")
      writer.end_element("segment")
      writer.end_element("unit")
    }
    writer.end_element("file")
    writer.end_element("xliff")
    writer.to_string()
  } catch {
    _ => return Err("failed to serialize XLIFF")
  } noraise {
    value => value
  }
  let output = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n" + body + "\n"
  match validate_generated_xliff_budget(output, XLIFF_MAX_SOURCE_BYTES) {
    Ok(_) => Ok(output)
    Err(message) => Err(message)
  }
}

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
/// Imports validated XLIFF 2.1 targets into deterministic locale JSON.
pub fn import_xliff(
  schema_source : String,
  source_locale_code : String,
  source_locale_source : String,
  target_locale_code : String,
  xliff_source : String,
) -> Result[String, String] {
  if @utf8.encode(xliff_source).length() > XLIFF_MAX_SOURCE_BYTES {
    return Err("XLIFF exceeds the input size limit")
  }
  let schema = match parse_schema(schema_source) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let source_locale = match
    parse_locale(source_locale_code, source_locale_source, schema) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  match require_complete(schema, source_locale, "source") {
    Ok(_) => ()
    Err(message) => return Err(message)
  }
  let target_code = match
    normalize_locale(target_locale_code, "target locale") {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let units = match
    parse_xliff_units(
      xliff_source,
      source_locale.locale,
      target_code,
      schema,
      source_locale,
    ) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let translated : Array[(String, String)] = []
  for unit in units {
    if !unit.target.trim().is_empty() {
      translated.push((unit.id, unit.target))
    }
  }
  let resource = locale_json(schema, translated)
  match parse_locale(target_code, resource, schema) {
    Ok(_) => Ok(resource)
    Err(message) => Err(message)
  }
}

///|
fn parse_xliff_units(
  source : String,
  expected_source_locale : String,
  expected_target_locale : String,
  schema : Schema,
  source_locale : LocaleResource,
) -> Result[Array[ImportedUnit], String] {
  let reader = @xml.NamespaceReader::from_string(source)
  let units : Array[ImportedUnit] = []
  let seen_ids : Map[String, Bool] = Map([])
  let stack : Array[String] = []
  let content = StringBuilder::new()
  let mut capture = 0
  let mut root_seen = false
  let mut file_seen = false
  let mut current_id = ""
  let mut current_source = ""
  let mut current_target = ""
  let mut source_seen = false
  let mut target_seen = false
  while true {
    let event = try reader.read_event() catch {
      error => return Err("invalid XLIFF XML: \{error}")
    } noraise {
      value => value
    }
    match event.kind {
      @xml.Start(element) => {
        match validate_xliff_element(element) {
          Ok(_) => ()
          Err(message) => return Err(message)
        }
        let name = element.name.local_name
        if capture != 0 {
          return Err("XLIFF source and target must contain text-only MF2 data")
        }
        match name {
          "xliff" => {
            if root_seen || !stack.is_empty() {
              return Err("XLIFF must contain exactly one xliff root")
            }
            root_seen = true
            match require_xliff_attribute(element, "version") {
              Some("2.1") => ()
              Some(value) => return Err("unsupported XLIFF version: \{value}")
              None => return Err("XLIFF root is missing version")
            }
            let declared_source = match
              require_xliff_attribute(element, "srcLang") {
              Some(value) =>
                match normalize_locale(value, "XLIFF srcLang") {
                  Ok(code) => code
                  Err(message) => return Err(message)
                }
              None => return Err("XLIFF root is missing srcLang")
            }
            if declared_source != expected_source_locale {
              return Err(
                "XLIFF source locale mismatch: expected \{expected_source_locale}, got \{declared_source}",
              )
            }
            let declared_target = match
              require_xliff_attribute(element, "trgLang") {
              Some(value) =>
                match normalize_locale(value, "XLIFF trgLang") {
                  Ok(code) => code
                  Err(message) => return Err(message)
                }
              None => return Err("XLIFF root is missing trgLang")
            }
            if declared_target != expected_target_locale {
              return Err(
                "XLIFF target locale mismatch: expected \{expected_target_locale}, got \{declared_target}",
              )
            }
          }
          "file" => {
            if stack != ["xliff"] || file_seen {
              return Err("XLIFF profile requires one file under xliff")
            }
            if require_xliff_attribute(element, "id") is None {
              return Err("XLIFF file is missing id")
            }
            file_seen = true
          }
          "unit" => {
            if stack.is_empty() || stack[stack.length() - 1] != "file" {
              return Err("XLIFF unit must be a child of file")
            }
            if units.length() >= XLIFF_MAX_UNITS {
              return Err("XLIFF exceeds the translation-unit limit")
            }
            let id = match require_xliff_attribute(element, "id") {
              Some(value) => value
              None => return Err("XLIFF unit is missing id")
            }
            if find_entry_by_id(schema.entries, id) is None {
              return Err("unknown XLIFF unit id: \{id}")
            }
            if seen_ids.contains(id) {
              return Err("duplicate XLIFF unit id: \{id}")
            }
            seen_ids[id] = true
            current_id = id
            current_source = ""
            current_target = ""
            source_seen = false
            target_seen = false
          }
          "segment" =>
            if current_id.is_empty() ||
              stack.is_empty() ||
              stack[stack.length() - 1] != "unit" {
              return Err("XLIFF segment must be inside a unit")
            }
          "source" => {
            if current_id.is_empty() ||
              source_seen ||
              stack.is_empty() ||
              stack[stack.length() - 1] != "segment" {
              return Err("invalid or duplicate XLIFF source")
            }
            source_seen = true
            capture = 1
            content.reset()
          }
          "target" => {
            if current_id.is_empty() ||
              target_seen ||
              stack.is_empty() ||
              stack[stack.length() - 1] != "segment" {
              return Err("invalid or duplicate XLIFF target")
            }
            target_seen = true
            capture = 2
            content.reset()
          }
          "notes" =>
            if stack.is_empty() || stack[stack.length() - 1] != "unit" {
              return Err("XLIFF notes must be inside a unit")
            }
          "note" =>
            if stack.is_empty() || stack[stack.length() - 1] != "notes" {
              return Err("XLIFF note must be inside notes")
            }
          _ =>
            return Err(
              "element is outside the supported XLIFF profile: \{name}",
            )
        }
        stack.push(name)
      }
      @xml.Empty(element) => {
        match validate_xliff_element(element) {
          Ok(_) => ()
          Err(message) => return Err(message)
        }
        let name = element.name.local_name
        if name == "source" {
          if current_id.is_empty() ||
            source_seen ||
            stack.is_empty() ||
            stack[stack.length() - 1] != "segment" {
            return Err("invalid or duplicate XLIFF source")
          }
          source_seen = true
          current_source = ""
        } else if name == "target" {
          if current_id.is_empty() ||
            target_seen ||
            stack.is_empty() ||
            stack[stack.length() - 1] != "segment" {
            return Err("invalid or duplicate XLIFF target")
          }
          target_seen = true
          current_target = ""
        } else {
          return Err(
            "empty element is outside the supported XLIFF profile: \{name}",
          )
        }
      }
      @xml.End(name) => {
        match name.local_name {
          "source" => {
            current_source = content.to_string()
            content.reset()
            capture = 0
          }
          "target" => {
            current_target = content.to_string()
            content.reset()
            capture = 0
          }
          "unit" => {
            if !source_seen {
              return Err("XLIFF unit is missing source: \{current_id}")
            }
            if !target_seen {
              return Err("XLIFF unit is missing target: \{current_id}")
            }
            let expected = match source_message(source_locale, current_id) {
              Some(value) => value
              None => return Err("missing source message: \{current_id}")
            }
            if current_source != expected {
              return Err("stale XLIFF source for unit: \{current_id}")
            }
            units.push({ id: current_id, target: current_target })
            current_id = ""
          }
          _ => ()
        }
        ignore(stack.pop())
      }
      @xml.Text(value) | @xml.CData(value) =>
        if capture != 0 {
          content.write_string(value)
        } else if !value.trim().is_empty() &&
          (stack.is_empty() || stack[stack.length() - 1] != "note") {
          return Err("text is outside an XLIFF source, target, or note")
        }
      @xml.DocType(_) => return Err("DOCTYPE is not allowed in XLIFF")
      @xml.Eof => break
      @xml.Comment(_) | @xml.PI(..) | @xml.Decl(..) => ()
    }
  }
  if !root_seen || !file_seen {
    return Err("XLIFF document is missing the required root or file")
  }
  if units.is_empty() {
    return Err("XLIFF contains no translation units")
  }
  Ok(units)
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
/// Produces an `en-XA` or `ar-XB` pseudo-locale while preserving MF2 syntax.
pub fn pseudo_locale(
  schema_source : String,
  source_locale_code : String,
  source_locale_source : String,
  mode : String,
) -> Result[String, String] {
  if mode != "en-XA" && mode != "ar-XB" {
    return Err("pseudo locale must be en-XA or ar-XB")
  }
  let schema = match parse_schema(schema_source) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let locale = match
    parse_locale(source_locale_code, source_locale_source, schema) {
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
  match parse_locale(mode, resource, schema) {
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
