///|
pub(all) enum RichPart {
  RichText(String)
  RichOpen(String, Array[FormatOption])
  RichClose(String)
  RichStandalone(String, Array[FormatOption])
} derive(Debug)

///|
pub fn format_mf2_rich(
  source : String,
  locale : String,
  args : Array[MessageArg],
  formatter : Formatter,
) -> Result[Array[RichPart], String] {
  if source.trim().has_prefix(".") {
    return Err("rich match messages are not supported yet")
  }
  let chars = source.to_array()
  let parts : Array[RichPart] = []
  let text = StringBuilder::new()
  let mut i = 0
  while i < chars.length() {
    if chars[i] == '\\' {
      if i + 1 >= chars.length() {
        return Err("trailing escape")
      }
      text.write_char(chars[i + 1])
      i = i + 2
    } else if chars[i] == '{' {
      push_rich_text(parts, text)
      let mut j = i + 1
      let content_chars : Array[Char] = []
      while j < chars.length() && chars[j] != '}' {
        content_chars.push(chars[j])
        j = j + 1
      }
      if j >= chars.length() {
        return Err("unclosed expression")
      }
      let content = String::from_array(content_chars).trim().to_owned()
      if content.has_prefix("#") {
        let tokens = rich_tokens(content[1:].to_owned())
        if tokens.is_empty() {
          return Err("empty markup tag")
        }
        let standalone = tokens[tokens.length() - 1] == "/"
        let options = match
          rich_options(
            tokens,
            if standalone {
              tokens.length() - 1
            } else {
              tokens.length()
            },
          ) {
          Ok(value) => value
          Err(message) => return Err(message)
        }
        if standalone {
          parts.push(RichStandalone(tokens[0], options))
        } else {
          parts.push(RichOpen(tokens[0], options))
        }
      } else if content.has_prefix("/") {
        let name = content[1:].to_owned().trim().to_owned()
        if name.is_empty() {
          return Err("empty closing markup tag")
        }
        parts.push(RichClose(name))
      } else {
        match format_mf2_message("{\{content}}", locale, args, formatter) {
          Ok(value) => parts.push(RichText(value))
          Err(message) => return Err(message)
        }
      }
      i = j + 1
    } else if chars[i] == '}' {
      return Err("unmatched closing brace")
    } else {
      text.write_char(chars[i])
      i = i + 1
    }
  }
  push_rich_text(parts, text)
  Ok(parts)
}

///|
pub fn validate_rich_tags(
  parts : Array[RichPart],
  allowed_tags : Array[String],
) -> Result[Unit, String] {
  for part in parts {
    let name = match part {
      RichOpen(name, _) | RichClose(name) | RichStandalone(name, _) =>
        Some(name)
      RichText(_) => None
    }
    match name {
      Some(value) if !allowed_tags.contains(value) =>
        return Err("rich message uses an unregistered tag: \{value}")
      _ => ()
    }
  }
  Ok(())
}

///|
fn push_rich_text(parts : Array[RichPart], text : StringBuilder) -> Unit {
  let value = text.to_string()
  if !value.is_empty() {
    parts.push(RichText(value))
    text.reset()
  }
}

///|
fn rich_tokens(value : String) -> Array[String] {
  let result : Array[String] = []
  let current = StringBuilder::new()
  let mut quoted = false
  for c in value.to_array() {
    if c == '|' {
      quoted = !quoted
      current.write_char(c)
    } else if !quoted && (c == ' ' || c == '\t') {
      let token = current.to_string()
      if !token.is_empty() {
        result.push(token)
        current.reset()
      }
    } else {
      current.write_char(c)
    }
  }
  let token = current.to_string()
  if !token.is_empty() {
    result.push(token)
  }
  result
}

///|
fn rich_options(
  tokens : Array[String],
  end : Int,
) -> Result[Array[FormatOption], String] {
  let options : Array[FormatOption] = []
  for i = 1; i < end; i = i + 1 {
    match tokens[i].split_once("=") {
      Some((name, value)) =>
        options.push({
          name: name.to_owned(),
          value: value.to_owned().trim(chars="|").to_owned(),
        })
      None => return Err("invalid markup option: \{tokens[i]}")
    }
  }
  Ok(options)
}
