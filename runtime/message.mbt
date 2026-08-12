///|
/// Maximum UTF-8 size accepted for one MF2 message.
pub const MF2_MAX_MESSAGE_BYTES : Int = 65536

///|
/// Maximum number of declarations accepted in one MF2 message.
pub const MF2_MAX_DECLARATIONS : Int = 4096

///|
/// Maximum number of matcher variants accepted in one MF2 message.
pub const MF2_MAX_VARIANTS : Int = 4096

///|
/// Maximum parameter count accepted by a message contract.
pub const MF2_MAX_CONTRACT_PARAMS : Int = 64

///|
/// Maximum rich-markup tag count accepted by a message contract.
pub const MF2_MAX_CONTRACT_TAGS : Int = 64

///|
/// Maximum number of arguments accepted by a formatting operation.
pub const MF2_MAX_ARGUMENTS : Int = 64

///|
/// Maximum options accepted on one expression or markup element.
pub const MF2_MAX_OPTIONS : Int = 64

///|
/// Typed values that may be supplied to an MF2 message.
pub(all) enum MessageValue {
  /// A Unicode string value.
  TextValue(String)
  /// A signed integer value.
  IntValue(Int)
  /// A floating-point number value.
  DoubleValue(Double)
  /// A Boolean value.
  BoolValue(Bool)
  /// An instant represented as Unix epoch milliseconds.
  InstantMillis(Int64)
} derive(Eq, Debug)

///|
/// A named, typed argument supplied to a message.
pub(all) struct MessageArg {
  /// Parameter name without the leading MF2 `$` marker.
  name : String
  /// Parameter value.
  value : MessageValue
} derive(Eq, Debug)

///|
/// A resolved name/value option passed to a formatter or markup renderer.
pub(all) struct FormatOption {
  /// Option name without its leading `@` or `u:` syntax.
  name : String
  /// Resolved option value.
  value : String
} derive(Eq, Debug)

///|
/// Failure reported by a platform formatter implementation.
pub(all) enum FormatterIssue {
  /// The selected backend does not implement the requested operation.
  UnsupportedOperation(String)
  /// An option name or value is invalid for the formatter.
  InvalidFormatterOption(String)
  /// The platform formatter raised or returned an operational failure.
  PlatformFormatterFailure(String)
} derive(Eq, Debug)

///|
/// Returns the human-readable detail carried by this formatter issue.
pub fn FormatterIssue::message(self : FormatterIssue) -> String {
  match self {
    UnsupportedOperation(message)
    | InvalidFormatterOption(message)
    | PlatformFormatterFailure(message) => message
  }
}

///|
/// Platform formatting callbacks used by the MF2 evaluator.
pub(all) struct Formatter {
  /// Formats a numeric value for a locale and resolved options.
  format_number : (String, Double, Array[FormatOption]) -> Result[
    String,
    FormatterIssue,
  ]
  /// Formats Unix epoch milliseconds for a locale and resolved options.
  format_datetime : (String, Int64, Array[FormatOption]) -> Result[
    String,
    FormatterIssue,
  ]
  /// Selects a CLDR plural category for a locale and numeric value.
  plural_category : (String, Double, Bool) -> Result[String, FormatterIssue]
}

///|
/// Creates the portable formatter with basic numbers and explicit CLDR gaps.
pub fn Formatter::basic() -> Formatter {
  {
    format_number: (_locale, value, options) => {
      let integer = option_value(options, "integer") == Some("true")
      if integer {
        Ok(value.trunc().to_string())
      } else {
        Ok(value.to_string())
      }
    },
    format_datetime: (_locale, _value, _options) => {
      Err(
        UnsupportedOperation(
          "date/time formatting requires a platform formatter",
        ),
      )
    },
    plural_category: (_locale, _value, _ordinal) => {
      Err(
        UnsupportedOperation(
          "plural selection requires a CLDR-capable platform formatter",
        ),
      )
    },
  }
}

///|
/// Stable category assigned to a compile or formatting failure.
pub(all) enum Mf2ErrorKind {
  /// The input does not match the supported MF2 grammar.
  Mf2SyntaxError
  /// The parsed message violates the supported MF2 data model.
  Mf2DataModelError
  /// An operand, declaration, selector, or option cannot be resolved.
  Mf2ResolutionError
  /// A resolved value cannot be formatted by the selected formatter.
  Mf2FormattingError
  /// A configured resource limit was exceeded.
  Mf2LimitError
} derive(Eq, Debug)

///|
/// Structured MF2 failure with a source offset.
pub(all) struct Mf2Error {
  /// Stable error category.
  kind : Mf2ErrorKind
  /// Human-readable diagnostic detail.
  message : String
  /// Character offset associated with the failure.
  offset : Int
} derive(Eq, Debug)

///|
/// Formats this error as a compact message with its source offset.
pub fn Mf2Error::to_string(self : Mf2Error) -> String {
  "\{self.message} (offset \{self.offset})"
}

///|
/// One declared parameter in a generated message contract.
pub(all) struct MessageParamSpec {
  /// Parameter name without the leading MF2 `$` marker.
  name : String
  /// Generator type name such as `String`, `Int`, or `InstantMillis`.
  typ : String
} derive(Eq, Debug)

///|
/// Parameters and rich-markup names allowed while compiling a message.
pub(all) struct MessageContract {
  /// Declared parameter names and types.
  params : Array[MessageParamSpec]
  /// Markup tag names allowed in the message.
  allowed_tags : Array[String]
  /// Whether the compiler must enforce this contract.
  enforce : Bool
} derive(Eq, Debug)

///|
/// Creates a permissive contract for low-level runtime integration.
pub fn MessageContract::open() -> MessageContract {
  { params: [], allowed_tags: [], enforce: false }
}

///|
/// Creates an enforced contract with typed parameters and allowed markup.
pub fn MessageContract::new(
  params : Array[MessageParamSpec],
  allowed_tags? : Array[String] = [],
) -> MessageContract {
  { params, allowed_tags, enforce: true }
}

///|
/// One item in structured rich-message output.
pub(all) enum MessagePart {
  /// Plain text content.
  Text(String)
  /// Opening markup with resolved options.
  Open(String, Array[FormatOption])
  /// Closing markup.
  Close(String)
  /// Standalone markup with resolved options.
  Standalone(String, Array[FormatOption])
} derive(Eq, Debug)

///|
/// Operand stored in the compiled MF2 data model.
pub enum Operand {
  /// A reference to a variable binding.
  VariableOperand(String)
  /// A quoted or unquoted literal.
  LiteralOperand(String)
} derive(Eq, Debug)

///|
/// Option value stored in the compiled MF2 data model.
pub enum OptionExpression {
  /// A literal option value.
  LiteralOption(String)
  /// An option value resolved from a variable binding.
  VariableOption(String)
} derive(Eq, Debug)

///|
/// Parsed, unresolved option in a compiled expression or markup node.
pub struct ParsedOption {
  name : String
  value : OptionExpression
} derive(Eq, Debug)

///|
/// Compiled MF2 expression with its operand, function, options, and offset.
pub struct Expression {
  operand : Operand
  function_name : String
  options : Array[ParsedOption]
  offset : Int
} derive(Eq, Debug)

///|
/// Node in a compiled MF2 pattern.
pub enum PatternNode {
  /// Literal pattern text.
  PatternText(String)
  /// Expression whose result is inserted into the pattern.
  PatternExpression(Expression)
  /// Opening markup node.
  PatternOpen(String, Array[ParsedOption])
  /// Closing markup node.
  PatternClose(String)
  /// Standalone markup node.
  PatternStandalone(String, Array[ParsedOption])
} derive(Eq, Debug)

///|
/// Compiled MF2 pattern and its markup-presence flag.
pub struct Pattern {
  nodes : Array[PatternNode]
  has_markup : Bool
} derive(Eq, Debug)

///|
/// Variable declaration stored in a compiled MF2 message.
pub enum Declaration {
  /// An `.input` declaration.
  InputDeclaration(String, Expression)
  /// A `.local` declaration.
  LocalDeclaration(String, Expression)
} derive(Eq, Debug)

///|
/// One matcher variant with selector keys and a compiled pattern.
pub struct Variant {
  keys : Array[String]
  pattern : Pattern
} derive(Eq, Debug)

///|
/// Validated MF2 data model produced once and reused for formatting.
pub struct CompiledMessage {
  declarations : Array[Declaration]
  match_names : Array[String]
  variants : Array[Variant]
  pattern : Pattern?
}

///|
priv struct ResolvedBinding {
  name : String
  value : MessageValue
  function_name : String
  options : Array[FormatOption]
}

///|
fn mf2_error(kind : Mf2ErrorKind, message : String, offset : Int) -> Mf2Error {
  { kind, message, offset }
}

///|
/// Compiles and contract-checks one MF2 message without formatting it.
pub fn compile_mf2_message(
  source : String,
  contract : MessageContract,
) -> Result[CompiledMessage, Array[Mf2Error]] {
  if @utf8.encode(source).length() > MF2_MAX_MESSAGE_BYTES {
    return Err([
      mf2_error(
        Mf2LimitError,
        "message exceeds the \{MF2_MAX_MESSAGE_BYTES}-byte limit",
        0,
      ),
    ])
  }
  let contract_errors = validate_message_contract(contract)
  if !contract_errors.is_empty() {
    return Err(contract_errors)
  }
  match compile_mf2_message_one(source, contract) {
    Ok(value) => Ok(value)
    Err(error) => Err([error])
  }
}

///|
fn validate_message_contract(contract : MessageContract) -> Array[Mf2Error] {
  if !contract.enforce {
    return []
  }
  if contract.params.length() > MF2_MAX_CONTRACT_PARAMS {
    return [
      mf2_error(
        Mf2LimitError,
        "message contract exceeds the \{MF2_MAX_CONTRACT_PARAMS}-parameter limit",
        0,
      ),
    ]
  }
  if contract.allowed_tags.length() > MF2_MAX_CONTRACT_TAGS {
    return [
      mf2_error(
        Mf2LimitError,
        "message contract exceeds the \{MF2_MAX_CONTRACT_TAGS}-tag limit",
        0,
      ),
    ]
  }
  let errors : Array[Mf2Error] = []
  let names : Map[String, Bool] = Map([])
  for param in contract.params {
    if !valid_identifier(param.name) {
      errors.push(
        mf2_error(
          Mf2DataModelError,
          "invalid message contract parameter: \{param.name}",
          0,
        ),
      )
    } else if names.contains(param.name) {
      errors.push(
        mf2_error(
          Mf2DataModelError,
          "duplicate message contract parameter: \{param.name}",
          0,
        ),
      )
    } else {
      names[param.name] = true
    }
    if !(param.typ == "String" ||
      param.typ == "Int" ||
      param.typ == "Double" ||
      param.typ == "Bool" ||
      param.typ == "InstantMillis") {
      errors.push(
        mf2_error(
          Mf2DataModelError,
          "unsupported message contract type for \{param.name}: \{param.typ}",
          0,
        ),
      )
    }
  }
  let tags : Map[String, Bool] = Map([])
  for tag in contract.allowed_tags {
    if !valid_identifier(tag) {
      errors.push(
        mf2_error(Mf2DataModelError, "invalid message contract tag: \{tag}", 0),
      )
    } else if tags.contains(tag) {
      errors.push(
        mf2_error(
          Mf2DataModelError,
          "duplicate message contract tag: \{tag}",
          0,
        ),
      )
    } else {
      tags[tag] = true
    }
  }
  errors
}

///|
fn compile_mf2_message_one(
  source : String,
  contract : MessageContract,
) -> Result[CompiledMessage, Mf2Error] {
  if is_complex_message(source) {
    compile_complex_message(source, contract)
  } else {
    match parse_pattern(source, 0, contract) {
      Ok(pattern) =>
        Ok({
          declarations: [],
          match_names: [],
          variants: [],
          pattern: Some(pattern),
        })
      Err(error) => Err(error)
    }
  }
}

///|
fn is_complex_message(source : String) -> Bool {
  let trimmed = source.trim()
  trimmed.has_prefix(".input") ||
  trimmed.has_prefix(".local") ||
  trimmed.has_prefix(".match") ||
  trimmed.has_prefix("{{")
}

///|
fn compile_complex_message(
  source : String,
  contract : MessageContract,
) -> Result[CompiledMessage, Mf2Error] {
  let chars = source.to_array()
  let declarations : Array[Declaration] = []
  let declared_names : Array[String] = []
  let declared_name_set : Map[String, Bool] = Map([])
  let mut cursor = skip_layout(chars, 0)
  while starts_with_chars(chars, cursor, ".input") ||
        starts_with_chars(chars, cursor, ".local") {
    if declarations.length() >= MF2_MAX_DECLARATIONS {
      return Err(
        mf2_error(
          Mf2LimitError,
          "message exceeds the declaration limit",
          cursor,
        ),
      )
    }
    let end = line_end(chars, cursor)
    let line = chars_slice(chars, cursor, end).trim().to_owned()
    let declaration_contract = contract_with_names(contract, declared_names)
    let declaration = if line.has_prefix(".input") {
      match
        parse_input_declaration(
          line, cursor, declaration_contract, declared_names,
        ) {
        Ok(value) => value
        Err(error) => return Err(error)
      }
    } else {
      match
        parse_local_declaration(
          line, cursor, declaration_contract, declared_names,
        ) {
        Ok(value) => value
        Err(error) => return Err(error)
      }
    }
    let name = match declaration {
      InputDeclaration(name, _) | LocalDeclaration(name, _) => name
    }
    if declared_name_set.contains(name) {
      return Err(
        mf2_error(Mf2DataModelError, "duplicate declaration: \{name}", cursor),
      )
    }
    declared_names.push(name)
    declared_name_set[name] = true
    declarations.push(declaration)
    cursor = skip_layout(chars, end)
  }
  let match_names : Array[String] = []
  let match_name_set : Map[String, Bool] = Map([])
  if starts_with_chars(chars, cursor, ".match") {
    let end = line_end(chars, cursor)
    let line = chars_slice(chars, cursor, end).trim().to_owned()
    let tokens = match tokenize(line[".match".length():].to_owned(), cursor) {
      Ok(value) => value
      Err(error) => return Err(error)
    }
    if tokens.is_empty() {
      return Err(
        mf2_error(
          Mf2DataModelError,
          ".match requires at least one selector",
          cursor,
        ),
      )
    }
    for token in tokens {
      if !token.has_prefix("$") || token.length() == 1 {
        return Err(
          mf2_error(Mf2DataModelError, "invalid .match selector", cursor),
        )
      }
      let name = token[1:].to_owned()
      if match_name_set.contains(name) {
        return Err(
          mf2_error(
            Mf2DataModelError,
            "duplicate .match selector: \{name}",
            cursor,
          ),
        )
      }
      if !declared_name_set.contains(name) {
        return Err(
          mf2_error(
            Mf2DataModelError,
            "matched variable requires a declaration: \{name}",
            cursor,
          ),
        )
      }
      match_names.push(name)
      match_name_set[name] = true
    }
    cursor = skip_layout(chars, end)
  }
  if match_names.is_empty() {
    if !starts_with_chars(chars, cursor, "{{") {
      return Err(
        mf2_error(
          Mf2DataModelError,
          "complex message requires a quoted pattern or matcher",
          cursor,
        ),
      )
    }
    let extracted = match extract_quoted_pattern(chars, cursor) {
      Ok(value) => value
      Err(error) => return Err(error)
    }
    let pattern_contract = contract_with_names(contract, declared_names)
    let pattern = match
      parse_pattern(extracted.0, cursor + 2, pattern_contract) {
      Ok(value) => value
      Err(error) => return Err(error)
    }
    if skip_layout(chars, extracted.1) != chars.length() {
      return Err(
        mf2_error(
          Mf2SyntaxError,
          "unexpected content after quoted pattern",
          extracted.1,
        ),
      )
    }
    return Ok({
      declarations,
      match_names,
      variants: [],
      pattern: Some(pattern),
    })
  }
  let variants : Array[Variant] = []
  let signatures : Map[String, Bool] = Map([])
  let mut has_fallback = false
  let pattern_contract = contract_with_names(contract, declared_names)
  while cursor < chars.length() {
    if variants.length() >= MF2_MAX_VARIANTS {
      return Err(
        mf2_error(Mf2LimitError, "message exceeds the variant limit", cursor),
      )
    }
    let open = match find_quoted_pattern_start(chars, cursor) {
      Some(value) => value
      None =>
        return Err(mf2_error(Mf2SyntaxError, "invalid match variant", cursor))
    }
    let raw_keys = chars_slice(chars, cursor, open).trim().to_owned()
    let keys = match tokenize(raw_keys, cursor) {
      Ok(value) => value
      Err(error) => return Err(error)
    }
    if keys.length() != match_names.length() {
      return Err(
        mf2_error(Mf2DataModelError, "match variant key count mismatch", cursor),
      )
    }
    let signature = keys.join("\u{1f}")
    if signatures.contains(signature) {
      return Err(
        mf2_error(
          Mf2DataModelError,
          "duplicate match variant keys: \{keys.join(" ")}",
          cursor,
        ),
      )
    }
    signatures[signature] = true
    if keys.all(key => key == "*") {
      has_fallback = true
    }
    let extracted = match extract_quoted_pattern(chars, open) {
      Ok(value) => value
      Err(error) => return Err(error)
    }
    let pattern = match parse_pattern(extracted.0, open + 2, pattern_contract) {
      Ok(value) => value
      Err(error) => return Err(error)
    }
    variants.push({ keys, pattern })
    cursor = skip_layout(chars, extracted.1)
  }
  if variants.is_empty() {
    return Err(
      mf2_error(
        Mf2DataModelError,
        "match message requires selectors and variants",
        0,
      ),
    )
  }
  if !has_fallback {
    return Err(
      mf2_error(
        Mf2DataModelError,
        "match message requires an all-wildcard fallback variant",
        0,
      ),
    )
  }
  Ok({ declarations, match_names, variants, pattern: None })
}

///|
fn parse_input_declaration(
  line : String,
  offset : Int,
  contract : MessageContract,
  declared_names : Array[String],
) -> Result[Declaration, Mf2Error] {
  let body = line[".input".length():].to_owned().trim().to_owned()
  if !body.has_prefix("{") || !body.has_suffix("}") {
    return Err(mf2_error(Mf2SyntaxError, "invalid .input declaration", offset))
  }
  let expression = match
    parse_expression(body[1:body.length() - 1].to_owned(), offset, contract) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  guard expression.operand is VariableOperand(name) else {
    return Err(mf2_error(Mf2DataModelError, "invalid .input variable", offset))
  }
  if !valid_identifier(name) {
    return Err(mf2_error(Mf2DataModelError, "invalid .input variable", offset))
  }
  if contract.enforce && find_param_spec(contract.params, name) is None {
    return Err(
      mf2_error(Mf2DataModelError, "unknown variable: \{name}", offset),
    )
  }
  ignore(declared_names)
  Ok(InputDeclaration(name, expression))
}

///|
fn parse_local_declaration(
  line : String,
  offset : Int,
  contract : MessageContract,
  declared_names : Array[String],
) -> Result[Declaration, Mf2Error] {
  let assignment = line[".local".length():].to_owned().trim().to_owned()
  let (raw_name, raw_expression) = match assignment.split_once("=") {
    Some(value) => value
    None =>
      return Err(
        mf2_error(Mf2SyntaxError, "invalid .local declaration", offset),
      )
  }
  let name_token = raw_name.to_owned().trim().to_owned()
  if !name_token.has_prefix("$") ||
    name_token.length() == 1 ||
    !valid_identifier(name_token[1:].to_owned()) {
    return Err(mf2_error(Mf2DataModelError, "invalid .local variable", offset))
  }
  let expression_source = raw_expression.to_owned().trim().to_owned()
  if !expression_source.has_prefix("{") || !expression_source.has_suffix("}") {
    return Err(mf2_error(Mf2SyntaxError, "invalid .local expression", offset))
  }
  let expression = match
    parse_expression(
      expression_source[1:expression_source.length() - 1].to_owned(),
      offset,
      contract,
    ) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  match expression.operand {
    VariableOperand(referenced) =>
      if contract.enforce &&
        find_param_spec(contract.params, referenced) is None &&
        !declared_names.contains(referenced) {
        return Err(
          mf2_error(
            Mf2DataModelError,
            "unknown variable: \{referenced}",
            offset,
          ),
        )
      }
    LiteralOperand(_) => ()
  }
  Ok(LocalDeclaration(name_token[1:].to_owned(), expression))
}

///|
fn parse_pattern(
  source : String,
  base_offset : Int,
  contract : MessageContract,
) -> Result[Pattern, Mf2Error] {
  let chars = source.to_array()
  let nodes : Array[PatternNode] = []
  let text = StringBuilder::new()
  let tag_stack : Array[String] = []
  let mut has_markup = false
  let mut cursor = 0
  while cursor < chars.length() {
    if chars[cursor] == '\\' {
      if cursor + 1 >= chars.length() {
        return Err(
          mf2_error(Mf2SyntaxError, "trailing escape", base_offset + cursor),
        )
      }
      let escaped = chars[cursor + 1]
      if escaped != '\\' && escaped != '{' && escaped != '}' && escaped != '|' {
        return Err(
          mf2_error(Mf2SyntaxError, "invalid escape", base_offset + cursor),
        )
      }
      text.write_char(escaped)
      cursor = cursor + 2
    } else if chars[cursor] == '{' {
      push_pattern_text(nodes, text)
      let close = match find_expression_end(chars, cursor) {
        Some(value) => value
        None =>
          return Err(
            mf2_error(
              Mf2SyntaxError,
              "unclosed expression",
              base_offset + cursor,
            ),
          )
      }
      let content = chars_slice(chars, cursor + 1, close).trim().to_owned()
      if content.has_prefix("#") {
        let markup = match
          parse_markup_open(
            content[1:].to_owned(),
            base_offset + cursor,
            contract,
          ) {
          Ok(value) => value
          Err(error) => return Err(error)
        }
        has_markup = true
        if markup.2 {
          nodes.push(PatternStandalone(markup.0, markup.1))
        } else {
          tag_stack.push(markup.0)
          nodes.push(PatternOpen(markup.0, markup.1))
        }
      } else if content.has_prefix("/") {
        let name = content[1:].to_owned().trim().to_owned()
        if !valid_identifier(name) {
          return Err(
            mf2_error(
              Mf2DataModelError,
              "invalid closing markup tag",
              base_offset + cursor,
            ),
          )
        }
        let expected = match tag_stack.pop() {
          Some(value) => value
          None =>
            return Err(
              mf2_error(
                Mf2DataModelError,
                "unexpected closing markup tag: \{name}",
                base_offset + cursor,
              ),
            )
        }
        if expected != name {
          return Err(
            mf2_error(
              Mf2DataModelError,
              "mismatched closing markup tag: expected \{expected}, got \{name}",
              base_offset + cursor,
            ),
          )
        }
        has_markup = true
        nodes.push(PatternClose(name))
      } else {
        let expression = match
          parse_expression(content, base_offset + cursor, contract) {
          Ok(value) => value
          Err(error) => return Err(error)
        }
        nodes.push(PatternExpression(expression))
      }
      cursor = close + 1
    } else if chars[cursor] == '}' {
      return Err(
        mf2_error(
          Mf2SyntaxError,
          "unmatched closing brace",
          base_offset + cursor,
        ),
      )
    } else {
      text.write_char(chars[cursor])
      cursor = cursor + 1
    }
  }
  push_pattern_text(nodes, text)
  if !tag_stack.is_empty() {
    return Err(
      mf2_error(
        Mf2DataModelError,
        "unclosed markup tag: \{tag_stack[tag_stack.length() - 1]}",
        base_offset,
      ),
    )
  }
  Ok({ nodes, has_markup })
}

///|
fn parse_markup_open(
  source : String,
  offset : Int,
  contract : MessageContract,
) -> Result[(String, Array[ParsedOption], Bool), Mf2Error] {
  let tokens = match tokenize(source, offset) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  if tokens.is_empty() {
    return Err(mf2_error(Mf2DataModelError, "empty markup tag", offset))
  }
  let standalone = tokens[tokens.length() - 1] == "/"
  let end = if standalone { tokens.length() - 1 } else { tokens.length() }
  if end - 1 > MF2_MAX_OPTIONS {
    return Err(
      mf2_error(
        Mf2LimitError,
        "markup exceeds the \{MF2_MAX_OPTIONS}-option limit",
        offset,
      ),
    )
  }
  let name = tokens[0]
  if !valid_identifier(name) {
    return Err(mf2_error(Mf2DataModelError, "invalid markup tag", offset))
  }
  if contract.enforce && !contract.allowed_tags.contains(name) {
    return Err(
      mf2_error(
        Mf2DataModelError,
        "rich message uses an unregistered tag: \{name}",
        offset,
      ),
    )
  }
  let options : Array[ParsedOption] = []
  for i = 1; i < end; i = i + 1 {
    let option = match parse_option_token(tokens[i], offset) {
      Ok(value) => value
      Err(error) => return Err(error)
    }
    if options.any(existing => existing.name == option.name) {
      return Err(
        mf2_error(
          Mf2DataModelError,
          "duplicate markup option: \{option.name}",
          offset,
        ),
      )
    }
    match validate_option_variable(option, contract, offset) {
      Ok(_) => ()
      Err(error) => return Err(error)
    }
    options.push(option)
  }
  Ok((name, options, standalone))
}

///|
fn parse_expression(
  source : String,
  offset : Int,
  contract : MessageContract,
) -> Result[Expression, Mf2Error] {
  let tokens = match tokenize(source, offset) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  if tokens.is_empty() {
    return Err(mf2_error(Mf2SyntaxError, "empty expression", offset))
  }
  let operand = if tokens[0].has_prefix("$") {
    let name = tokens[0][1:].to_owned()
    if !valid_identifier(name) {
      return Err(mf2_error(Mf2DataModelError, "invalid variable", offset))
    }
    if contract.enforce && find_param_spec(contract.params, name) is None {
      return Err(
        mf2_error(Mf2DataModelError, "unknown variable: \{name}", offset),
      )
    }
    VariableOperand(name)
  } else if is_quoted_literal(tokens[0]) {
    LiteralOperand(unquote_literal(tokens[0]))
  } else if valid_unquoted_literal(tokens[0]) {
    LiteralOperand(tokens[0])
  } else {
    return Err(
      mf2_error(
        Mf2SyntaxError,
        "expression operand must be a variable or quoted literal",
        offset,
      ),
    )
  }
  let mut function_name = ""
  let options : Array[ParsedOption] = []
  for i = 1; i < tokens.length(); i = i + 1 {
    let token = tokens[i]
    if token.has_prefix(":") {
      if !function_name.is_empty() {
        return Err(
          mf2_error(
            Mf2DataModelError,
            "multiple functions in expression",
            offset,
          ),
        )
      }
      function_name = token[1:].to_owned()
      if !supported_function(function_name) {
        return Err(
          mf2_error(
            Mf2DataModelError,
            "unsupported function: :\{function_name}",
            offset,
          ),
        )
      }
    } else {
      if options.length() >= MF2_MAX_OPTIONS {
        return Err(
          mf2_error(
            Mf2LimitError,
            "function exceeds the \{MF2_MAX_OPTIONS}-option limit",
            offset,
          ),
        )
      }
      let option = match parse_option_token(token, offset) {
        Ok(value) => value
        Err(error) => return Err(error)
      }
      if options.any(existing => existing.name == option.name) {
        return Err(
          mf2_error(
            Mf2DataModelError,
            "duplicate function option: \{option.name}",
            offset,
          ),
        )
      }
      match validate_option_variable(option, contract, offset) {
        Ok(_) => ()
        Err(error) => return Err(error)
      }
      options.push(option)
    }
  }
  match validate_function_options(function_name, options, offset) {
    Ok(_) => ()
    Err(error) => return Err(error)
  }
  match operand {
    VariableOperand(name) =>
      match find_param_spec(contract.params, name) {
        Some(param) =>
          match
            validate_expression_operand_type(
              name,
              param.typ,
              function_name,
              offset,
            ) {
            Ok(_) => ()
            Err(error) => return Err(error)
          }
        None => ()
      }
    LiteralOperand(value) =>
      if function_name == "number" ||
        function_name == "integer" ||
        function_name == "offset" {
        if parse_numeric_literal(value) is None {
          return Err(
            mf2_error(
              Mf2DataModelError,
              ":\{function_name} literal operand must be a finite number",
              offset,
            ),
          )
        }
      } else if function_name == "lampclaw:datetime" {
        return Err(
          mf2_error(
            Mf2DataModelError,
            ":lampclaw:datetime requires an InstantMillis variable",
            offset,
          ),
        )
      }
  }
  Ok({ operand, function_name, options, offset })
}

///|
fn validate_option_variable(
  option : ParsedOption,
  contract : MessageContract,
  offset : Int,
) -> Result[Unit, Mf2Error] {
  match option.value {
    VariableOption(name) if contract.enforce =>
      if find_param_spec(contract.params, name) is None {
        Err(
          mf2_error(
            Mf2DataModelError,
            "unknown option variable: \{name}",
            offset,
          ),
        )
      } else {
        Ok(())
      }
    _ => Ok(())
  }
}

///|
fn validate_expression_operand_type(
  name : String,
  typ : String,
  function_name : String,
  offset : Int,
) -> Result[Unit, Mf2Error] {
  if typ == "Local" || function_name.is_empty() || function_name == "string" {
    return Ok(())
  }
  let valid = match function_name {
    "number" | "integer" | "offset" => typ == "Int" || typ == "Double"
    "lampclaw:datetime" => typ == "InstantMillis"
    _ => false
  }
  if valid {
    Ok(())
  } else {
    Err(
      mf2_error(
        Mf2DataModelError,
        "variable \{name} of type \{typ} is incompatible with :\{function_name}",
        offset,
      ),
    )
  }
}

///|
fn supported_function(name : String) -> Bool {
  name == "string" ||
  name == "number" ||
  name == "integer" ||
  name == "offset" ||
  name == "lampclaw:datetime"
}

///|
fn validate_function_options(
  function_name : String,
  options : Array[ParsedOption],
  offset : Int,
) -> Result[Unit, Mf2Error] {
  let display_function = if function_name.is_empty() {
    "string"
  } else {
    function_name
  }
  for option in options {
    let allowed = match function_name {
      "number" | "integer" =>
        option.name == "select" ||
        option.name == "style" ||
        option.name == "currency" ||
        option.name == "currencyDisplay" ||
        option.name == "useGrouping" ||
        option.name == "minimumIntegerDigits" ||
        option.name == "minimumFractionDigits" ||
        option.name == "maximumFractionDigits" ||
        option.name == "minimumSignificantDigits" ||
        option.name == "maximumSignificantDigits"
      "offset" => option.name == "add" || option.name == "subtract"
      "lampclaw:datetime" =>
        option.name == "dateStyle" ||
        option.name == "timeStyle" ||
        option.name == "timeZone" ||
        option.name == "hourCycle"
      "" | "string" => false
      _ => false
    }
    if !allowed {
      return Err(
        mf2_error(
          Mf2DataModelError,
          "unsupported option for :\{display_function}: \{option.name}",
          offset,
        ),
      )
    }
    match validate_literal_function_option(function_name, option, offset) {
      Ok(_) => ()
      Err(error) => return Err(error)
    }
  }
  match literal_parsed_option(options, "select") {
    Some(value) if value != "cardinal" && value != "ordinal" && value != "exact" =>
      Err(
        mf2_error(
          Mf2DataModelError,
          "number select must be cardinal, ordinal, or exact",
          offset,
        ),
      )
    _ => Ok(())
  }
}

///|
fn validate_literal_function_option(
  function_name : String,
  option : ParsedOption,
  offset : Int,
) -> Result[Unit, Mf2Error] {
  let value = match option.value {
    LiteralOption(value) => value
    VariableOption(_) => return Ok(())
  }
  let valid = match (function_name, option.name) {
    ("number" | "integer", "style") =>
      value == "decimal" || value == "currency" || value == "percent"
    ("number" | "integer", "currency") => currency_code_is_valid(value)
    ("number" | "integer", "currencyDisplay") =>
      value == "symbol" ||
      value == "narrowSymbol" ||
      value == "code" ||
      value == "name"
    ("number" | "integer", "useGrouping") => value == "true" || value == "false"
    (
      "number"
      | "integer",
      "minimumIntegerDigits"
      | "minimumFractionDigits"
      | "maximumFractionDigits"
      | "minimumSignificantDigits"
      | "maximumSignificantDigits",
    ) => nonnegative_integer_literal(value)
    ("offset", "add" | "subtract") => parse_numeric_literal(value) is Some(_)
    ("lampclaw:datetime", "dateStyle" | "timeStyle") =>
      value == "full" ||
      value == "long" ||
      value == "medium" ||
      value == "short"
    ("lampclaw:datetime", "hourCycle") =>
      value == "h11" || value == "h12" || value == "h23" || value == "h24"
    ("lampclaw:datetime", "timeZone") => !value.is_empty()
    (_, "select") => true
    _ => true
  }
  if valid {
    Ok(())
  } else {
    Err(
      mf2_error(
        Mf2DataModelError,
        "invalid literal value for :\{function_name} option \{option.name}: \{value}",
        offset,
      ),
    )
  }
}

///|
fn nonnegative_integer_literal(value : String) -> Bool {
  if value.is_empty() {
    return false
  }
  for char in value.to_array() {
    if char < '0' || char > '9' {
      return false
    }
  }
  true
}

///|
fn currency_code_is_valid(value : String) -> Bool {
  if value.length() != 3 {
    return false
  }
  for char in value.to_array() {
    if !((char >= 'a' && char <= 'z') || (char >= 'A' && char <= 'Z')) {
      return false
    }
  }
  true
}

///|
fn parse_option_token(
  token : String,
  offset : Int,
) -> Result[ParsedOption, Mf2Error] {
  let (name, raw_value) = match token.split_once("=") {
    Some(value) => value
    None =>
      return Err(
        mf2_error(Mf2SyntaxError, "invalid function option: \{token}", offset),
      )
  }
  let option_name = name.to_owned()
  if !valid_identifier(option_name) {
    return Err(mf2_error(Mf2DataModelError, "invalid option name", offset))
  }
  let value_token = raw_value.to_owned()
  if value_token.is_empty() {
    return Err(mf2_error(Mf2SyntaxError, "empty option value", offset))
  }
  let value = if value_token.has_prefix("$") {
    let variable = value_token[1:].to_owned()
    if !valid_identifier(variable) {
      return Err(
        mf2_error(Mf2DataModelError, "invalid option variable", offset),
      )
    }
    VariableOption(variable)
  } else if is_quoted_literal(value_token) {
    LiteralOption(unquote_literal(value_token))
  } else {
    // MF2 option identifiers and numeric literals are valid unquoted values.
    LiteralOption(value_token)
  }
  Ok({ name: option_name, value })
}

///|
fn tokenize(source : String, offset : Int) -> Result[Array[String], Mf2Error] {
  let tokens : Array[String] = []
  let current = StringBuilder::new()
  let mut quoted = false
  let chars = source.to_array()
  let mut cursor = 0
  while cursor < chars.length() {
    let char = chars[cursor]
    if char == '\\' {
      if cursor + 1 >= chars.length() {
        return Err(
          mf2_error(Mf2SyntaxError, "trailing escape", offset + cursor),
        )
      }
      current.write_char(char)
      current.write_char(chars[cursor + 1])
      cursor = cursor + 2
    } else if char == '|' {
      quoted = !quoted
      current.write_char(char)
      cursor = cursor + 1
    } else if !quoted && is_layout_char(char) {
      let token = current.to_string()
      if !token.is_empty() {
        tokens.push(token)
        current.reset()
      }
      cursor = cursor + 1
    } else {
      current.write_char(char)
      cursor = cursor + 1
    }
  }
  if quoted {
    return Err(mf2_error(Mf2SyntaxError, "unclosed quoted literal", offset))
  }
  let final_token = current.to_string()
  if !final_token.is_empty() {
    tokens.push(final_token)
  }
  Ok(tokens)
}

///|
/// Formats a compiled message as plain text and rejects markup output.
pub fn format_text(
  compiled : CompiledMessage,
  locale : String,
  args : Array[MessageArg],
  formatter : Formatter,
) -> Result[String, Mf2Error] {
  let bindings = match resolve_bindings(compiled, args) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let pattern = match choose_pattern(compiled, locale, bindings, formatter) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  if pattern.has_markup {
    return Err(
      mf2_error(Mf2FormattingError, "MF2 markup requires the parts API", 0),
    )
  }
  let out = StringBuilder::new()
  for node in pattern.nodes {
    match node {
      PatternText(value) => out.write_string(value)
      PatternExpression(expression) => {
        let resolved = match resolve_expression(expression, bindings) {
          Ok(value) => value
          Err(error) => return Err(error)
        }
        match format_resolved(resolved, locale, formatter, expression.offset) {
          Ok(value) => out.write_string(value)
          Err(error) => return Err(error)
        }
      }
      PatternOpen(_, _) | PatternClose(_) | PatternStandalone(_, _) => ()
    }
  }
  Ok(out.to_string())
}

///|
/// Formats a compiled message as structured text and markup parts.
pub fn format_parts(
  compiled : CompiledMessage,
  locale : String,
  args : Array[MessageArg],
  formatter : Formatter,
) -> Result[Array[MessagePart], Mf2Error] {
  let bindings = match resolve_bindings(compiled, args) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let pattern = match choose_pattern(compiled, locale, bindings, formatter) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let parts : Array[MessagePart] = []
  for node in pattern.nodes {
    match node {
      PatternText(value) => push_message_text(parts, value)
      PatternExpression(expression) => {
        let resolved = match resolve_expression(expression, bindings) {
          Ok(value) => value
          Err(error) => return Err(error)
        }
        match format_resolved(resolved, locale, formatter, expression.offset) {
          Ok(value) => push_message_text(parts, value)
          Err(error) => return Err(error)
        }
      }
      PatternOpen(name, parsed) => {
        let options = match resolve_options(parsed, bindings, 0) {
          Ok(value) => value
          Err(error) => return Err(error)
        }
        parts.push(Open(name, options))
      }
      PatternClose(name) => parts.push(Close(name))
      PatternStandalone(name, parsed) => {
        let options = match resolve_options(parsed, bindings, 0) {
          Ok(value) => value
          Err(error) => return Err(error)
        }
        parts.push(Standalone(name, options))
      }
    }
  }
  Ok(parts)
}

///|
fn push_message_text(parts : Array[MessagePart], value : String) -> Unit {
  if value.is_empty() {
    return
  }
  if !parts.is_empty() {
    match parts[parts.length() - 1] {
      Text(previous) => {
        parts[parts.length() - 1] = Text(previous + value)
        return
      }
      _ => ()
    }
  }
  parts.push(Text(value))
}

///|
fn resolve_bindings(
  compiled : CompiledMessage,
  args : Array[MessageArg],
) -> Result[Array[ResolvedBinding], Mf2Error] {
  if args.length() > MF2_MAX_ARGUMENTS {
    return Err(
      mf2_error(
        Mf2LimitError,
        "formatting exceeds the \{MF2_MAX_ARGUMENTS}-argument limit",
        0,
      ),
    )
  }
  let bindings : Array[ResolvedBinding] = []
  for arg in args {
    if find_binding(bindings, arg.name) is Some(_) {
      return Err(
        mf2_error(
          Mf2ResolutionError,
          "duplicate message argument: \{arg.name}",
          0,
        ),
      )
    }
    bindings.push({
      name: arg.name,
      value: arg.value,
      function_name: "",
      options: [],
    })
  }
  for declaration in compiled.declarations {
    match declaration {
      InputDeclaration(name, expression) => {
        let existing = match find_binding(bindings, name) {
          Some(value) => value
          None =>
            return Err(
              mf2_error(
                Mf2ResolutionError,
                "unknown variable: \{name}",
                expression.offset,
              ),
            )
        }
        let options = match
          resolve_options(expression.options, bindings, expression.offset) {
          Ok(value) => value
          Err(error) => return Err(error)
        }
        replace_binding(bindings, {
          name,
          value: existing.value,
          function_name: expression.function_name,
          options,
        })
      }
      LocalDeclaration(name, expression) => {
        let resolved = match resolve_expression(expression, bindings) {
          Ok(value) => value
          Err(error) => return Err(error)
        }
        if find_binding(bindings, name) is Some(_) {
          return Err(
            mf2_error(
              Mf2ResolutionError,
              "duplicate resolved variable: \{name}",
              expression.offset,
            ),
          )
        }
        bindings.push({ ..resolved, name, })
      }
    }
  }
  Ok(bindings)
}

///|
fn resolve_expression(
  expression : Expression,
  bindings : Array[ResolvedBinding],
) -> Result[ResolvedBinding, Mf2Error] {
  let base = match expression.operand {
    VariableOperand(name) =>
      match find_binding(bindings, name) {
        Some(value) => value
        None =>
          return Err(
            mf2_error(
              Mf2ResolutionError,
              "unknown variable: \{name}",
              expression.offset,
            ),
          )
      }
    LiteralOperand(value) =>
      { name: "", value: TextValue(value), function_name: "", options: [] }
  }
  let own_options = match
    resolve_options(expression.options, bindings, expression.offset) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let options = merge_options(base.options, own_options)
  let function_name = if expression.function_name.is_empty() {
    base.function_name
  } else {
    expression.function_name
  }
  let value = match expression.operand {
    LiteralOperand(raw) if function_name == "number" ||
      function_name == "integer" ||
      function_name == "offset" =>
      match parse_numeric_literal(raw) {
        Some(number) => DoubleValue(number)
        None =>
          return Err(
            mf2_error(
              Mf2ResolutionError,
              ":\{function_name} literal operand must be a finite number",
              expression.offset,
            ),
          )
      }
    _ => base.value
  }
  Ok({ name: base.name, value, function_name, options })
}

///|
fn resolve_options(
  options : Array[ParsedOption],
  bindings : Array[ResolvedBinding],
  offset : Int,
) -> Result[Array[FormatOption], Mf2Error] {
  let resolved : Array[FormatOption] = []
  for option in options {
    let value = match option.value {
      LiteralOption(value) => value
      VariableOption(name) =>
        match find_binding(bindings, name) {
          Some(binding) => message_value_to_string(binding.value)
          None =>
            return Err(
              mf2_error(
                Mf2ResolutionError,
                "unknown option variable: \{name}",
                offset,
              ),
            )
        }
    }
    resolved.push({ name: option.name, value })
  }
  Ok(resolved)
}

///|
fn merge_options(
  inherited : Array[FormatOption],
  own : Array[FormatOption],
) -> Array[FormatOption] {
  let result = inherited.copy()
  for option in own {
    let mut replaced = false
    for i = 0; i < result.length(); i = i + 1 {
      if result[i].name == option.name {
        result[i] = option
        replaced = true
        break
      }
    }
    if !replaced {
      result.push(option)
    }
  }
  result
}

///|
fn choose_pattern(
  compiled : CompiledMessage,
  locale : String,
  bindings : Array[ResolvedBinding],
  formatter : Formatter,
) -> Result[Pattern, Mf2Error] {
  match compiled.pattern {
    Some(pattern) => Ok(pattern)
    None => {
      let mut best_pattern : Pattern? = None
      let mut best_ranks : Array[Int] = []
      for variant in compiled.variants {
        let ranks : Array[Int] = []
        let mut matches = true
        for i = 0; i < compiled.match_names.length(); i = i + 1 {
          let binding = match find_binding(bindings, compiled.match_names[i]) {
            Some(value) => value
            None =>
              return Err(
                mf2_error(
                  Mf2ResolutionError,
                  "unknown selector variable: \{compiled.match_names[i]}",
                  0,
                ),
              )
          }
          let rank = match
            selector_rank(variant.keys[i], binding, locale, formatter) {
            Ok(value) => value
            Err(error) => return Err(error)
          }
          if rank < 0 {
            matches = false
            break
          }
          ranks.push(rank)
        }
        if matches && (best_pattern is None || ranks_better(ranks, best_ranks)) {
          best_pattern = Some(variant.pattern)
          best_ranks = ranks
        }
      }
      match best_pattern {
        Some(pattern) => Ok(pattern)
        None =>
          Err(mf2_error(Mf2ResolutionError, "no match variant selected", 0))
      }
    }
  }
}

///|
fn selector_rank(
  key : String,
  binding : ResolvedBinding,
  locale : String,
  formatter : Formatter,
) -> Result[Int, Mf2Error] {
  if key == "*" {
    return Ok(0)
  }
  let function_name = if binding.function_name.is_empty() {
    "string"
  } else {
    binding.function_name
  }
  if function_name == "number" ||
    function_name == "integer" ||
    function_name == "offset" {
    let number = match numeric_binding_value(binding, 0) {
      Ok(value) => value
      Err(error) => return Err(error)
    }
    match parse_numeric_literal(key) {
      Some(exact) => return Ok(if exact == number { 3 } else { -1 })
      None => ()
    }
    if option_value(binding.options, "select") == Some("exact") {
      return Ok(-1)
    }
    let ordinal = option_value(binding.options, "select") == Some("ordinal")
    match (formatter.plural_category)(locale, number, ordinal) {
      Ok(category) => Ok(if category == unquote_literal(key) { 2 } else { -1 })
      Err(issue) => Err(mf2_error(Mf2FormattingError, issue.message(), 0))
    }
  } else {
    Ok(
      if message_value_to_string(binding.value) == unquote_literal(key) {
        2
      } else {
        -1
      },
    )
  }
}

///|
fn ranks_better(candidate : Array[Int], current : Array[Int]) -> Bool {
  if current.is_empty() {
    return true
  }
  for i = 0; i < candidate.length(); i = i + 1 {
    if candidate[i] > current[i] {
      return true
    }
    if candidate[i] < current[i] {
      return false
    }
  }
  false
}

///|
fn format_resolved(
  binding : ResolvedBinding,
  locale : String,
  formatter : Formatter,
  offset : Int,
) -> Result[String, Mf2Error] {
  let function_name = if binding.function_name.is_empty() {
    "string"
  } else {
    binding.function_name
  }
  match function_name {
    "string" => Ok(message_value_to_string(binding.value))
    "number" | "integer" => {
      let number = match message_value_to_double(binding.value) {
        Some(value) => value
        None =>
          return Err(
            mf2_error(
              Mf2ResolutionError,
              ":\{function_name} requires an Int or Double",
              offset,
            ),
          )
      }
      let number = if function_name == "integer" {
        number.trunc()
      } else {
        number
      }
      let options = formatter_number_options(binding.options)
      if function_name == "integer" {
        options.push({ name: "integer", value: "true" })
      }
      match (formatter.format_number)(locale, number, options) {
        Ok(value) => Ok(value)
        Err(issue) =>
          Err(mf2_error(Mf2FormattingError, issue.message(), offset))
      }
    }
    "offset" => {
      let adjusted = match numeric_binding_value(binding, offset) {
        Ok(value) => value
        Err(error) => return Err(error)
      }
      match
        (formatter.format_number)(
          locale,
          adjusted,
          formatter_offset_number_options(binding.options),
        ) {
        Ok(value) => Ok(value)
        Err(issue) =>
          Err(mf2_error(Mf2FormattingError, issue.message(), offset))
      }
    }
    "lampclaw:datetime" =>
      match binding.value {
        InstantMillis(value) =>
          match (formatter.format_datetime)(locale, value, binding.options) {
            Ok(formatted) => Ok(formatted)
            Err(issue) =>
              Err(mf2_error(Mf2FormattingError, issue.message(), offset))
          }
        _ =>
          Err(
            mf2_error(
              Mf2ResolutionError,
              ":lampclaw:datetime requires InstantMillis",
              offset,
            ),
          )
      }
    _ =>
      Err(
        mf2_error(
          Mf2DataModelError,
          "unsupported function: :\{function_name}",
          offset,
        ),
      )
  }
}

///|
fn formatter_number_options(
  options : Array[FormatOption],
) -> Array[FormatOption] {
  options.filter(option => option.name != "select")
}

///|
fn formatter_offset_number_options(
  options : Array[FormatOption],
) -> Array[FormatOption] {
  options.filter(option => {
    option.name != "select" && option.name != "add" && option.name != "subtract"
  })
}

///|
fn numeric_binding_value(
  binding : ResolvedBinding,
  offset : Int,
) -> Result[Double, Mf2Error] {
  let raw = match message_value_to_double(binding.value) {
    Some(value) if !value.is_nan() && !value.is_inf() => value
    _ =>
      return Err(
        mf2_error(
          Mf2ResolutionError,
          ":\{binding.function_name} requires a finite Int or Double",
          offset,
        ),
      )
  }
  if binding.function_name == "integer" {
    Ok(raw.trunc())
  } else if binding.function_name == "offset" {
    let mut adjusted = raw
    match option_value(binding.options, "add") {
      Some(value) =>
        match parse_numeric_literal(value) {
          Some(number) => adjusted = adjusted + number
          None =>
            return Err(
              mf2_error(
                Mf2ResolutionError,
                ":offset add must be a finite number",
                offset,
              ),
            )
        }
      None => ()
    }
    match option_value(binding.options, "subtract") {
      Some(value) =>
        match parse_numeric_literal(value) {
          Some(number) => adjusted = adjusted - number
          None =>
            return Err(
              mf2_error(
                Mf2ResolutionError,
                ":offset subtract must be a finite number",
                offset,
              ),
            )
        }
      None => ()
    }
    if adjusted.is_nan() || adjusted.is_inf() {
      Err(
        mf2_error(
          Mf2ResolutionError,
          ":offset result must be a finite number",
          offset,
        ),
      )
    } else {
      Ok(adjusted)
    }
  } else {
    Ok(raw)
  }
}

///|
/// Validates MF2 source against a list of string parameter names.
pub fn validate_mf2_message(
  source : String,
  params : Array[String],
) -> Result[Unit, String] {
  let specs = params.map(name => MessageParamSpec::{ name, typ: "String" })
  match compile_mf2_message(source, MessageContract::new(specs)) {
    Ok(_) => Ok(())
    Err(errors) => Err(errors[0].message)
  }
}

///|
/// Validates MF2 source against parameter names and runtime value types.
pub fn validate_mf2_message_with_args(
  source : String,
  args : Array[MessageArg],
) -> Result[Unit, String] {
  let specs = args.map(arg => MessageParamSpec::{
    name: arg.name,
    typ: message_value_type(arg.value),
  })
  match compile_mf2_message(source, MessageContract::new(specs)) {
    Ok(_) => Ok(())
    Err(errors) => Err(errors[0].message)
  }
}

///|
/// Compiles and formats MF2 source using the permissive low-level contract.
pub fn format_mf2_message(
  source : String,
  locale : String,
  args : Array[MessageArg],
  formatter : Formatter,
) -> Result[String, String] {
  let compiled = match compile_mf2_message(source, MessageContract::open()) {
    Ok(value) => value
    Err(errors) => return Err(errors[0].message)
  }
  match format_text(compiled, locale, args, formatter) {
    Ok(value) => Ok(value)
    Err(error) => Err(error.message)
  }
}

///|
fn message_value_type(value : MessageValue) -> String {
  match value {
    TextValue(_) => "String"
    IntValue(_) => "Int"
    DoubleValue(_) => "Double"
    BoolValue(_) => "Bool"
    InstantMillis(_) => "InstantMillis"
  }
}

///|
fn message_value_to_string(value : MessageValue) -> String {
  match value {
    TextValue(value) => value
    IntValue(value) => value.to_string()
    DoubleValue(value) => value.to_string()
    BoolValue(value) => value.to_string()
    InstantMillis(value) => value.to_string()
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
fn parse_numeric_literal(source : String) -> Double? {
  if !valid_numeric_literal_syntax(source) {
    return None
  }
  let value = try @string.parse_double(source) catch {
    _ => return None
  } noraise {
    value => value
  }
  if value.is_nan() || value.is_inf() {
    None
  } else {
    Some(value)
  }
}

///|
fn valid_numeric_literal_syntax(source : String) -> Bool {
  let chars = source.to_array()
  if chars.is_empty() {
    return false
  }
  let mut cursor = 0
  if chars[cursor] == '-' {
    cursor = cursor + 1
    if cursor == chars.length() {
      return false
    }
  }
  if chars[cursor] == '0' {
    cursor = cursor + 1
    if cursor < chars.length() && chars[cursor] >= '0' && chars[cursor] <= '9' {
      return false
    }
  } else if chars[cursor] >= '1' && chars[cursor] <= '9' {
    while cursor < chars.length() &&
          chars[cursor] >= '0' &&
          chars[cursor] <= '9' {
      cursor = cursor + 1
    }
  } else {
    return false
  }
  if cursor < chars.length() && chars[cursor] == '.' {
    cursor = cursor + 1
    let fraction_start = cursor
    while cursor < chars.length() &&
          chars[cursor] >= '0' &&
          chars[cursor] <= '9' {
      cursor = cursor + 1
    }
    if cursor == fraction_start {
      return false
    }
  }
  if cursor < chars.length() && (chars[cursor] == 'e' || chars[cursor] == 'E') {
    cursor = cursor + 1
    if cursor < chars.length() && (chars[cursor] == '+' || chars[cursor] == '-') {
      cursor = cursor + 1
    }
    let exponent_start = cursor
    while cursor < chars.length() &&
          chars[cursor] >= '0' &&
          chars[cursor] <= '9' {
      cursor = cursor + 1
    }
    if cursor == exponent_start {
      return false
    }
  }
  cursor == chars.length()
}

///|
fn find_param_spec(
  params : Array[MessageParamSpec],
  name : String,
) -> MessageParamSpec? {
  for param in params {
    if param.name == name {
      return Some(param)
    }
  }
  None
}

///|
fn contract_with_names(
  contract : MessageContract,
  names : Array[String],
) -> MessageContract {
  if !contract.enforce {
    return contract
  }
  let params = contract.params.copy()
  for name in names {
    if find_param_spec(params, name) is None {
      params.push({ name, typ: "Local" })
    }
  }
  { ..contract, params, }
}

///|
fn find_binding(
  bindings : Array[ResolvedBinding],
  name : String,
) -> ResolvedBinding? {
  for binding in bindings {
    if binding.name == name {
      return Some(binding)
    }
  }
  None
}

///|
fn replace_binding(
  bindings : Array[ResolvedBinding],
  replacement : ResolvedBinding,
) -> Unit {
  for i = 0; i < bindings.length(); i = i + 1 {
    if bindings[i].name == replacement.name {
      bindings[i] = replacement
      return
    }
  }
  bindings.push(replacement)
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
fn literal_parsed_option(
  options : Array[ParsedOption],
  name : String,
) -> String? {
  for option in options {
    if option.name == name {
      match option.value {
        LiteralOption(value) => return Some(value)
        VariableOption(_) => return None
      }
    }
  }
  None
}

///|
fn is_quoted_literal(value : String) -> Bool {
  value.length() >= 2 && value.has_prefix("|") && value.has_suffix("|")
}

///|
fn unquote_literal(value : String) -> String {
  if is_quoted_literal(value) {
    value[1:value.length() - 1]
    .to_owned()
    .replace_all(old="\\|", new="|")
    .replace_all(old="\\\\", new="\\")
  } else {
    value
  }
}

///|
fn valid_identifier(value : String) -> Bool {
  if value.is_empty() {
    return false
  }
  for char in value.to_array() {
    if !((char >= 'a' && char <= 'z') ||
      (char >= 'A' && char <= 'Z') ||
      (char >= '0' && char <= '9') ||
      char == '_' ||
      char == '-' ||
      char == '.' ||
      char == ':') {
      return false
    }
  }
  true
}

///|
fn valid_unquoted_literal(value : String) -> Bool {
  if value.is_empty() ||
    value.has_prefix("$") ||
    value.has_prefix(":") ||
    value.has_prefix("#") ||
    value.has_prefix("/") ||
    value.has_prefix("@") {
    return false
  }
  for char in value.to_array() {
    if char == '{' || char == '}' || char == '|' || char == '\\' {
      return false
    }
  }
  true
}

///|
fn push_pattern_text(nodes : Array[PatternNode], text : StringBuilder) -> Unit {
  let value = text.to_string()
  if !value.is_empty() {
    nodes.push(PatternText(value))
    text.reset()
  }
}

///|
fn find_expression_end(chars : Array[Char], start : Int) -> Int? {
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
fn extract_quoted_pattern(
  chars : Array[Char],
  start : Int,
) -> Result[(String, Int), Mf2Error] {
  if !starts_with_chars(chars, start, "{{") {
    return Err(mf2_error(Mf2SyntaxError, "expected quoted pattern", start))
  }
  let out : Array[Char] = []
  let mut cursor = start + 2
  while cursor < chars.length() {
    if chars[cursor] == '\\' {
      if cursor + 1 >= chars.length() {
        return Err(mf2_error(Mf2SyntaxError, "trailing escape", cursor))
      }
      out.push(chars[cursor])
      out.push(chars[cursor + 1])
      cursor = cursor + 2
    } else if chars[cursor] == '{' {
      let close = match find_expression_end(chars, cursor) {
        Some(value) => value
        None =>
          return Err(mf2_error(Mf2SyntaxError, "unclosed expression", cursor))
      }
      for i = cursor; i <= close; i = i + 1 {
        out.push(chars[i])
      }
      cursor = close + 1
    } else if chars[cursor] == '}' &&
      cursor + 1 < chars.length() &&
      chars[cursor + 1] == '}' {
      return Ok((String::from_array(out), cursor + 2))
    } else {
      out.push(chars[cursor])
      cursor = cursor + 1
    }
  }
  Err(mf2_error(Mf2SyntaxError, "unclosed quoted pattern", start))
}

///|
fn find_quoted_pattern_start(chars : Array[Char], start : Int) -> Int? {
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
fn chars_slice(chars : Array[Char], start : Int, end : Int) -> String {
  let result : Array[Char] = []
  for i = start; i < end; i = i + 1 {
    result.push(chars[i])
  }
  String::from_array(result)
}

///|
fn starts_with_chars(chars : Array[Char], start : Int, value : String) -> Bool {
  let expected = value.to_array()
  if start + expected.length() > chars.length() {
    return false
  }
  for i = 0; i < expected.length(); i = i + 1 {
    if chars[start + i] != expected[i] {
      return false
    }
  }
  true
}

///|
fn line_end(chars : Array[Char], start : Int) -> Int {
  let mut cursor = start
  while cursor < chars.length() &&
        chars[cursor] != '\n' &&
        chars[cursor] != '\r' {
    cursor = cursor + 1
  }
  cursor
}

///|
fn skip_layout(chars : Array[Char], start : Int) -> Int {
  let mut cursor = start
  while cursor < chars.length() && is_layout_char(chars[cursor]) {
    cursor = cursor + 1
  }
  cursor
}

///|
fn is_layout_char(char : Char) -> Bool {
  char == ' ' || char == '\t' || char == '\n' || char == '\r'
}
