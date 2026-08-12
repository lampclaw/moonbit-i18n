///|
fn validate_resource_name(
  scope : String,
  kind : String,
  name : String,
) -> Result[Unit, String] {
  if name.is_empty() {
    return Err("\{kind} name must not be empty: \{scope}")
  }
  if !starts_with_ascii_letter(name) {
    return Err("\{kind} name must start with an ASCII letter: \{scope}.\{name}")
  }
  for char in name.to_array() {
    if !(is_ascii_letter(char) ||
      is_ascii_digit(char) ||
      char == '_' ||
      char == '-' ||
      char == ' ') {
      return Err(
        "\{kind} name must contain only ASCII letters, digits, '_', '-' or spaces: \{scope}.\{name}",
      )
    }
  }
  Ok(())
}

///|
fn validate_param_name(id : String, name : String) -> Result[Unit, String] {
  let chars = name.to_array()
  if name == "_" {
    return Err("param name must not be the MoonBit wildcard: \{id}._")
  }
  if chars.is_empty() || !(is_lower_ascii(chars[0]) || chars[0] == '_') {
    return Err("param name must be a lower ASCII identifier: \{id}.\{name}")
  }
  for char in chars {
    if !(is_lower_ascii(char) || is_ascii_digit(char) || char == '_') {
      return Err("param name must be a lower ASCII identifier: \{id}.\{name}")
    }
  }
  if is_moonbit_keyword(name) {
    return Err("param name must not be a MoonBit keyword: \{id}.\{name}")
  }
  Ok(())
}

///|
fn validate_identifier_collisions(
  entries : Array[Entry],
) -> Result[Unit, String] {
  let errors : Array[String] = []
  let group_names = groups(entries)
  let generated_groups : Map[String, String] = Map([])
  for group in group_names {
    let generated = pascal(group)
    if generated == "I18n" {
      errors.push("group generates the reserved I18nText type name: \{group}")
    }
    if generated == "Self" {
      errors.push("group generates the reserved Self variant: \{group}")
    }
    match generated_groups.get(generated) {
      Some(previous) =>
        errors.push(
          "groups generate the same enum variant: \{previous} and \{group} -> \{generated}",
        )
      None => generated_groups[generated] = group
    }
  }
  for group in group_names {
    let group_entries = entries_for(entries, group)
    let generated_keys : Map[String, String] = Map([])
    for entry in group_entries {
      let generated = pascal(entry.key)
      if generated == "Self" {
        errors.push(
          "key generates the reserved Self variant in \{group}: \{entry.key}",
        )
      }
      match generated_keys.get(generated) {
        Some(previous) =>
          errors.push(
            "keys generate the same enum variant in \{group}: \{previous} and \{entry.key} -> \{generated}",
          )
        None => generated_keys[generated] = entry.key
      }
    }
  }
  if errors.is_empty() {
    Ok(())
  } else {
    Err(errors.join("\n"))
  }
}

///|
fn validate_locale_identifier_collisions(
  locales : Array[LocaleConfig],
) -> Result[Unit, String] {
  let errors : Array[String] = []
  let generated_locales : Map[String, String] = Map([])
  for locale in locales {
    let generated = locale_variant(locale.code)
    if generated == "Self" {
      errors.push(
        "locale code generates the reserved Self variant: \{locale.code}",
      )
    }
    match generated_locales.get(generated) {
      Some(previous) =>
        errors.push(
          "locale codes generate the same enum variant: \{previous} and \{locale.code} -> \{generated}",
        )
      None => generated_locales[generated] = locale.code
    }
  }
  if errors.is_empty() {
    Ok(())
  } else {
    Err(errors.join("\n"))
  }
}

///|
fn groups(entries : Array[Entry]) -> Array[String] {
  let result : Array[String] = []
  let seen : Map[String, Bool] = Map([])
  for entry in entries {
    if !seen.contains(entry.group) {
      seen[entry.group] = true
      result.push(entry.group)
    }
  }
  result.sort_by((left, right) => left.lexical_compare(right))
  result
}

///|
fn entries_for(entries : Array[Entry], group : String) -> Array[Entry] {
  let result : Array[Entry] = []
  let lower_bound = group + "."
  let mut low = 0
  let mut high = entries.length()
  while low < high {
    let middle = low + (high - low) / 2
    if message_id(entries[middle]).lexical_compare(lower_bound) < 0 {
      low = middle + 1
    } else {
      high = middle
    }
  }
  let mut cursor = low
  while cursor < entries.length() && entries[cursor].group == group {
    result.push(entries[cursor])
    cursor = cursor + 1
  }
  result
}

///|
fn pascal(name : String) -> String {
  let out = StringBuilder::new()
  let mut upper_next = true
  for char in name.to_array() {
    if char == '-' || char == '_' || char == ' ' {
      upper_next = true
    } else if upper_next {
      out.write_char(to_upper_ascii(char))
      upper_next = false
    } else {
      out.write_char(char)
    }
  }
  out.to_string()
}

///|
fn locale_variant(code : String) -> String {
  pascal(code)
}

///|
fn starts_with_ascii_letter(value : String) -> Bool {
  let chars = value.to_array()
  !chars.is_empty() && is_ascii_letter(chars[0])
}

///|
fn is_moonbit_keyword(value : String) -> Bool {
  match value {
    "as"
    | "async"
    | "await"
    | "break"
    | "catch"
    | "const"
    | "continue"
    | "derive"
    | "else"
    | "enum"
    | "extern"
    | "false"
    | "fn"
    | "for"
    | "guard"
    | "if"
    | "impl"
    | "in"
    | "let"
    | "loop"
    | "match"
    | "mut"
    | "noraise"
    | "pub"
    | "raise"
    | "return"
    | "struct"
    | "test"
    | "trait"
    | "true"
    | "try"
    | "type"
    | "while"
    | "with" => true
    _ => false
  }
}

///|
fn is_ascii_letter(char : Char) -> Bool {
  match char {
    'a'..='z' | 'A'..='Z' => true
    _ => false
  }
}

///|
fn is_ascii_digit(char : Char) -> Bool {
  match char {
    '0'..='9' => true
    _ => false
  }
}

///|
fn is_lower_ascii(char : Char) -> Bool {
  match char {
    'a'..='z' => true
    _ => false
  }
}

///|
fn to_upper_ascii(char : Char) -> Char {
  char.to_ascii_uppercase()
}
