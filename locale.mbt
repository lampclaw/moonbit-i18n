///|
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
  let out = StringBuilder::new()
  for c in value.to_array() {
    out.write_char(locale_to_lower(c))
  }
  out.to_string()
}

///|
fn ascii_upper(value : String) -> String {
  let out = StringBuilder::new()
  for c in value.to_array() {
    out.write_char(locale_to_upper(c))
  }
  out.to_string()
}

///|
fn ascii_title(value : String) -> String {
  let chars = value.to_array()
  let out = StringBuilder::new()
  for i = 0; i < chars.length(); i = i + 1 {
    out.write_char(
      if i == 0 {
        locale_to_upper(chars[i])
      } else {
        locale_to_lower(chars[i])
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
fn locale_to_lower(c : Char) -> Char {
  match c {
    'A' => 'a'
    'B' => 'b'
    'C' => 'c'
    'D' => 'd'
    'E' => 'e'
    'F' => 'f'
    'G' => 'g'
    'H' => 'h'
    'I' => 'i'
    'J' => 'j'
    'K' => 'k'
    'L' => 'l'
    'M' => 'm'
    'N' => 'n'
    'O' => 'o'
    'P' => 'p'
    'Q' => 'q'
    'R' => 'r'
    'S' => 's'
    'T' => 't'
    'U' => 'u'
    'V' => 'v'
    'W' => 'w'
    'X' => 'x'
    'Y' => 'y'
    'Z' => 'z'
    _ => c
  }
}

///|
fn locale_to_upper(c : Char) -> Char {
  match c {
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
    _ => c
  }
}
