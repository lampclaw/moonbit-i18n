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
  for group in group_names {
    if pascal(group) == "I18n" {
      errors.push("group generates the reserved I18nText type name: \{group}")
    }
    if pascal(group) == "Self" {
      errors.push("group generates the reserved Self variant: \{group}")
    }
  }
  for i = 0; i < group_names.length(); i = i + 1 {
    for j = i + 1; j < group_names.length(); j = j + 1 {
      if pascal(group_names[i]) == pascal(group_names[j]) {
        errors.push(
          "groups generate the same enum variant: \{group_names[i]} and \{group_names[j]} -> \{pascal(group_names[i])}",
        )
      }
    }
  }
  for group in group_names {
    let group_entries = entries_for(entries, group)
    for entry in group_entries {
      if pascal(entry.key) == "Self" {
        errors.push(
          "key generates the reserved Self variant in \{group}: \{entry.key}",
        )
      }
    }
    for i = 0; i < group_entries.length(); i = i + 1 {
      for j = i + 1; j < group_entries.length(); j = j + 1 {
        if pascal(group_entries[i].key) == pascal(group_entries[j].key) {
          errors.push(
            "keys generate the same enum variant in \{group}: \{group_entries[i].key} and \{group_entries[j].key} -> \{pascal(group_entries[i].key)}",
          )
        }
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
  for locale in locales {
    if locale_variant(locale.code) == "Self" {
      errors.push(
        "locale code generates the reserved Self variant: \{locale.code}",
      )
    }
  }
  for i = 0; i < locales.length(); i = i + 1 {
    for j = i + 1; j < locales.length(); j = j + 1 {
      if locale_variant(locales[i].code) == locale_variant(locales[j].code) {
        errors.push(
          "locale codes generate the same enum variant: \{locales[i].code} and \{locales[j].code} -> \{locale_variant(locales[i].code)}",
        )
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
fn groups(entries : Array[Entry]) -> Array[String] {
  let result : Array[String] = []
  for entry in entries {
    if !result.contains(entry.group) {
      result.push(entry.group)
    }
  }
  result.sort_by((left, right) => left.lexical_compare(right))
  result
}

///|
fn entries_for(entries : Array[Entry], group : String) -> Array[Entry] {
  let result : Array[Entry] = []
  for entry in entries {
    if entry.group == group {
      result.push(entry)
    }
  }
  result.sort_by((left, right) => left.key.lexical_compare(right.key))
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
  match char {
    'a' => 'A'
    'b' => 'B'
    'c' => 'C'
    'd' => 'D'
    'e' => 'E'
    'f' => 'F'
    'g' => 'G'
    'h' => 'H'
    'i' => 'I'
    'j' => 'J'
    'k' => 'K'
    'l' => 'L'
    'm' => 'M'
    'n' => 'N'
    'o' => 'O'
    'p' => 'P'
    'q' => 'Q'
    'r' => 'R'
    's' => 'S'
    't' => 'T'
    'u' => 'U'
    'v' => 'V'
    'w' => 'W'
    'x' => 'X'
    'y' => 'Y'
    'z' => 'Z'
    _ => char
  }
}
