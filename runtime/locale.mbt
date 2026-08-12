///|
/// Normalizes a supported BCP-47-like locale code and rejects invalid input.
pub fn normalize_locale_code(code : String) -> Result[String, String] {
  let normalized = code.replace_all(old="_", new="-")
  let parts = normalized.split("-").map(part => part.to_owned()).collect()
  if parts.is_empty() || parts[0].is_empty() {
    return Err("locale code must not be empty")
  }
  let out : Array[String] = []
  for i = 0; i < parts.length(); i = i + 1 {
    let part = parts[i]
    if part.is_empty() || !locale_part_is_ascii_alnum(part) {
      return Err("invalid locale code: \{code}")
    }
    if i == 0 {
      out.push(ascii_lower(part))
    } else if part.length() == 4 {
      out.push(ascii_title(part))
    } else if part.length() == 2 || (part.length() == 3 && part_is_digits(part)) {
      out.push(ascii_upper(part))
    } else {
      out.push(ascii_lower(part))
    }
  }
  Ok(out.join("-"))
}

///|
/// Returns progressively less-specific locale candidates for lookup.
pub fn locale_lookup_chain(code : String) -> Array[String] {
  let normalized = match normalize_locale_code(code) {
    Ok(value) => value
    Err(_) => return []
  }
  let parts = normalized.split("-").map(part => part.to_owned()).collect()
  let result : Array[String] = []
  for end = parts.length(); end > 0; end = end - 1 {
    let candidate = parts[:end].to_owned().join("-")
    if !result.contains(candidate) {
      result.push(candidate)
    }
  }
  result
}

///|
/// Resolves ordered requested locales against supported locales and a default.
pub fn resolve_locale_code(
  requested : Array[String],
  supported : Array[String],
  fallback : String,
) -> String {
  let normalized_supported : Array[String] = []
  for code in supported {
    match normalize_locale_code(code) {
      Ok(value) => normalized_supported.push(value)
      Err(_) => ()
    }
  }
  for code in requested {
    for candidate in locale_lookup_chain(code) {
      if normalized_supported.contains(candidate) {
        return candidate
      }
    }
  }
  match normalize_locale_code(fallback) {
    Ok(value) if normalized_supported.contains(value) => value
    _ =>
      if normalized_supported.is_empty() {
        fallback
      } else {
        normalized_supported[0]
      }
  }
}

///|
fn locale_part_is_ascii_alnum(value : String) -> Bool {
  for c in value.to_array() {
    if !(locale_is_ascii_letter(c) || locale_is_ascii_digit(c)) {
      return false
    }
  }
  true
}

///|
fn part_is_digits(value : String) -> Bool {
  for c in value.to_array() {
    if !locale_is_ascii_digit(c) {
      return false
    }
  }
  true
}

///|
fn ascii_lower(value : String) -> String {
  value.to_lower()
}

///|
fn ascii_upper(value : String) -> String {
  value.to_upper()
}

///|
fn ascii_title(value : String) -> String {
  let chars = value.to_array()
  let out = StringBuilder::new()
  for i = 0; i < chars.length(); i = i + 1 {
    out.write_char(
      if i == 0 {
        chars[i].to_ascii_uppercase()
      } else {
        chars[i].to_ascii_lowercase()
      },
    )
  }
  out.to_string()
}

///|
fn locale_is_ascii_letter(c : Char) -> Bool {
  match c {
    'a'..='z' | 'A'..='Z' => true
    _ => false
  }
}

///|
fn locale_is_ascii_digit(c : Char) -> Bool {
  match c {
    '0'..='9' => true
    _ => false
  }
}

///|
