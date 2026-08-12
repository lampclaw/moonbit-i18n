///|
/// Compatibility representation for rich text and markup events.
pub(all) enum RichPart {
  /// Plain text.
  RichText(String)
  /// Opening markup with resolved options.
  RichOpen(String, Array[FormatOption])
  /// Closing markup.
  RichClose(String)
  /// Standalone markup with resolved options.
  RichStandalone(String, Array[FormatOption])
} derive(Eq, Debug)

///|
/// Formats MF2 source into the compatibility rich-parts representation.
pub fn format_mf2_rich(
  source : String,
  locale : String,
  args : Array[MessageArg],
  formatter : Formatter,
) -> Result[Array[RichPart], String] {
  let compiled = match compile_mf2_message(source, MessageContract::open()) {
    Ok(value) => value
    Err(errors) => return Err(errors[0].message)
  }
  match format_parts(compiled, locale, args, formatter) {
    Ok(parts) =>
      Ok(
        parts.map(part => {
          match part {
            Text(value) => RichText(value)
            Open(name, options) => RichOpen(name, options)
            Close(name) => RichClose(name)
            Standalone(name, options) => RichStandalone(name, options)
          }
        }),
      )
    Err(error) => Err(error.message)
  }
}

///|
/// Ensures every rich markup name is present in the allowed-tag contract.
pub fn validate_rich_tags(
  parts : Array[RichPart],
  allowed_tags : Array[String],
) -> Result[Unit, String] {
  if allowed_tags.length() > MF2_MAX_CONTRACT_TAGS {
    return Err(
      "rich tag allowlist exceeds the \{MF2_MAX_CONTRACT_TAGS}-tag limit",
    )
  }
  let allowed : Map[String, Bool] = Map([])
  for tag in allowed_tags {
    if !valid_identifier(tag) {
      return Err("invalid rich tag allowlist entry: \{tag}")
    }
    if allowed.contains(tag) {
      return Err("duplicate rich tag allowlist entry: \{tag}")
    }
    allowed[tag] = true
  }
  let stack : Array[String] = []
  for part in parts {
    match part {
      RichText(_) => ()
      RichStandalone(name, _) =>
        if !allowed.contains(name) {
          return Err("rich message uses an unregistered tag: \{name}")
        }
      RichOpen(name, _) => {
        if !allowed.contains(name) {
          return Err("rich message uses an unregistered tag: \{name}")
        }
        stack.push(name)
      }
      RichClose(name) => {
        if !allowed.contains(name) {
          return Err("rich message uses an unregistered tag: \{name}")
        }
        let expected = match stack.pop() {
          Some(value) => value
          None => return Err("unexpected closing rich tag: \{name}")
        }
        if expected != name {
          return Err(
            "mismatched closing rich tag: expected \{expected}, got \{name}",
          )
        }
      }
    }
  }
  if !stack.is_empty() {
    Err("unclosed rich tag: \{stack[stack.length() - 1]}")
  } else {
    Ok(())
  }
}
