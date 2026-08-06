///|
pub(all) enum MessageValue {
  TextValue(String)
  IntValue(Int)
  DoubleValue(Double)
  BoolValue(Bool)
  DateTimeValue(String)
} derive(Eq, Debug)

///|
pub(all) struct MessageArg {
  name : String
  value : MessageValue
}

///|
pub(all) struct FormatOption {
  name : String
  value : String
} derive(Debug)

///|
pub(all) struct Formatter {
  format_number : (String, Double, Array[FormatOption]) -> String
  format_datetime : (String, String, Array[FormatOption]) -> String
  plural_category : (String, Double, Bool) -> String
}

///|
pub fn Formatter::basic() -> Formatter {
  {
    format_number: (_locale, value, options) => {
      let integer = option_value(options, "integer") == Some("true")
      if integer {
        value.to_int().to_string()
      } else {
        value.to_string()
      }
    },
    format_datetime: (_locale, value, _options) => value,
    plural_category: (_locale, value, ordinal) => {
      if ordinal {
        let n = value.to_int() % 100
        let last = value.to_int() % 10
        if n >= 11 && n <= 13 {
          "other"
        } else if last == 1 {
          "one"
        } else if last == 2 {
          "two"
        } else if last == 3 {
          "few"
        } else {
          "other"
        }
      } else if value == 1.0 {
        "one"
      } else {
        "other"
      }
    },
  }
}

///|
pub fn validate_mf2_message(
  source : String,
  params : Array[String],
) -> Result[Unit, String] {
  match
    format_mf2_message(source, "en-US", dummy_args(params), Formatter::basic()) {
    Ok(_) => Ok(())
    Err(message) => Err(message)
  }
}

///|
pub fn validate_mf2_message_with_args(
  source : String,
  args : Array[MessageArg],
) -> Result[Unit, String] {
  match format_mf2_message(source, "en-US", args, Formatter::basic()) {
    Ok(_) => Ok(())
    Err(message) => Err(message)
  }
}

///|
pub fn format_mf2_message(
  source : String,
  locale : String,
  args : Array[MessageArg],
  formatter : Formatter,
) -> Result[String, String] {
  if source.trim().has_prefix(".") {
    format_match_message(source, locale, args, formatter)
  } else {
    format_pattern(source, locale, args, formatter)
  }
}

///|
fn format_pattern(
  source : String,
  locale : String,
  args : Array[MessageArg],
  formatter : Formatter,
) -> Result[String, String] {
  let chars = source.to_array()
  let out = StringBuilder::new()
  let mut i = 0
  while i < chars.length() {
    if chars[i] == '\\' {
      if i + 1 >= chars.length() {
        return Err("trailing escape")
      }
      let escaped = chars[i + 1]
      if escaped != '\\' && escaped != '{' && escaped != '}' {
        return Err("invalid escape")
      }
      out.write_char(escaped)
      i = i + 2
    } else if chars[i] == '{' {
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
      match format_expression(content, locale, args, formatter) {
        Ok(value) => out.write_string(value)
        Err(message) => return Err(message)
      }
      i = j + 1
    } else if chars[i] == '}' {
      return Err("unmatched closing brace")
    } else {
      out.write_char(chars[i])
      i = i + 1
    }
  }
  Ok(out.to_string())
}

///|
fn format_expression(
  content : String,
  locale : String,
  args : Array[MessageArg],
  formatter : Formatter,
) -> Result[String, String] {
  if content.is_empty() {
    return Err("empty expression")
  }
  if content.has_prefix("#") || content.has_prefix("/") {
    return Err("MF2 markup requires the rich message API")
  }
  let tokens = whitespace_tokens(content)
  if tokens.is_empty() {
    return Err("empty expression")
  }
  let value = if tokens[0].has_prefix("$") {
    let name = tokens[0][1:].to_owned()
    match find_arg(args, name) {
      Some(arg) => arg.value
      None => return Err("unknown variable: \{name}")
    }
  } else {
    TextValue(unquote_literal(tokens[0]))
  }
  let mut function_name = ""
  let options : Array[FormatOption] = []
  for i = 1; i < tokens.length(); i = i + 1 {
    let token = tokens[i]
    if token.has_prefix(":") {
      if !function_name.is_empty() {
        return Err("multiple functions in expression")
      }
      function_name = token[1:].to_owned()
    } else {
      match token.split_once("=") {
        Some((name, option)) =>
          options.push({
            name: name.to_owned(),
            value: unquote_literal(option.to_owned()),
          })
        None => return Err("invalid function option: \{token}")
      }
    }
  }
  format_value(value, function_name, options, locale, formatter)
}

///|
fn format_value(
  value : MessageValue,
  function_name : String,
  options : Array[FormatOption],
  locale : String,
  formatter : Formatter,
) -> Result[String, String] {
  match function_name {
    "" | "string" => Ok(message_value_to_string(value))
    "number" =>
      match message_value_to_double(value) {
        Some(number) => Ok((formatter.format_number)(locale, number, options))
        None => Err(":number requires an Int or Double")
      }
    "integer" =>
      match message_value_to_double(value) {
        Some(number) => {
          let next_options = options.copy()
          next_options.push({ name: "integer", value: "true" })
          Ok((formatter.format_number)(locale, number, next_options))
        }
        None => Err(":integer requires an Int or Double")
      }
    "datetime" =>
      match value {
        DateTimeValue(datetime) | TextValue(datetime) =>
          Ok((formatter.format_datetime)(locale, datetime, options))
        _ => Err(":datetime requires a DateTime or String")
      }
    _ => Err("unsupported function: :\{function_name}")
  }
}

///|
fn format_match_message(
  source : String,
  locale : String,
  args : Array[MessageArg],
  formatter : Formatter,
) -> Result[String, String] {
  let selectors : Array[(String, String, Array[FormatOption])] = []
  let match_names : Array[String] = []
  let variants : Array[(Array[String], String)] = []
  let resolved_args = args.copy()
  let mut standalone_pattern : String? = None
  for raw_line in source.split("\n") {
    let line = raw_line.to_owned().trim().to_owned()
    if line.is_empty() {
      continue
    }
    if line.has_prefix(".input") {
      let open = match line.find("{") {
        Some(value) => value
        None => return Err("invalid .input declaration")
      }
      let close = match line.rev_find("}") {
        Some(value) => value
        None => return Err("invalid .input declaration")
      }
      let expression = line[open + 1:close].to_owned()
      let tokens = whitespace_tokens(expression)
      if tokens.is_empty() || !tokens[0].has_prefix("$") {
        return Err("invalid .input variable")
      }
      let name = tokens[0][1:].to_owned()
      let mut function_name = "string"
      let options : Array[FormatOption] = []
      for i = 1; i < tokens.length(); i = i + 1 {
        if tokens[i].has_prefix(":") {
          function_name = tokens[i][1:].to_owned()
        } else {
          match tokens[i].split_once("=") {
            Some((key, value)) =>
              options.push({
                name: key.to_owned(),
                value: unquote_literal(value.to_owned()),
              })
            None => return Err("invalid .input option")
          }
        }
      }
      selectors.push((name, function_name, options))
    } else if line.has_prefix(".local") {
      let assignment = line[".local".length():].to_owned().trim().to_owned()
      let (name_part, expression_part) = match assignment.split_once("=") {
        Some(value) => value
        None => return Err("invalid .local declaration")
      }
      let name_token = name_part.to_owned().trim().to_owned()
      if !name_token.has_prefix("$") || name_token.length() == 1 {
        return Err("invalid .local variable")
      }
      let expression = expression_part.to_owned().trim().to_owned()
      if !expression.has_prefix("{") || !expression.has_suffix("}") {
        return Err("invalid .local expression")
      }
      let content = expression[1:expression.length() - 1].to_owned()
      let value = match
        format_expression(content, locale, resolved_args, formatter) {
        Ok(value) => value
        Err(message) => return Err(message)
      }
      resolved_args.push({
        name: name_token[1:].to_owned(),
        value: TextValue(value),
      })
    } else if line.has_prefix(".match") {
      let tokens = whitespace_tokens(line[".match".length():].to_owned())
      for token in tokens {
        if !token.has_prefix("$") {
          return Err("invalid .match selector")
        }
        match_names.push(token[1:].to_owned())
      }
    } else if line.has_prefix("{{") &&
      line.has_suffix("}}") &&
      match_names.is_empty() {
      standalone_pattern = Some(line[2:line.length() - 2].to_owned())
    } else {
      let open = match line.find("{{") {
        Some(value) => value
        None => return Err("invalid match variant")
      }
      let close = match line.rev_find("}}") {
        Some(value) => value
        None => return Err("invalid match variant")
      }
      if close < open + 2 {
        return Err("invalid match variant")
      }
      let keys = whitespace_tokens(line[:open].to_owned())
      let pattern = line[open + 2:close].to_owned()
      variants.push((keys, pattern))
    }
  }
  if match_names.is_empty() {
    return match standalone_pattern {
      Some(pattern) => format_pattern(pattern, locale, resolved_args, formatter)
      None => Err("complex message requires a pattern or matcher")
    }
  }
  if variants.is_empty() {
    return Err("match message requires selectors and variants")
  }
  for variant in variants {
    let (keys, pattern) = variant
    if keys.length() != match_names.length() {
      return Err("match variant key count mismatch")
    }
    let mut matches = true
    for i = 0; i < match_names.length(); i = i + 1 {
      if keys[i] == "*" {
        continue
      }
      let selector = match find_selector(selectors, match_names[i]) {
        Some(value) => value
        None =>
          return Err("matched variable requires .input: \{match_names[i]}")
      }
      let arg = match find_arg(resolved_args, match_names[i]) {
        Some(value) => value
        None => return Err("unknown variable: \{match_names[i]}")
      }
      if !selector_matches(
          keys[i],
          arg.value,
          selector.1,
          selector.2,
          locale,
          formatter,
        ) {
        matches = false
        break
      }
    }
    if matches {
      return format_pattern(pattern, locale, resolved_args, formatter)
    }
  }
  Err("no match variant selected")
}

///|
fn selector_matches(
  key : String,
  value : MessageValue,
  function_name : String,
  options : Array[FormatOption],
  locale : String,
  formatter : Formatter,
) -> Bool {
  if function_name == "number" || function_name == "integer" {
    guard message_value_to_double(value) is Some(number) else { return false }
    if key == number.to_string() || key == number.to_int().to_string() {
      return true
    }
    let ordinal = option_value(options, "select") == Some("ordinal")
    (formatter.plural_category)(locale, number, ordinal) == key
  } else {
    message_value_to_string(value) == unquote_literal(key)
  }
}

///|
fn find_selector(
  selectors : Array[(String, String, Array[FormatOption])],
  name : String,
) -> (String, String, Array[FormatOption])? {
  for selector in selectors {
    if selector.0 == name {
      return Some(selector)
    }
  }
  None
}

///|
fn find_arg(args : Array[MessageArg], name : String) -> MessageArg? {
  for arg in args {
    if arg.name == name {
      return Some(arg)
    }
  }
  None
}

///|
fn message_value_to_string(value : MessageValue) -> String {
  match value {
    TextValue(value) | DateTimeValue(value) => value
    IntValue(value) => value.to_string()
    DoubleValue(value) => value.to_string()
    BoolValue(value) => value.to_string()
  }
}

///|
fn message_value_to_double(value : MessageValue) -> Double? {
  match value {
    IntValue(value) => Some(value.to_double())
    DoubleValue(value) => Some(value)
    _ => None
  }
}

///|
fn whitespace_tokens(value : String) -> Array[String] {
  let result : Array[String] = []
  let current = StringBuilder::new()
  let mut quoted = false
  for c in value.to_array() {
    if c == '|' {
      quoted = !quoted
      current.write_char(c)
    } else if !quoted && (c == ' ' || c == '\t' || c == '\n' || c == '\r') {
      let token = current.to_string()
      if !token.is_empty() {
        result.push(token)
        current.reset()
      }
    } else {
      current.write_char(c)
    }
  }
  if quoted {
    return []
  }
  let token = current.to_string()
  if !token.is_empty() {
    result.push(token)
  }
  result
}

///|
fn unquote_literal(value : String) -> String {
  if value.length() >= 2 && value.has_prefix("|") && value.has_suffix("|") {
    value[1:value.length() - 1].to_owned().replace_all(old="\\|", new="|")
  } else {
    value
  }
}

///|
fn option_value(options : Array[FormatOption], name : String) -> String? {
  for option in options {
    if option.name == name {
      return Some(option.value)
    }
  }
  None
}

///|
fn dummy_args(params : Array[String]) -> Array[MessageArg] {
  params.map(name => { name, value: TextValue(name) })
}
