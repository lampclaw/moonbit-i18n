///|
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
  let out = StringBuilder::new()
  out.write_string("<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n")
  out.write_string(
    "<xliff xmlns=\"urn:oasis:names:tc:xliff:document:2.0\" version=\"2.1\" srcLang=\"\{xml_escape(source_locale.locale)}\" trgLang=\"\{xml_escape(target_code)}\">\n",
  )
  out.write_string("  <file id=\"messages\">\n")
  for schema_entry in schema.entries {
    let id = message_id(schema_entry)
    let source_message = match
      find_entry(source_locale.entries, schema_entry.group, schema_entry.key) {
      Some(value) => value.text
      None => return Err("missing source message: \{id}")
    }
    let target_message = match target_locale {
      Some(locale) =>
        match find_entry(locale.entries, schema_entry.group, schema_entry.key) {
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
    out.write_string("    <unit id=\"\{xml_escape(id)}\">")
    match schema_description(schema, id) {
      Some(description) =>
        out.write_string(
          "<notes><note>\{xml_escape(description)}</note></notes>",
        )
      None => ()
    }
    out.write_string("<segment><source>\{xml_escape(source_message)}</source>")
    out.write_string(
      "<target state=\"\{state}\">\{xml_escape(target_message)}</target></segment></unit>\n",
    )
  }
  out.write_string("  </file>\n</xliff>\n")
  Ok(out.to_string())
}

///|
pub fn import_xliff(
  schema_source : String,
  target_locale_code : String,
  xliff_source : String,
) -> Result[String, String] {
  let schema = match parse_schema(schema_source) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let target_code = match
    normalize_locale(target_locale_code, "target locale") {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  match xml_attribute(xliff_source, "trgLang") {
    Some(raw_code) => {
      let declared = match
        normalize_locale(xml_unescape(raw_code), "XLIFF trgLang") {
        Ok(value) => value
        Err(message) => return Err(message)
      }
      if declared != target_code {
        return Err(
          "XLIFF target locale mismatch: expected \{target_code}, got \{declared}",
        )
      }
    }
    None => ()
  }
  let translated : Array[(String, String)] = []
  let seen_ids : Array[String] = []
  let mut found_unit = false
  for raw_unit in xliff_source.split("<unit ") {
    let chunk = raw_unit.to_owned()
    if !chunk.contains("</unit>") {
      continue
    }
    found_unit = true
    let unit = "<unit " + chunk
    let id = match xml_attribute(unit, "id") {
      Some(value) => xml_unescape(value)
      None => return Err("XLIFF unit is missing id")
    }
    if find_entry_by_id(schema.entries, id) is None {
      return Err("unknown XLIFF unit id: \{id}")
    }
    if seen_ids.contains(id) {
      return Err("duplicate XLIFF unit id: \{id}")
    }
    seen_ids.push(id)
    let target = match xml_element(unit, "target") {
      Some(value) => xml_unescape(value)
      None => return Err("XLIFF unit is missing target: \{id}")
    }
    if !target.is_empty() {
      translated.push((id, target))
    }
  }
  if !found_unit {
    return Err("XLIFF contains no translation units")
  }
  let resource = locale_json(schema, translated)
  match parse_locale(target_code, resource, schema) {
    Ok(_) => Ok(resource)
    Err(message) => Err(message)
  }
}

///|
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
  for group in groups(schema.entries) {
    let items : Map[String, Json] = Map([])
    for entry in entries_for(schema.entries, group) {
      match translated_value(translated, message_id(entry)) {
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
  if !source.trim().has_prefix(".") {
    return wrap_pseudo(pseudo_pattern(source), mode)
  }
  let out = StringBuilder::new()
  let lines : Array[String] = source
    .split("\n")
    .map(line => line.to_owned())
    .collect()
  for i = 0; i < lines.length(); i = i + 1 {
    if i > 0 {
      out.write_char('\n')
    }
    out.write_string(pseudo_selector_line(lines[i], mode))
  }
  out.to_string()
}

///|
fn pseudo_selector_line(source : String, mode : String) -> String {
  let trimmed = source.trim()
  if trimmed.has_prefix(".input ") ||
    trimmed.has_prefix(".local ") ||
    trimmed.has_prefix(".match ") {
    return source
  }
  match source.find("{{") {
    Some(start) => {
      let after_open = source[start + 2:].to_owned()
      match after_open.find("}}") {
        Some(end) =>
          source[:start].to_owned() +
          "{{" +
          wrap_pseudo(pseudo_pattern(after_open[:end].to_owned()), mode) +
          "}}" +
          after_open[end + 2:].to_owned()
        None => pseudo_pattern(source)
      }
    }
    None => pseudo_pattern(source)
  }
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
  let out = StringBuilder::new()
  let mut expression_depth = 0
  for char in source.to_array() {
    if char == '{' {
      expression_depth = expression_depth + 1
      out.write_char(char)
    } else if char == '}' {
      expression_depth = expression_depth - 1
      out.write_char(char)
    } else if expression_depth > 0 {
      out.write_char(char)
    } else {
      out.write_char(pseudo_char(char))
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
  for pair in schema.descriptions {
    if pair.0 == id {
      return Some(pair.1)
    }
  }
  None
}

///|
fn translated_value(values : Array[(String, String)], id : String) -> String? {
  for pair in values {
    if pair.0 == id {
      return Some(pair.1)
    }
  }
  None
}

///|
fn xml_escape(value : String) -> String {
  value
  .replace_all(old="&", new="&amp;")
  .replace_all(old="<", new="&lt;")
  .replace_all(old=">", new="&gt;")
  .replace_all(old="\"", new="&quot;")
  .replace_all(old="'", new="&apos;")
  .replace_all(old="\n", new="&#10;")
}

///|
fn xml_unescape(value : String) -> String {
  value
  .replace_all(old="&#10;", new="\n")
  .replace_all(old="&apos;", new="'")
  .replace_all(old="&quot;", new="\"")
  .replace_all(old="&gt;", new=">")
  .replace_all(old="&lt;", new="<")
  .replace_all(old="&amp;", new="&")
}

///|
fn xml_attribute(line : String, name : String) -> String? {
  let double_prefix = "\{name}=\""
  match line.find(double_prefix) {
    Some(start) => {
      let remain = line[start + double_prefix.length():].to_owned()
      match remain.find("\"") {
        Some(end) => Some(remain[:end].to_owned())
        None => None
      }
    }
    None => {
      let single_prefix = "\{name}='"
      match line.find(single_prefix) {
        Some(start) => {
          let remain = line[start + single_prefix.length():].to_owned()
          match remain.find("'") {
            Some(end) => Some(remain[:end].to_owned())
            None => None
          }
        }
        None => None
      }
    }
  }
}

///|
fn xml_element(line : String, name : String) -> String? {
  let open = match line.find("<\{name}") {
    Some(value) => value
    None => return None
  }
  let after_open = line[open:].to_owned()
  let body_start = match after_open.find(">") {
    Some(value) => open + value + 1
    None => return None
  }
  let close = "</\{name}>"
  let remain = line[body_start:].to_owned()
  match remain.find(close) {
    Some(end) => Some(remain[:end].to_owned())
    None => None
  }
}
