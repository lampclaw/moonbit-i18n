///|
/// Pinned Unicode MessageFormat syntax and data-model profile implemented by
/// the standalone parser in this package.
pub const MF2_SYNTAX_PROFILE : String = "unicode-mf2-ldml48.2-syntax-v1"

///|
/// A literal or variable reference in the normative MF2 interchange model.
pub(all) enum Mf2ModelValue {
  /// A cooked literal value with quotes and escapes removed.
  Mf2ModelLiteral(String)
  /// A variable name without its leading `$` sigil.
  Mf2ModelVariable(String)
} derive(Eq, Debug)

///|
/// One function or markup option in the normative MF2 interchange model.
pub(all) struct Mf2ModelOption {
  /// NFC-normalized option identifier.
  name : String
  /// Literal or variable option value.
  value : Mf2ModelValue
} derive(Eq, Debug)

///|
/// One expression or markup attribute in the normative MF2 interchange model.
pub(all) struct Mf2ModelAttribute {
  /// NFC-normalized attribute identifier.
  name : String
  /// Optional cooked literal value; `None` represents a valueless attribute.
  value : String?
} derive(Eq, Debug)

///|
/// A function reference in the normative MF2 interchange model.
pub(all) struct Mf2ModelFunction {
  /// NFC-normalized function identifier without its leading `:` sigil.
  name : String
  /// Function options in source order.
  options : Array[Mf2ModelOption]
} derive(Eq, Debug)

///|
/// An expression in the normative MF2 interchange model.
pub(all) struct Mf2ModelExpression {
  /// Optional literal or variable operand.
  arg : Mf2ModelValue?
  /// Optional function reference; a function-only expression has no `arg`.
  function_ref : Mf2ModelFunction?
  /// Attributes after applying the specified last-value-wins rule.
  attributes : Array[Mf2ModelAttribute]
  /// Character offset of the opening `{` in the source message.
  offset : Int
} derive(Eq, Debug)

///|
/// Kind of markup placeholder in the normative MF2 interchange model.
pub(all) enum Mf2ModelMarkupKind {
  /// An opening markup placeholder.
  Mf2MarkupOpen
  /// A standalone markup placeholder.
  Mf2MarkupStandalone
  /// A closing markup placeholder.
  Mf2MarkupClose
} derive(Eq, Debug)

///|
/// A markup placeholder in the normative MF2 interchange model.
pub(all) struct Mf2ModelMarkup {
  /// Open, standalone, or close kind.
  kind : Mf2ModelMarkupKind
  /// NFC-normalized markup identifier without syntax sigils.
  name : String
  /// Markup options in source order.
  options : Array[Mf2ModelOption]
  /// Attributes after applying the specified last-value-wins rule.
  attributes : Array[Mf2ModelAttribute]
  /// Character offset of the opening `{` in the source message.
  offset : Int
} derive(Eq, Debug)

///|
/// One part of an MF2 pattern in the normative interchange model.
pub(all) enum Mf2ModelPatternPart {
  /// Non-empty literal pattern text with escapes processed.
  Mf2ModelText(String)
  /// An expression placeholder.
  Mf2ModelExpressionPart(Mf2ModelExpression)
  /// A markup placeholder.
  Mf2ModelMarkupPart(Mf2ModelMarkup)
} derive(Eq, Debug)

///|
/// A linear MF2 pattern in the normative interchange model.
pub(all) struct Mf2ModelPattern {
  /// Text, expression, and markup parts in source order.
  parts : Array[Mf2ModelPatternPart]
} derive(Eq, Debug)

///|
/// One MF2 declaration in the normative interchange model.
pub(all) enum Mf2ModelDeclaration {
  /// An input declaration; the expression operand names the bound variable.
  Mf2ModelInput(String, Mf2ModelExpression)
  /// A local declaration and its expression value.
  Mf2ModelLocal(String, Mf2ModelExpression)
} derive(Eq, Debug)

///|
/// One matcher key in the normative interchange model.
pub(all) enum Mf2ModelVariantKey {
  /// A cooked literal key value.
  Mf2ModelLiteralKey(String)
  /// The catch-all `*` key.
  Mf2ModelCatchallKey
} derive(Eq, Debug)

///|
/// One matcher variant in the normative interchange model.
pub(all) struct Mf2ModelVariant {
  /// Variant keys in selector order.
  keys : Array[Mf2ModelVariantKey]
  /// Pattern selected by this variant.
  value : Mf2ModelPattern
  /// Character offset of the first key in the source message.
  offset : Int
} derive(Eq, Debug)

///|
/// A parsed MF2 message in the normative interchange model.
pub(all) enum Mf2MessageModel {
  /// A message with declarations and one pattern.
  Mf2PatternMessage(Array[Mf2ModelDeclaration], Mf2ModelPattern)
  /// A message with declarations, selectors, and variants.
  Mf2SelectMessage(
    Array[Mf2ModelDeclaration],
    Array[String],
    Array[Mf2ModelVariant]
  )
} derive(Eq, Debug)

///|
priv struct Mf2SyntaxParser {
  chars : Array[Char]
  mut cursor : Int
}

///|
fn mf2_syntax_error(message : String, offset : Int) -> Mf2Error {
  { kind: Mf2SyntaxError, code: Mf2SyntaxCode, message, offset }
}

///|
fn mf2_model_error(
  code : Mf2ErrorCode,
  message : String,
  offset : Int,
) -> Mf2Error {
  { kind: Mf2DataModelError, code, message, offset }
}

///|
/// Parses the complete pinned MF2 grammar into its interchange data model.
///
/// This operation establishes well-formedness only. Call
/// `validate_mf2_model` or `parse_valid_mf2_model` to apply the additional
/// validity rules.
pub fn parse_mf2_syntax(source : String) -> Result[Mf2MessageModel, Mf2Error] {
  if @utf8.encode(source).length() > MF2_MAX_MESSAGE_BYTES {
    return Err({
      kind: Mf2LimitError,
      code: Mf2LimitCode,
      message: "message exceeds the \{MF2_MAX_MESSAGE_BYTES}-byte limit",
      offset: 0,
    })
  }
  let chars = source.to_array()
  for i = 0; i < chars.length(); i = i + 1 {
    if chars[i].to_int() == 0 {
      return Err(mf2_syntax_error("MF2 messages must not contain U+0000", i))
    }
  }
  let parser = Mf2SyntaxParser::{ chars, cursor: 0 }
  parser.parse_message()
}

///|
/// Parses a well-formed MF2 message and applies all pinned data-model validity
/// rules. Syntax failures contain one syntax error; validity failures may
/// contain multiple independent data-model errors.
pub fn parse_valid_mf2_model(
  source : String,
) -> Result[Mf2MessageModel, Array[Mf2Error]] {
  let model = match parse_mf2_syntax(source) {
    Ok(value) => value
    Err(error) => return Err([error])
  }
  let errors = validate_mf2_model(model)
  if errors.is_empty() {
    Ok(model)
  } else {
    Err(errors)
  }
}

///|
fn Mf2SyntaxParser::parse_message(
  self : Mf2SyntaxParser,
) -> Result[Mf2MessageModel, Mf2Error] {
  let start = self.cursor
  self.skip_optional_layout()
  let complex = self.starts_with(".input") ||
    self.starts_with(".local") ||
    self.starts_with(".match") ||
    self.starts_with("{{")
  self.cursor = start
  if complex {
    self.parse_complex_message()
  } else {
    self.parse_simple_message()
  }
}

///|
fn Mf2SyntaxParser::parse_simple_message(
  self : Mf2SyntaxParser,
) -> Result[Mf2MessageModel, Mf2Error] {
  let significant_start = self.cursor
  self.skip_optional_layout()
  if self.cursor < self.chars.length() {
    let first = self.chars[self.cursor]
    if first == '.' ||
      (!is_mf2_simple_start_char(first) && first != '\\' && first != '{') {
      return Err(
        mf2_syntax_error(
          "invalid first non-whitespace character in a simple message",
          self.cursor,
        ),
      )
    }
  }
  self.cursor = significant_start
  let pattern = match self.parse_pattern(false) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  if self.cursor != self.chars.length() {
    return Err(
      mf2_syntax_error("unexpected content after message", self.cursor),
    )
  }
  Ok(Mf2PatternMessage([], pattern))
}

///|
fn Mf2SyntaxParser::parse_complex_message(
  self : Mf2SyntaxParser,
) -> Result[Mf2MessageModel, Mf2Error] {
  self.skip_optional_layout()
  let declarations : Array[Mf2ModelDeclaration] = []
  while self.starts_with(".input") || self.starts_with(".local") {
    if declarations.length() >= MF2_MAX_DECLARATIONS {
      return Err({
        kind: Mf2LimitError,
        code: Mf2LimitCode,
        message: "message exceeds the declaration limit",
        offset: self.cursor,
      })
    }
    let declaration = if self.starts_with(".input") {
      match self.parse_input_declaration() {
        Ok(value) => value
        Err(error) => return Err(error)
      }
    } else {
      match self.parse_local_declaration() {
        Ok(value) => value
        Err(error) => return Err(error)
      }
    }
    declarations.push(declaration)
    self.skip_optional_layout()
  }
  let result = if self.starts_with("{{") {
    let pattern = match self.parse_quoted_pattern() {
      Ok(value) => value
      Err(error) => return Err(error)
    }
    Mf2PatternMessage(declarations, pattern)
  } else if self.starts_with(".match") {
    match self.parse_matcher(declarations) {
      Ok(value) => value
      Err(error) => return Err(error)
    }
  } else {
    return Err(
      mf2_syntax_error(
        "complex message requires a quoted pattern or matcher",
        self.cursor,
      ),
    )
  }
  self.skip_optional_layout()
  if self.cursor != self.chars.length() {
    return Err(
      mf2_syntax_error("unexpected content after complex message", self.cursor),
    )
  }
  Ok(result)
}

///|
fn Mf2SyntaxParser::parse_input_declaration(
  self : Mf2SyntaxParser,
) -> Result[Mf2ModelDeclaration, Mf2Error] {
  let offset = self.cursor
  self.cursor = self.cursor + ".input".length()
  self.skip_optional_layout()
  let expression = match self.parse_placeholder_expression() {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  guard expression.arg is Some(Mf2ModelVariable(name)) else {
    return Err(
      mf2_syntax_error(".input requires a variable expression", offset),
    )
  }
  Ok(Mf2ModelInput(name, expression))
}

///|
fn Mf2SyntaxParser::parse_local_declaration(
  self : Mf2SyntaxParser,
) -> Result[Mf2ModelDeclaration, Mf2Error] {
  let offset = self.cursor
  self.cursor = self.cursor + ".local".length()
  if !self.skip_required_layout() {
    return Err(mf2_syntax_error(".local requires whitespace", self.cursor))
  }
  let name = match self.parse_variable() {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  self.skip_optional_layout()
  if !self.consume('=') {
    return Err(mf2_syntax_error(".local requires '='", self.cursor))
  }
  self.skip_optional_layout()
  let expression = match self.parse_placeholder_expression() {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  ignore(offset)
  Ok(Mf2ModelLocal(name, expression))
}

///|
fn Mf2SyntaxParser::parse_matcher(
  self : Mf2SyntaxParser,
  declarations : Array[Mf2ModelDeclaration],
) -> Result[Mf2MessageModel, Mf2Error] {
  let match_offset = self.cursor
  self.cursor = self.cursor + ".match".length()
  if !self.skip_required_layout() {
    return Err(mf2_syntax_error(".match requires a selector", self.cursor))
  }
  let selectors : Array[String] = []
  let first = match self.parse_variable() {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  selectors.push(first)
  while true {
    if !self.skip_required_layout() {
      return Err(
        mf2_syntax_error(
          "matcher selector and variant require separating whitespace",
          self.cursor,
        ),
      )
    }
    if self.peek() == Some('$') {
      if selectors.length() >= MF2_MAX_SELECTORS {
        return Err({
          kind: Mf2LimitError,
          code: Mf2LimitCode,
          message: "matcher exceeds the selector limit",
          offset: self.cursor,
        })
      }
      let selector = match self.parse_variable() {
        Ok(value) => value
        Err(error) => return Err(error)
      }
      selectors.push(selector)
    } else {
      break
    }
  }
  if self.cursor == match_offset + ".match".length() {
    return Err(mf2_syntax_error(".match requires a selector", self.cursor))
  }
  let variants : Array[Mf2ModelVariant] = []
  while self.cursor < self.chars.length() {
    self.skip_optional_layout()
    if self.cursor >= self.chars.length() {
      break
    }
    if variants.length() >= MF2_MAX_VARIANTS {
      return Err({
        kind: Mf2LimitError,
        code: Mf2LimitCode,
        message: "message exceeds the variant limit",
        offset: self.cursor,
      })
    }
    let variant = match self.parse_variant() {
      Ok(value) => value
      Err(error) => return Err(error)
    }
    variants.push(variant)
  }
  if variants.is_empty() {
    return Err(
      mf2_syntax_error("matcher requires at least one variant", self.cursor),
    )
  }
  Ok(Mf2SelectMessage(declarations, selectors, variants))
}

///|
fn Mf2SyntaxParser::parse_variant(
  self : Mf2SyntaxParser,
) -> Result[Mf2ModelVariant, Mf2Error] {
  let offset = self.cursor
  let keys : Array[Mf2ModelVariantKey] = []
  while true {
    if self.starts_with("{{") {
      break
    }
    let key = if self.consume('*') {
      Mf2ModelCatchallKey
    } else {
      match self.parse_literal() {
        Ok(value) => Mf2ModelLiteralKey(value)
        Err(error) => return Err(error)
      }
    }
    keys.push(key)
    let before_layout = self.cursor
    self.skip_optional_layout()
    if self.starts_with("{{") {
      break
    }
    if !mf2_range_has_whitespace(self.chars, before_layout, self.cursor) {
      return Err(
        mf2_syntax_error(
          "matcher keys must be separated by whitespace",
          self.cursor,
        ),
      )
    }
  }
  if keys.is_empty() {
    return Err(mf2_syntax_error("matcher variant requires a key", offset))
  }
  let value = match self.parse_quoted_pattern() {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  Ok({ keys, value, offset })
}

///|
fn Mf2SyntaxParser::parse_quoted_pattern(
  self : Mf2SyntaxParser,
) -> Result[Mf2ModelPattern, Mf2Error] {
  if !self.starts_with("{{") {
    return Err(mf2_syntax_error("expected quoted pattern", self.cursor))
  }
  self.cursor = self.cursor + 2
  let pattern = match self.parse_pattern(true) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  if !self.starts_with("}}") {
    return Err(mf2_syntax_error("unclosed quoted pattern", self.cursor))
  }
  self.cursor = self.cursor + 2
  Ok(pattern)
}

///|
fn Mf2SyntaxParser::parse_pattern(
  self : Mf2SyntaxParser,
  quoted : Bool,
) -> Result[Mf2ModelPattern, Mf2Error] {
  let parts : Array[Mf2ModelPatternPart] = []
  let text = StringBuilder::new()
  while self.cursor < self.chars.length() {
    if quoted && self.starts_with("}}") {
      break
    }
    let char = self.chars[self.cursor]
    if char == '\\' {
      let escaped = match self.parse_escape() {
        Ok(value) => value
        Err(error) => return Err(error)
      }
      text.write_char(escaped)
    } else if char == '{' {
      push_mf2_model_text(parts, text)
      let part = match self.parse_placeholder() {
        Ok(value) => value
        Err(error) => return Err(error)
      }
      parts.push(part)
    } else if char == '}' {
      return Err(mf2_syntax_error("unmatched closing brace", self.cursor))
    } else {
      text.write_char(char)
      self.cursor = self.cursor + 1
    }
  }
  push_mf2_model_text(parts, text)
  Ok({ parts, })
}

///|
fn push_mf2_model_text(
  parts : Array[Mf2ModelPatternPart],
  text : StringBuilder,
) -> Unit {
  let value = text.to_string()
  if !value.is_empty() {
    match parts.last() {
      Some(Mf2ModelText(previous)) =>
        parts[parts.length() - 1] = Mf2ModelText(previous + value)
      _ => parts.push(Mf2ModelText(value))
    }
    text.reset()
  }
}

///|
fn Mf2SyntaxParser::parse_placeholder(
  self : Mf2SyntaxParser,
) -> Result[Mf2ModelPatternPart, Mf2Error] {
  let offset = self.cursor
  if !self.consume('{') {
    return Err(mf2_syntax_error("expected placeholder", self.cursor))
  }
  self.skip_optional_layout()
  if self.consume('#') {
    match self.parse_markup(offset, false) {
      Ok(value) => Ok(Mf2ModelMarkupPart(value))
      Err(error) => Err(error)
    }
  } else if self.consume('/') {
    match self.parse_markup(offset, true) {
      Ok(value) => Ok(Mf2ModelMarkupPart(value))
      Err(error) => Err(error)
    }
  } else {
    match self.parse_expression_body(offset) {
      Ok(value) => Ok(Mf2ModelExpressionPart(value))
      Err(error) => Err(error)
    }
  }
}

///|
fn Mf2SyntaxParser::parse_placeholder_expression(
  self : Mf2SyntaxParser,
) -> Result[Mf2ModelExpression, Mf2Error] {
  let offset = self.cursor
  if !self.consume('{') {
    return Err(mf2_syntax_error("expected expression", self.cursor))
  }
  self.skip_optional_layout()
  self.parse_expression_body(offset)
}

///|
fn Mf2SyntaxParser::parse_expression_body(
  self : Mf2SyntaxParser,
  offset : Int,
) -> Result[Mf2ModelExpression, Mf2Error] {
  let arg : Mf2ModelValue? = if self.peek() == Some('$') {
    let name = match self.parse_variable() {
      Ok(value) => value
      Err(error) => return Err(error)
    }
    Some(Mf2ModelVariable(name))
  } else if self.peek() == Some(':') {
    None
  } else {
    let literal = match self.parse_literal() {
      Ok(value) => value
      Err(error) => return Err(error)
    }
    Some(Mf2ModelLiteral(literal))
  }
  let mut function_ref : Mf2ModelFunction? = None
  let mut attribute_layout_consumed = false
  let attributes : Array[Mf2ModelAttribute] = []
  if arg is None {
    function_ref = Some(
      match self.parse_function() {
        Ok(value) => value
        Err(error) => return Err(error)
      },
    )
    attribute_layout_consumed = false
  } else {
    let before_layout = self.cursor
    if self.skip_required_layout() {
      if self.peek() == Some(':') {
        function_ref = Some(
          match self.parse_function() {
            Ok(value) => value
            Err(error) => return Err(error)
          },
        )
        attribute_layout_consumed = false
      } else if self.peek() != Some('@') && self.peek() != Some('}') {
        return Err(
          mf2_syntax_error(
            "unexpected token after expression operand",
            self.cursor,
          ),
        )
      } else if self.peek() == Some('@') {
        attribute_layout_consumed = true
      }
    } else {
      self.cursor = before_layout
    }
  }
  while true {
    let before_layout = self.cursor
    if !attribute_layout_consumed && !self.skip_required_layout() {
      self.cursor = before_layout
      break
    }
    attribute_layout_consumed = false
    if self.peek() == Some('@') {
      let attribute = match self.parse_attribute() {
        Ok(value) => value
        Err(error) => return Err(error)
      }
      replace_mf2_attribute(attributes, attribute)
    } else {
      break
    }
  }
  self.skip_optional_layout()
  if !self.consume('}') {
    return Err(mf2_syntax_error("unclosed expression", self.cursor))
  }
  Ok({ arg, function_ref, attributes, offset })
}

///|
fn Mf2SyntaxParser::parse_function(
  self : Mf2SyntaxParser,
) -> Result[Mf2ModelFunction, Mf2Error] {
  if !self.consume(':') {
    return Err(mf2_syntax_error("expected function", self.cursor))
  }
  let name = match self.parse_identifier() {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let options : Array[Mf2ModelOption] = []
  while true {
    let before_layout = self.cursor
    if !self.skip_required_layout() {
      self.cursor = before_layout
      break
    }
    if self.peek() == Some('@') || self.peek() == Some('}') {
      self.cursor = before_layout
      break
    }
    if options.length() >= MF2_MAX_OPTIONS {
      return Err({
        kind: Mf2LimitError,
        code: Mf2LimitCode,
        message: "function exceeds the \{MF2_MAX_OPTIONS}-option limit",
        offset: self.cursor,
      })
    }
    let option = match self.parse_model_option() {
      Ok(value) => value
      Err(error) => return Err(error)
    }
    options.push(option)
  }
  Ok({ name, options })
}

///|
fn Mf2SyntaxParser::parse_markup(
  self : Mf2SyntaxParser,
  offset : Int,
  closing : Bool,
) -> Result[Mf2ModelMarkup, Mf2Error] {
  self.skip_optional_layout()
  let name = match self.parse_identifier() {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let options : Array[Mf2ModelOption] = []
  let attributes : Array[Mf2ModelAttribute] = []
  let mut standalone = false
  while true {
    let before_layout = self.cursor
    if !self.skip_required_layout() {
      self.cursor = before_layout
      break
    }
    if self.peek() == Some('@') ||
      self.peek() == Some('}') ||
      (!closing && self.peek() == Some('/')) {
      self.cursor = before_layout
      break
    }
    if options.length() >= MF2_MAX_OPTIONS {
      return Err({
        kind: Mf2LimitError,
        code: Mf2LimitCode,
        message: "markup exceeds the \{MF2_MAX_OPTIONS}-option limit",
        offset,
      })
    }
    let option = match self.parse_model_option() {
      Ok(value) => value
      Err(error) => return Err(error)
    }
    options.push(option)
  }
  let mut attribute_layout_consumed = false
  while true {
    let before_layout = self.cursor
    if !attribute_layout_consumed && !self.skip_required_layout() {
      self.cursor = before_layout
      break
    }
    attribute_layout_consumed = false
    if self.peek() == Some('@') {
      let attribute = match self.parse_attribute() {
        Ok(value) => value
        Err(error) => return Err(error)
      }
      replace_mf2_attribute(attributes, attribute)
    } else {
      break
    }
  }
  self.skip_optional_layout()
  if !closing && !standalone && self.consume('/') {
    standalone = true
    self.skip_optional_layout()
  }
  if !self.consume('}') {
    return Err(mf2_syntax_error("unclosed markup placeholder", self.cursor))
  }
  let kind = if closing {
    Mf2MarkupClose
  } else if standalone {
    Mf2MarkupStandalone
  } else {
    Mf2MarkupOpen
  }
  Ok({ kind, name, options, attributes, offset })
}

///|
fn Mf2SyntaxParser::parse_model_option(
  self : Mf2SyntaxParser,
) -> Result[Mf2ModelOption, Mf2Error] {
  let name = match self.parse_identifier() {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  self.skip_optional_layout()
  if !self.consume('=') {
    return Err(mf2_syntax_error("option requires '='", self.cursor))
  }
  self.skip_optional_layout()
  let value = if self.peek() == Some('$') {
    let variable = match self.parse_variable() {
      Ok(value) => value
      Err(error) => return Err(error)
    }
    Mf2ModelVariable(variable)
  } else {
    let literal = match self.parse_literal() {
      Ok(value) => value
      Err(error) => return Err(error)
    }
    Mf2ModelLiteral(literal)
  }
  Ok({ name, value })
}

///|
fn Mf2SyntaxParser::parse_attribute(
  self : Mf2SyntaxParser,
) -> Result[Mf2ModelAttribute, Mf2Error] {
  if !self.consume('@') {
    return Err(mf2_syntax_error("expected attribute", self.cursor))
  }
  let name = match self.parse_identifier() {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let before_layout = self.cursor
  self.skip_optional_layout()
  let value = if self.consume('=') {
    self.skip_optional_layout()
    Some(
      match self.parse_literal() {
        Ok(value) => value
        Err(error) => return Err(error)
      },
    )
  } else {
    self.cursor = before_layout
    None
  }
  Ok({ name, value })
}

///|
fn replace_mf2_attribute(
  attributes : Array[Mf2ModelAttribute],
  replacement : Mf2ModelAttribute,
) -> Unit {
  for i = 0; i < attributes.length(); i = i + 1 {
    if attributes[i].name == replacement.name {
      attributes[i] = replacement
      return
    }
  }
  attributes.push(replacement)
}

///|
fn Mf2SyntaxParser::parse_variable(
  self : Mf2SyntaxParser,
) -> Result[String, Mf2Error] {
  let offset = self.cursor
  if !self.consume('$') {
    return Err(mf2_syntax_error("expected variable", self.cursor))
  }
  match self.parse_name() {
    Ok(value) => Ok(value)
    Err(_) => Err(mf2_syntax_error("invalid variable name", offset))
  }
}

///|
fn Mf2SyntaxParser::parse_identifier(
  self : Mf2SyntaxParser,
) -> Result[String, Mf2Error] {
  let offset = self.cursor
  let first = match self.parse_name() {
    Ok(value) => value
    Err(_) => return Err(mf2_syntax_error("invalid identifier", offset))
  }
  if self.consume(':') {
    let second = match self.parse_name() {
      Ok(value) => value
      Err(_) =>
        return Err(mf2_syntax_error("invalid namespaced identifier", offset))
    }
    Ok(first + ":" + second)
  } else {
    Ok(first)
  }
}

///|
fn Mf2SyntaxParser::parse_name(
  self : Mf2SyntaxParser,
) -> Result[String, Mf2Error] {
  let offset = self.cursor
  if self.peek().map(is_mf2_bidi).unwrap_or(false) {
    self.cursor = self.cursor + 1
  }
  guard self.peek() is Some(first) && is_mf2_name_start(first) else {
    self.cursor = offset
    return Err(mf2_syntax_error("invalid MF2 name", offset))
  }
  let out = StringBuilder::new()
  out.write_char(first)
  self.cursor = self.cursor + 1
  while self.peek().map(is_mf2_name_char).unwrap_or(false) {
    guard self.peek() is Some(char) else { break }
    out.write_char(char)
    self.cursor = self.cursor + 1
  }
  if self.peek().map(is_mf2_bidi).unwrap_or(false) {
    self.cursor = self.cursor + 1
  }
  Ok(@normalization.nfc(out.to_string()))
}

///|
fn Mf2SyntaxParser::parse_literal(
  self : Mf2SyntaxParser,
) -> Result[String, Mf2Error] {
  if self.peek() == Some('|') {
    self.parse_quoted_literal()
  } else {
    self.parse_unquoted_literal()
  }
}

///|
fn Mf2SyntaxParser::parse_quoted_literal(
  self : Mf2SyntaxParser,
) -> Result[String, Mf2Error] {
  let offset = self.cursor
  if !self.consume('|') {
    return Err(mf2_syntax_error("expected quoted literal", self.cursor))
  }
  let out = StringBuilder::new()
  while self.cursor < self.chars.length() {
    let char = self.chars[self.cursor]
    if char == '|' {
      self.cursor = self.cursor + 1
      return Ok(out.to_string())
    }
    if char == '\\' {
      let escaped = match self.parse_escape() {
        Ok(value) => value
        Err(error) => return Err(error)
      }
      out.write_char(escaped)
    } else {
      out.write_char(char)
      self.cursor = self.cursor + 1
    }
  }
  Err(mf2_syntax_error("unclosed quoted literal", offset))
}

///|
fn Mf2SyntaxParser::parse_unquoted_literal(
  self : Mf2SyntaxParser,
) -> Result[String, Mf2Error] {
  let offset = self.cursor
  let out = StringBuilder::new()
  while self.peek().map(is_mf2_name_char).unwrap_or(false) {
    guard self.peek() is Some(char) else { break }
    out.write_char(char)
    self.cursor = self.cursor + 1
  }
  if out.to_string().is_empty() {
    return Err(mf2_syntax_error("expected literal", offset))
  }
  Ok(out.to_string())
}

///|
fn Mf2SyntaxParser::parse_escape(
  self : Mf2SyntaxParser,
) -> Result[Char, Mf2Error] {
  let offset = self.cursor
  if !self.consume('\\') || self.cursor >= self.chars.length() {
    return Err(mf2_syntax_error("trailing escape", offset))
  }
  let escaped = self.chars[self.cursor]
  if escaped != '\\' && escaped != '{' && escaped != '}' && escaped != '|' {
    return Err(mf2_syntax_error("invalid escape", offset))
  }
  self.cursor = self.cursor + 1
  Ok(escaped)
}

///|
fn Mf2SyntaxParser::peek(self : Mf2SyntaxParser) -> Char? {
  if self.cursor < self.chars.length() {
    Some(self.chars[self.cursor])
  } else {
    None
  }
}

///|
fn Mf2SyntaxParser::consume(self : Mf2SyntaxParser, char : Char) -> Bool {
  if self.peek() == Some(char) {
    self.cursor = self.cursor + 1
    true
  } else {
    false
  }
}

///|
fn Mf2SyntaxParser::starts_with(self : Mf2SyntaxParser, value : String) -> Bool {
  let expected = value.to_array()
  if self.cursor + expected.length() > self.chars.length() {
    return false
  }
  for i = 0; i < expected.length(); i = i + 1 {
    if self.chars[self.cursor + i] != expected[i] {
      return false
    }
  }
  true
}

///|
fn Mf2SyntaxParser::skip_optional_layout(self : Mf2SyntaxParser) -> Unit {
  while self.peek().map(is_mf2_layout).unwrap_or(false) {
    self.cursor = self.cursor + 1
  }
}

///|
fn Mf2SyntaxParser::skip_required_layout(self : Mf2SyntaxParser) -> Bool {
  let start = self.cursor
  while self.peek().map(is_mf2_bidi).unwrap_or(false) {
    self.cursor = self.cursor + 1
  }
  guard self.peek() is Some(char) && is_mf2_whitespace(char) else {
    self.cursor = start
    return false
  }
  self.cursor = self.cursor + 1
  self.skip_optional_layout()
  true
}

///|
fn is_mf2_whitespace(char : Char) -> Bool {
  char == ' ' ||
  char == '\t' ||
  char == '\r' ||
  char == '\n' ||
  char.to_int() == 0x3000
}

///|
fn is_mf2_bidi(char : Char) -> Bool {
  let code = char.to_int()
  code == 0x061c ||
  code == 0x200e ||
  code == 0x200f ||
  (code >= 0x2066 && code <= 0x2069)
}

///|
fn is_mf2_layout(char : Char) -> Bool {
  is_mf2_whitespace(char) || is_mf2_bidi(char)
}

///|
fn is_mf2_name_start(char : Char) -> Bool {
  let code = char.to_int()
  (code >= 0x41 && code <= 0x5a) ||
  (code >= 0x61 && code <= 0x7a) ||
  code == 0x2b ||
  code == 0x5f ||
  (code >= 0x00a1 && code <= 0x061b) ||
  (code >= 0x061d && code <= 0x167f) ||
  (code >= 0x1681 && code <= 0x1fff) ||
  (code >= 0x200b && code <= 0x200d) ||
  (code >= 0x2010 && code <= 0x2027) ||
  (code >= 0x2030 && code <= 0x205e) ||
  (code >= 0x2060 && code <= 0x2065) ||
  (code >= 0x206a && code <= 0x2fff) ||
  (code >= 0x3001 && code <= 0xd7ff) ||
  (code >= 0xe000 && code <= 0xfdcf) ||
  (code >= 0xfdf0 && code <= 0xfffd) ||
  is_mf2_supplementary_name_start(code)
}

///|
fn is_mf2_supplementary_name_start(code : Int) -> Bool {
  code >= 0x10000 && code <= 0x10fffd && (code & 0xffff) <= 0xfffd
}

///|
fn is_mf2_name_char(char : Char) -> Bool {
  is_mf2_name_start(char) ||
  (char >= '0' && char <= '9') ||
  char == '-' ||
  char == '.'
}

///|
fn is_mf2_simple_start_char(char : Char) -> Bool {
  let code = char.to_int()
  code != 0 &&
  !is_mf2_whitespace(char) &&
  code != 0x2e &&
  code != 0x5c &&
  code != 0x7b &&
  code != 0x7d
}

///|
fn mf2_range_has_whitespace(
  chars : Array[Char],
  start : Int,
  end : Int,
) -> Bool {
  for i = start; i < end; i = i + 1 {
    if is_mf2_whitespace(chars[i]) {
      return true
    }
  }
  false
}

///|
/// Applies the pinned MF2 data-model validity rules to a well-formed model.
/// The returned errors are deterministic and ordered by declarations,
/// expressions, then matcher-wide constraints.
pub fn validate_mf2_model(model : Mf2MessageModel) -> Array[Mf2Error] {
  let errors : Array[Mf2Error] = []
  let declarations = match model {
    Mf2PatternMessage(value, _) | Mf2SelectMessage(value, _, _) => value
  }
  validate_mf2_declarations(declarations, errors)
  for declaration in declarations {
    let expression = match declaration {
      Mf2ModelInput(_, value) | Mf2ModelLocal(_, value) => value
    }
    validate_mf2_expression_options(expression, errors)
  }
  match model {
    Mf2PatternMessage(_, pattern) =>
      validate_mf2_pattern_options(pattern, errors)
    Mf2SelectMessage(_, selectors, variants) => {
      for variant in variants {
        validate_mf2_pattern_options(variant.value, errors)
      }
      validate_mf2_matcher(declarations, selectors, variants, errors)
    }
  }
  errors
}

///|
fn validate_mf2_declarations(
  declarations : Array[Mf2ModelDeclaration],
  errors : Array[Mf2Error],
) -> Unit {
  let used_names : Map[String, Bool] = Map([])
  for declaration in declarations {
    let (name, expression) = match declaration {
      Mf2ModelInput(name, value) | Mf2ModelLocal(name, value) => (name, value)
    }
    let references = match declaration {
      Mf2ModelInput(_, value) => mf2_expression_option_variables(value)
      Mf2ModelLocal(_, value) => mf2_expression_variables(value)
    }
    if used_names.contains(name) || references.contains(name) {
      errors.push(
        mf2_model_error(
          Mf2DuplicateDeclarationCode,
          "duplicate declaration or declaration data-flow name: \{name}",
          expression.offset,
        ),
      )
    }
    used_names[name] = true
    for reference in references {
      used_names[reference] = true
    }
  }
}

///|
fn mf2_expression_variables(expression : Mf2ModelExpression) -> Array[String] {
  let variables : Array[String] = []
  match expression.arg {
    Some(Mf2ModelVariable(name)) => variables.push(name)
    _ => ()
  }
  for name in mf2_expression_option_variables(expression) {
    if !variables.contains(name) {
      variables.push(name)
    }
  }
  variables
}

///|
fn mf2_expression_option_variables(
  expression : Mf2ModelExpression,
) -> Array[String] {
  let variables : Array[String] = []
  match expression.function_ref {
    Some(function_ref) =>
      for option in function_ref.options {
        match option.value {
          Mf2ModelVariable(name) =>
            if !variables.contains(name) {
              variables.push(name)
            }
          _ => ()
        }
      }
    None => ()
  }
  variables
}

///|
fn validate_mf2_expression_options(
  expression : Mf2ModelExpression,
  errors : Array[Mf2Error],
) -> Unit {
  match expression.function_ref {
    Some(function_ref) =>
      validate_mf2_option_names(function_ref.options, expression.offset, errors)
    None => ()
  }
}

///|
fn validate_mf2_pattern_options(
  pattern : Mf2ModelPattern,
  errors : Array[Mf2Error],
) -> Unit {
  for part in pattern.parts {
    match part {
      Mf2ModelExpressionPart(expression) =>
        validate_mf2_expression_options(expression, errors)
      Mf2ModelMarkupPart(markup) =>
        validate_mf2_option_names(markup.options, markup.offset, errors)
      Mf2ModelText(_) => ()
    }
  }
}

///|
fn validate_mf2_option_names(
  options : Array[Mf2ModelOption],
  offset : Int,
  errors : Array[Mf2Error],
) -> Unit {
  let names : Map[String, Bool] = Map([])
  for option in options {
    let canonical = @normalization.nfc(option.name)
    if names.contains(canonical) {
      errors.push(
        mf2_model_error(
          Mf2DuplicateOptionNameCode,
          "duplicate NFC-equivalent option name: \{option.name}",
          offset,
        ),
      )
    } else {
      names[canonical] = true
    }
  }
}

///|
fn validate_mf2_matcher(
  declarations : Array[Mf2ModelDeclaration],
  selectors : Array[String],
  variants : Array[Mf2ModelVariant],
  errors : Array[Mf2Error],
) -> Unit {
  let mut has_fallback = false
  let signatures : Map[String, Bool] = Map([])
  for variant in variants {
    if variant.keys.length() != selectors.length() {
      errors.push(
        mf2_model_error(
          Mf2VariantKeyMismatchCode,
          "variant key count does not match selector count",
          variant.offset,
        ),
      )
    }
    if variant.keys.length() == selectors.length() &&
      variant.keys.all(key => key is Mf2ModelCatchallKey) {
      has_fallback = true
    }
    let signature = variant.keys
      .map(key => {
        match key {
          Mf2ModelCatchallKey => "*"
          Mf2ModelLiteralKey(value) => {
            let canonical = @normalization.nfc(value)
            "l\{canonical.length()}:\{canonical}"
          }
        }
      })
      .join("\u{1f}")
    if signatures.contains(signature) {
      errors.push(
        mf2_model_error(
          Mf2DuplicateVariantCode,
          "duplicate NFC-equivalent matcher variant",
          variant.offset,
        ),
      )
    } else {
      signatures[signature] = true
    }
  }
  if !has_fallback {
    errors.push(
      mf2_model_error(
        Mf2MissingFallbackVariantCode,
        "matcher requires an all-catch-all fallback variant",
        if variants.is_empty() {
          0
        } else {
          variants[0].offset
        },
      ),
    )
  }
  for selector in selectors {
    if !mf2_selector_is_annotated(selector, declarations, []) {
      errors.push(
        mf2_model_error(
          Mf2MissingSelectorAnnotationCode,
          "selector requires a function-annotated declaration: \{selector}",
          0,
        ),
      )
    }
  }
}

///|
fn mf2_selector_is_annotated(
  name : String,
  declarations : Array[Mf2ModelDeclaration],
  visited : Array[String],
) -> Bool {
  if visited.contains(name) {
    return false
  }
  let next_visited = visited.copy()
  next_visited.push(name)
  for declaration in declarations {
    let (declared_name, expression) = match declaration {
      Mf2ModelInput(declared_name, expression)
      | Mf2ModelLocal(declared_name, expression) => (declared_name, expression)
    }
    if declared_name == name {
      if expression.function_ref is Some(_) {
        return true
      }
      match expression.arg {
        Some(Mf2ModelVariable(reference)) =>
          return mf2_selector_is_annotated(
            reference, declarations, next_visited,
          )
        _ => return false
      }
    }
  }
  false
}

///|
/// Serializes a valid MF2 interchange model into deterministic, compact MF2
/// syntax. Pattern messages are emitted as quoted patterns so their leading
/// content can never be confused with a complex-message keyword.
pub fn serialize_mf2_model(
  model : Mf2MessageModel,
) -> Result[String, Array[Mf2Error]] {
  let errors = validate_mf2_model_shape(model)
  for error in validate_mf2_model(model) {
    errors.push(error)
  }
  if !errors.is_empty() {
    return Err(errors)
  }
  let out = StringBuilder::new()
  match model {
    Mf2PatternMessage(declarations, pattern) => {
      write_mf2_declarations(out, declarations)
      write_mf2_quoted_pattern(out, pattern)
    }
    Mf2SelectMessage(declarations, selectors, variants) => {
      write_mf2_declarations(out, declarations)
      out.write_string(".match ")
      for i = 0; i < selectors.length(); i = i + 1 {
        if i > 0 {
          out.write_char(' ')
        }
        out.write_char('$')
        out.write_string(selectors[i])
      }
      out.write_char('\n')
      for i = 0; i < variants.length(); i = i + 1 {
        if i > 0 {
          out.write_char('\n')
        }
        for j = 0; j < variants[i].keys.length(); j = j + 1 {
          if j > 0 {
            out.write_char(' ')
          }
          match variants[i].keys[j] {
            Mf2ModelCatchallKey => out.write_char('*')
            Mf2ModelLiteralKey(value) => write_mf2_literal(out, value)
          }
        }
        out.write_char(' ')
        write_mf2_quoted_pattern(out, variants[i].value)
      }
    }
  }
  let serialized = out.to_string()
  if @utf8.encode(serialized).length() > MF2_MAX_MESSAGE_BYTES {
    Err([
      {
        kind: Mf2LimitError,
        code: Mf2LimitCode,
        message: "serialized message exceeds the \{MF2_MAX_MESSAGE_BYTES}-byte limit",
        offset: 0,
      },
    ])
  } else {
    Ok(serialized)
  }
}

///|
fn write_mf2_declarations(
  out : StringBuilder,
  declarations : Array[Mf2ModelDeclaration],
) -> Unit {
  for declaration in declarations {
    match declaration {
      Mf2ModelInput(_, expression) => {
        out.write_string(".input ")
        write_mf2_expression(out, expression)
      }
      Mf2ModelLocal(name, expression) => {
        out.write_string(".local $")
        out.write_string(name)
        out.write_string(" = ")
        write_mf2_expression(out, expression)
      }
    }
    out.write_char('\n')
  }
}

///|
fn write_mf2_quoted_pattern(
  out : StringBuilder,
  pattern : Mf2ModelPattern,
) -> Unit {
  out.write_string("{{")
  write_mf2_pattern(out, pattern)
  out.write_string("}}")
}

///|
fn write_mf2_pattern(out : StringBuilder, pattern : Mf2ModelPattern) -> Unit {
  for part in pattern.parts {
    match part {
      Mf2ModelText(value) =>
        for char in value.to_array() {
          if char == '\\' || char == '{' || char == '}' {
            out.write_char('\\')
          }
          out.write_char(char)
        }
      Mf2ModelExpressionPart(expression) =>
        write_mf2_expression(out, expression)
      Mf2ModelMarkupPart(markup) => write_mf2_markup(out, markup)
    }
  }
}

///|
fn write_mf2_expression(
  out : StringBuilder,
  expression : Mf2ModelExpression,
) -> Unit {
  out.write_char('{')
  match expression.arg {
    Some(Mf2ModelLiteral(value)) => write_mf2_literal(out, value)
    Some(Mf2ModelVariable(name)) => {
      out.write_char('$')
      out.write_string(name)
    }
    None => ()
  }
  match expression.function_ref {
    Some(function_ref) => {
      if expression.arg is Some(_) {
        out.write_char(' ')
      }
      out.write_char(':')
      out.write_string(function_ref.name)
      write_mf2_options(out, function_ref.options)
    }
    None => ()
  }
  write_mf2_attributes(out, expression.attributes)
  out.write_char('}')
}

///|
fn write_mf2_markup(out : StringBuilder, markup : Mf2ModelMarkup) -> Unit {
  out.write_char('{')
  match markup.kind {
    Mf2MarkupOpen | Mf2MarkupStandalone => out.write_char('#')
    Mf2MarkupClose => out.write_char('/')
  }
  out.write_string(markup.name)
  write_mf2_options(out, markup.options)
  write_mf2_attributes(out, markup.attributes)
  if markup.kind == Mf2MarkupStandalone {
    out.write_string(" /")
  }
  out.write_char('}')
}

///|
fn write_mf2_options(
  out : StringBuilder,
  options : Array[Mf2ModelOption],
) -> Unit {
  let sorted = options.copy()
  sorted.sort_by((left, right) => left.name.lexical_compare(right.name))
  for option in sorted {
    out.write_char(' ')
    out.write_string(option.name)
    out.write_char('=')
    match option.value {
      Mf2ModelLiteral(value) => write_mf2_literal(out, value)
      Mf2ModelVariable(name) => {
        out.write_char('$')
        out.write_string(name)
      }
    }
  }
}

///|
fn write_mf2_attributes(
  out : StringBuilder,
  attributes : Array[Mf2ModelAttribute],
) -> Unit {
  let sorted = attributes.copy()
  sorted.sort_by((left, right) => left.name.lexical_compare(right.name))
  for attribute in sorted {
    out.write_string(" @")
    out.write_string(attribute.name)
    match attribute.value {
      Some(value) => {
        out.write_char('=')
        write_mf2_literal(out, value)
      }
      None => ()
    }
  }
}

///|
fn write_mf2_literal(out : StringBuilder, value : String) -> Unit {
  if valid_mf2_unquoted_model_literal(value) {
    out.write_string(value)
  } else {
    out.write_char('|')
    for char in value.to_array() {
      if char == '\\' || char == '|' {
        out.write_char('\\')
      }
      out.write_char(char)
    }
    out.write_char('|')
  }
}

///|
fn valid_mf2_unquoted_model_literal(value : String) -> Bool {
  let chars = value.to_array()
  !chars.is_empty() && chars.all(is_mf2_name_char)
}

///|
fn validate_mf2_model_shape(model : Mf2MessageModel) -> Array[Mf2Error] {
  let errors : Array[Mf2Error] = []
  let declarations = match model {
    Mf2PatternMessage(value, _) | Mf2SelectMessage(value, _, _) => value
  }
  if declarations.length() > MF2_MAX_DECLARATIONS {
    errors.push({
      kind: Mf2LimitError,
      code: Mf2LimitCode,
      message: "message model exceeds the declaration limit",
      offset: 0,
    })
  }
  for declaration in declarations {
    match declaration {
      Mf2ModelInput(name, expression) => {
        validate_mf2_model_name(name, false, expression.offset, errors)
        if expression.arg != Some(Mf2ModelVariable(name)) {
          errors.push(
            mf2_model_error(
              Mf2DataModelCode,
              "input declaration name must equal its variable operand",
              expression.offset,
            ),
          )
        }
        validate_mf2_expression_shape(expression, errors)
      }
      Mf2ModelLocal(name, expression) => {
        validate_mf2_model_name(name, false, expression.offset, errors)
        validate_mf2_expression_shape(expression, errors)
      }
    }
  }
  match model {
    Mf2PatternMessage(_, pattern) => validate_mf2_pattern_shape(pattern, errors)
    Mf2SelectMessage(_, selectors, variants) => {
      if selectors.is_empty() {
        errors.push(
          mf2_model_error(
            Mf2DataModelCode,
            "select message requires at least one selector",
            0,
          ),
        )
      } else if selectors.length() > MF2_MAX_SELECTORS {
        errors.push({
          kind: Mf2LimitError,
          code: Mf2LimitCode,
          message: "message model exceeds the selector limit",
          offset: 0,
        })
      }
      if variants.length() > MF2_MAX_VARIANTS {
        errors.push({
          kind: Mf2LimitError,
          code: Mf2LimitCode,
          message: "message model exceeds the variant limit",
          offset: 0,
        })
      }
      for selector in selectors {
        validate_mf2_model_name(selector, false, 0, errors)
      }
      for variant in variants {
        for key in variant.keys {
          match key {
            Mf2ModelLiteralKey(value) =>
              validate_mf2_model_string(value, variant.offset, errors)
            Mf2ModelCatchallKey => ()
          }
        }
        validate_mf2_pattern_shape(variant.value, errors)
      }
    }
  }
  errors
}

///|
fn validate_mf2_expression_shape(
  expression : Mf2ModelExpression,
  errors : Array[Mf2Error],
) -> Unit {
  if expression.arg is None && expression.function_ref is None {
    errors.push(
      mf2_model_error(
        Mf2DataModelCode,
        "expression requires an operand or function",
        expression.offset,
      ),
    )
  }
  match expression.arg {
    Some(Mf2ModelLiteral(value)) =>
      validate_mf2_model_string(value, expression.offset, errors)
    Some(Mf2ModelVariable(name)) =>
      validate_mf2_model_name(name, false, expression.offset, errors)
    None => ()
  }
  match expression.function_ref {
    Some(function_ref) => {
      validate_mf2_model_name(
        function_ref.name,
        true,
        expression.offset,
        errors,
      )
      validate_mf2_model_options(
        function_ref.options,
        expression.offset,
        errors,
      )
    }
    None => ()
  }
  validate_mf2_model_attributes(
    expression.attributes,
    expression.offset,
    errors,
  )
}

///|
fn validate_mf2_pattern_shape(
  pattern : Mf2ModelPattern,
  errors : Array[Mf2Error],
) -> Unit {
  if pattern.parts.length() > MF2_MAX_PATTERN_PARTS {
    errors.push({
      kind: Mf2LimitError,
      code: Mf2LimitCode,
      message: "message model exceeds the pattern-part limit",
      offset: 0,
    })
  }
  for part in pattern.parts {
    match part {
      Mf2ModelText(value) => {
        if value.is_empty() {
          errors.push(
            mf2_model_error(
              Mf2DataModelCode,
              "pattern text parts must be non-empty",
              0,
            ),
          )
        }
        validate_mf2_model_string(value, 0, errors)
      }
      Mf2ModelExpressionPart(expression) =>
        validate_mf2_expression_shape(expression, errors)
      Mf2ModelMarkupPart(markup) => {
        validate_mf2_model_name(markup.name, true, markup.offset, errors)
        validate_mf2_model_options(markup.options, markup.offset, errors)
        validate_mf2_model_attributes(markup.attributes, markup.offset, errors)
      }
    }
  }
}

///|
fn validate_mf2_model_options(
  options : Array[Mf2ModelOption],
  offset : Int,
  errors : Array[Mf2Error],
) -> Unit {
  if options.length() > MF2_MAX_OPTIONS {
    errors.push({
      kind: Mf2LimitError,
      code: Mf2LimitCode,
      message: "model expression exceeds the option limit",
      offset,
    })
  }
  for option in options {
    validate_mf2_model_name(option.name, true, offset, errors)
    match option.value {
      Mf2ModelLiteral(value) => validate_mf2_model_string(value, offset, errors)
      Mf2ModelVariable(name) =>
        validate_mf2_model_name(name, false, offset, errors)
    }
  }
}

///|
fn validate_mf2_model_attributes(
  attributes : Array[Mf2ModelAttribute],
  offset : Int,
  errors : Array[Mf2Error],
) -> Unit {
  for attribute in attributes {
    validate_mf2_model_name(attribute.name, true, offset, errors)
    match attribute.value {
      Some(value) => validate_mf2_model_string(value, offset, errors)
      None => ()
    }
  }
}

///|
fn validate_mf2_model_name(
  value : String,
  identifier : Bool,
  offset : Int,
  errors : Array[Mf2Error],
) -> Unit {
  let parser = Mf2SyntaxParser::{ chars: value.to_array(), cursor: 0 }
  let parsed = if identifier {
    parser.parse_identifier()
  } else {
    parser.parse_name()
  }
  if parsed != Ok(@normalization.nfc(value)) ||
    parser.cursor != parser.chars.length() {
    errors.push(
      mf2_model_error(
        Mf2DataModelCode,
        "invalid or non-canonical MF2 model name: \{value}",
        offset,
      ),
    )
  }
}

///|
fn validate_mf2_model_string(
  value : String,
  offset : Int,
  errors : Array[Mf2Error],
) -> Unit {
  if value.to_array().any(char => char.to_int() == 0) {
    errors.push(
      mf2_model_error(
        Mf2DataModelCode,
        "MF2 model strings must not contain U+0000",
        offset,
      ),
    )
  }
}

///|
/// Encodes a valid MF2 interchange model as deterministic JSON matching the
/// pinned normative field names. Extension fields such as source offsets are
/// deliberately omitted.
pub fn mf2_model_to_json(
  model : Mf2MessageModel,
) -> Result[String, Array[Mf2Error]] {
  match serialize_mf2_model(model) {
    Ok(_) => ()
    Err(errors) => return Err(errors)
  }
  Ok(mf2_model_json(model).stringify(indent=2) + "\n")
}

///|
/// Decodes and validates JSON using the pinned normative MF2 interchange data
/// model. Unknown object fields are ignored as required by the model's
/// extension rule.
#warnings("-deprecated")
pub fn parse_mf2_model_json(source : String) -> Result[Mf2MessageModel, String] {
  if @utf8.encode(source).length() > CATALOG_MAX_SOURCE_BYTES {
    return Err("MF2 data-model JSON exceeds the input size limit")
  }
  let json = try @json.parse(source, max_nesting_depth=64) catch {
    _ => return Err("invalid MF2 data-model JSON")
  } noraise {
    value => value
  }
  let model = match parse_mf2_model_json_value(json) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  match serialize_mf2_model(model) {
    Ok(_) => Ok(model)
    Err(errors) => Err(errors[0].message)
  }
}

///|
fn mf2_model_json(model : Mf2MessageModel) -> Json {
  match model {
    Mf2PatternMessage(declarations, pattern) =>
      Json::object({
        "type": Json::string("message"),
        "declarations": Json::array(declarations.map(mf2_declaration_json)),
        "pattern": mf2_pattern_json(pattern),
      })
    Mf2SelectMessage(declarations, selectors, variants) =>
      Json::object({
        "type": Json::string("select"),
        "declarations": Json::array(declarations.map(mf2_declaration_json)),
        "selectors": Json::array(
          selectors.map(name => mf2_value_json(Mf2ModelVariable(name))),
        ),
        "variants": Json::array(
          variants.map(variant => {
            Json::object({
              "keys": Json::array(
                variant.keys.map(key => {
                  match key {
                    Mf2ModelLiteralKey(value) =>
                      mf2_value_json(Mf2ModelLiteral(value))
                    Mf2ModelCatchallKey =>
                      Json::object({ "type": Json::string("*") })
                  }
                }),
              ),
              "value": mf2_pattern_json(variant.value),
            })
          }),
        ),
      })
  }
}

///|
fn mf2_declaration_json(declaration : Mf2ModelDeclaration) -> Json {
  match declaration {
    Mf2ModelInput(name, value) =>
      Json::object({
        "type": Json::string("input"),
        "name": Json::string(name),
        "value": mf2_expression_json(value),
      })
    Mf2ModelLocal(name, value) =>
      Json::object({
        "type": Json::string("local"),
        "name": Json::string(name),
        "value": mf2_expression_json(value),
      })
  }
}

///|
fn mf2_pattern_json(pattern : Mf2ModelPattern) -> Json {
  Json::array(
    pattern.parts.map(part => {
      match part {
        Mf2ModelText(value) => Json::string(value)
        Mf2ModelExpressionPart(value) => mf2_expression_json(value)
        Mf2ModelMarkupPart(value) => mf2_markup_json(value)
      }
    }),
  )
}

///|
fn mf2_expression_json(expression : Mf2ModelExpression) -> Json {
  let obj : Map[String, Json] = {
    "type": Json::string("expression"),
    "attributes": mf2_attributes_json(expression.attributes),
  }
  match expression.arg {
    Some(value) => obj["arg"] = mf2_value_json(value)
    None => ()
  }
  match expression.function_ref {
    Some(value) => obj["function"] = mf2_function_json(value)
    None => ()
  }
  Json::object(obj)
}

///|
fn mf2_markup_json(markup : Mf2ModelMarkup) -> Json {
  let kind = match markup.kind {
    Mf2MarkupOpen => "open"
    Mf2MarkupStandalone => "standalone"
    Mf2MarkupClose => "close"
  }
  Json::object({
    "type": Json::string("markup"),
    "kind": Json::string(kind),
    "name": Json::string(markup.name),
    "options": mf2_options_json(markup.options),
    "attributes": mf2_attributes_json(markup.attributes),
  })
}

///|
fn mf2_function_json(function_ref : Mf2ModelFunction) -> Json {
  Json::object({
    "type": Json::string("function"),
    "name": Json::string(function_ref.name),
    "options": mf2_options_json(function_ref.options),
  })
}

///|
fn mf2_value_json(value : Mf2ModelValue) -> Json {
  match value {
    Mf2ModelLiteral(value) =>
      Json::object({
        "type": Json::string("literal"),
        "value": Json::string(value),
      })
    Mf2ModelVariable(name) =>
      Json::object({
        "type": Json::string("variable"),
        "name": Json::string(name),
      })
  }
}

///|
fn mf2_options_json(options : Array[Mf2ModelOption]) -> Json {
  let obj : Map[String, Json] = Map([])
  let sorted = options.copy()
  sorted.sort_by((left, right) => left.name.lexical_compare(right.name))
  for option in sorted {
    obj[option.name] = mf2_value_json(option.value)
  }
  Json::object(obj)
}

///|
fn mf2_attributes_json(attributes : Array[Mf2ModelAttribute]) -> Json {
  let obj : Map[String, Json] = Map([])
  let sorted = attributes.copy()
  sorted.sort_by((left, right) => left.name.lexical_compare(right.name))
  for attribute in sorted {
    obj[attribute.name] = match attribute.value {
      Some(value) => mf2_value_json(Mf2ModelLiteral(value))
      None => Json::boolean(true)
    }
  }
  Json::object(obj)
}

///|
fn parse_mf2_model_json_value(json : Json) -> Result[Mf2MessageModel, String] {
  guard json is Object(obj) else {
    return Err("MF2 data-model root must be an object")
  }
  let typ = match obj.get("type") {
    Some(String(value)) => value
    _ => return Err("MF2 data-model message type must be a string")
  }
  let declarations = match obj.get("declarations") {
    Some(Array(values)) => {
      let parsed : Array[Mf2ModelDeclaration] = []
      for value in values {
        match parse_mf2_declaration_json(value) {
          Ok(value) => parsed.push(value)
          Err(message) => return Err(message)
        }
      }
      parsed
    }
    None => []
    _ => return Err("MF2 data-model declarations must be an array")
  }
  match typ {
    "message" => {
      let pattern = match obj.get("pattern") {
        Some(value) =>
          match parse_mf2_pattern_json(value) {
            Ok(value) => value
            Err(message) => return Err(message)
          }
        None => return Err("MF2 pattern message is missing pattern")
      }
      Ok(Mf2PatternMessage(declarations, pattern))
    }
    "select" => {
      let selectors : Array[String] = []
      match obj.get("selectors") {
        Some(Array(values)) =>
          for value in values {
            match parse_mf2_value_json(value) {
              Ok(Mf2ModelVariable(name)) => selectors.push(name)
              Ok(_) => return Err("MF2 selector must be a variable reference")
              Err(message) => return Err(message)
            }
          }
        _ => return Err("MF2 select message selectors must be an array")
      }
      let variants : Array[Mf2ModelVariant] = []
      match obj.get("variants") {
        Some(Array(values)) =>
          for value in values {
            match parse_mf2_variant_json(value) {
              Ok(value) => variants.push(value)
              Err(message) => return Err(message)
            }
          }
        _ => return Err("MF2 select message variants must be an array")
      }
      Ok(Mf2SelectMessage(declarations, selectors, variants))
    }
    _ => Err("unsupported MF2 data-model message type: " + typ)
  }
}

///|
fn parse_mf2_declaration_json(
  json : Json,
) -> Result[Mf2ModelDeclaration, String] {
  guard json is Object(obj) else {
    return Err("MF2 declaration must be an object")
  }
  let typ = match obj.get("type") {
    Some(String(value)) => value
    _ => return Err("MF2 declaration type must be a string")
  }
  let name = match obj.get("name") {
    Some(String(value)) => value
    _ => return Err("MF2 declaration name must be a string")
  }
  let value = match obj.get("value") {
    Some(value) =>
      match parse_mf2_expression_json(value) {
        Ok(value) => value
        Err(message) => return Err(message)
      }
    None => return Err("MF2 declaration is missing value")
  }
  match typ {
    "input" => Ok(Mf2ModelInput(name, value))
    "local" => Ok(Mf2ModelLocal(name, value))
    _ => Err("unsupported MF2 declaration type: " + typ)
  }
}

///|
fn parse_mf2_pattern_json(json : Json) -> Result[Mf2ModelPattern, String] {
  guard json is Array(values) else {
    return Err("MF2 pattern must be an array")
  }
  let parts : Array[Mf2ModelPatternPart] = []
  for value in values {
    match value {
      String(text) => parts.push(Mf2ModelText(text))
      Object(obj) =>
        match obj.get("type") {
          Some(String("expression")) =>
            match parse_mf2_expression_json(value) {
              Ok(value) => parts.push(Mf2ModelExpressionPart(value))
              Err(message) => return Err(message)
            }
          Some(String("markup")) =>
            match parse_mf2_markup_json(value) {
              Ok(value) => parts.push(Mf2ModelMarkupPart(value))
              Err(message) => return Err(message)
            }
          _ => return Err("unsupported MF2 pattern object type")
        }
      _ => return Err("MF2 pattern parts must be strings or objects")
    }
  }
  Ok({ parts, })
}

///|
fn parse_mf2_expression_json(json : Json) -> Result[Mf2ModelExpression, String] {
  guard json is Object(obj) && obj.get("type") is Some(String("expression")) else {
    return Err("MF2 expression must be an expression object")
  }
  let arg = match obj.get("arg") {
    Some(value) =>
      Some(
        match parse_mf2_value_json(value) {
          Ok(value) => value
          Err(message) => return Err(message)
        },
      )
    None => None
  }
  let function_ref = match obj.get("function") {
    Some(value) =>
      Some(
        match parse_mf2_function_json(value) {
          Ok(value) => value
          Err(message) => return Err(message)
        },
      )
    None => None
  }
  let attributes = match parse_mf2_attributes_json(obj.get("attributes")) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  Ok({ arg, function_ref, attributes, offset: 0 })
}

///|
fn parse_mf2_markup_json(json : Json) -> Result[Mf2ModelMarkup, String] {
  guard json is Object(obj) && obj.get("type") is Some(String("markup")) else {
    return Err("MF2 markup must be a markup object")
  }
  let kind = match obj.get("kind") {
    Some(String("open")) => Mf2MarkupOpen
    Some(String("standalone")) => Mf2MarkupStandalone
    Some(String("close")) => Mf2MarkupClose
    _ => return Err("MF2 markup kind must be open, standalone, or close")
  }
  let name = match obj.get("name") {
    Some(String(value)) => value
    _ => return Err("MF2 markup name must be a string")
  }
  let options = match parse_mf2_options_json(obj.get("options")) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let attributes = match parse_mf2_attributes_json(obj.get("attributes")) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  Ok({ kind, name, options, attributes, offset: 0 })
}

///|
fn parse_mf2_function_json(json : Json) -> Result[Mf2ModelFunction, String] {
  guard json is Object(obj) && obj.get("type") is Some(String("function")) else {
    return Err("MF2 function must be a function object")
  }
  let name = match obj.get("name") {
    Some(String(value)) => value
    _ => return Err("MF2 function name must be a string")
  }
  let options = match parse_mf2_options_json(obj.get("options")) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  Ok({ name, options })
}

///|
fn parse_mf2_value_json(json : Json) -> Result[Mf2ModelValue, String] {
  guard json is Object(obj) else {
    return Err("MF2 literal or variable must be an object")
  }
  match obj.get("type") {
    Some(String("literal")) =>
      match obj.get("value") {
        Some(String(value)) => Ok(Mf2ModelLiteral(value))
        _ => Err("MF2 literal value must be a string")
      }
    Some(String("variable")) =>
      match obj.get("name") {
        Some(String(value)) => Ok(Mf2ModelVariable(value))
        _ => Err("MF2 variable name must be a string")
      }
    _ => Err("unsupported MF2 literal or variable type")
  }
}

///|
fn parse_mf2_options_json(
  json : Json?,
) -> Result[Array[Mf2ModelOption], String] {
  let options : Array[Mf2ModelOption] = []
  match json {
    None => return Ok(options)
    Some(Object(obj)) =>
      for pair in obj.iter() {
        let value = match parse_mf2_value_json(pair.1) {
          Ok(value) => value
          Err(message) => return Err(message)
        }
        options.push({ name: pair.0, value })
      }
    _ => return Err("MF2 options must be an object")
  }
  options.sort_by((left, right) => left.name.lexical_compare(right.name))
  Ok(options)
}

///|
fn parse_mf2_attributes_json(
  json : Json?,
) -> Result[Array[Mf2ModelAttribute], String] {
  let attributes : Array[Mf2ModelAttribute] = []
  match json {
    None => return Ok(attributes)
    Some(Object(obj)) =>
      for pair in obj.iter() {
        let value = match pair.1 {
          True => None
          value =>
            match parse_mf2_value_json(value) {
              Ok(Mf2ModelLiteral(value)) => Some(value)
              Ok(_) =>
                return Err("MF2 attribute values must be literals or true")
              Err(message) => return Err(message)
            }
        }
        attributes.push({ name: pair.0, value })
      }
    _ => return Err("MF2 attributes must be an object")
  }
  attributes.sort_by((left, right) => left.name.lexical_compare(right.name))
  Ok(attributes)
}

///|
fn parse_mf2_variant_json(json : Json) -> Result[Mf2ModelVariant, String] {
  guard json is Object(obj) else { return Err("MF2 variant must be an object") }
  let keys : Array[Mf2ModelVariantKey] = []
  match obj.get("keys") {
    Some(Array(values)) =>
      for value in values {
        match value {
          Object(key) if key.get("type") is Some(String("*")) =>
            keys.push(Mf2ModelCatchallKey)
          _ =>
            match parse_mf2_value_json(value) {
              Ok(Mf2ModelLiteral(value)) => keys.push(Mf2ModelLiteralKey(value))
              Ok(_) =>
                return Err("MF2 variant key must be a literal or catch-all")
              Err(message) => return Err(message)
            }
        }
      }
    _ => return Err("MF2 variant keys must be an array")
  }
  let value = match obj.get("value") {
    Some(value) =>
      match parse_mf2_pattern_json(value) {
        Ok(value) => value
        Err(message) => return Err(message)
      }
    None => return Err("MF2 variant is missing value")
  }
  Ok({ keys, value, offset: 0 })
}
