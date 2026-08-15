///|
extern "js" fn browser_fixture_source() -> String =
  #| () => globalThis.__LAMPCLAW_MF2_BROWSER_FIXTURES__ ?? "[]"

///|
extern "js" fn publish_browser_results(source : String) -> Unit =
  #| source => { globalThis.__LAMPCLAW_MF2_BROWSER_RESULTS__ = source }

///|
fn json_string(object : Map[String, Json], name : String) -> String {
  match object.get(name) {
    Some(String(value)) => value
    _ => abort("browser conformance field must be a string: \{name}")
  }
}

///|
fn parse_number(source : String) -> Double? {
  try @string.parse_double(source) catch {
    _ => None
  } noraise {
    value => Some(value)
  }
}

///|
fn fixture_inputs(raw : Json?) -> Array[@runtime.Mf2Input] {
  let inputs : Array[@runtime.Mf2Input] = []
  guard raw is Some(Array(parameters)) else { return inputs }
  for value in parameters {
    guard value is Object(parameter) else {
      abort("browser conformance parameter must be an object")
    }
    let name = json_string(parameter, "name")
    let kind = json_string(parameter, "type")
    let message_value = match kind {
      "string" | "datetime" =>
        @runtime.TextValue(json_string(parameter, "value"))
      "int" =>
        match parameter.get("value") {
          Some(Number(value, ..)) => @runtime.IntValue(value.to_int())
          _ => abort("browser int parameter must be numeric")
        }
      "double" =>
        match parameter.get("value") {
          Some(Number(value, ..)) => @runtime.DoubleValue(value)
          _ => abort("browser double parameter must be numeric")
        }
      "bool" =>
        match parameter.get("value") {
          Some(True) => @runtime.BoolValue(true)
          Some(False) => @runtime.BoolValue(false)
          _ => abort("browser bool parameter must be boolean")
        }
      _ => abort("unsupported browser parameter type: \{kind}")
    }
    inputs.push(@runtime.Mf2Input::new(name, message_value))
  }
  inputs
}

///|
fn error_code(error : @runtime.Mf2Error) -> String {
  match error.code {
    @runtime.Mf2SyntaxCode => "syntax-error"
    @runtime.Mf2DataModelCode => "data-model-error"
    @runtime.Mf2ResolutionCode => "resolution-error"
    @runtime.Mf2VariantKeyMismatchCode => "variant-key-mismatch"
    @runtime.Mf2MissingFallbackVariantCode => "missing-fallback-variant"
    @runtime.Mf2MissingSelectorAnnotationCode => "missing-selector-annotation"
    @runtime.Mf2DuplicateDeclarationCode => "duplicate-declaration"
    @runtime.Mf2DuplicateOptionNameCode => "duplicate-option-name"
    @runtime.Mf2DuplicateVariantCode => "duplicate-variant"
    @runtime.Mf2UnresolvedVariableCode => "unresolved-variable"
    @runtime.Mf2UnknownFunctionCode => "unknown-function"
    @runtime.Mf2BadSelectorCode => "bad-selector"
    @runtime.Mf2BadOperandCode => "bad-operand"
    @runtime.Mf2BadOptionCode => "bad-option"
    @runtime.Mf2BadVariantKeyCode => "bad-variant-key"
    @runtime.Mf2UnsupportedOperationCode => "unsupported-operation"
    @runtime.Mf2FormattingCode => "formatting-error"
    @runtime.Mf2LimitCode => "limit-error"
  }
}

///|
fn message_value_number(value : @runtime.MessageValue?) -> Double? {
  match value {
    Some(@runtime.IntValue(value)) => Some(value.to_double())
    Some(@runtime.DoubleValue(value)) => Some(value)
    Some(@runtime.TextValue(value)) => parse_number(value)
    _ => None
  }
}

///|
fn inherited_option(
  options : Array[@runtime.FormatOption],
  name : String,
) -> String? {
  for option in options {
    if option.name == name {
      return Some(option.value)
    }
  }
  None
}

///|
fn test_number_string(value : Double, decimal_places : Int) -> String {
  let sign = if value < 0.0 { "-" } else { "" }
  let absolute = if value < 0.0 { -value } else { value }
  let integer = absolute.trunc().to_int()
  if decimal_places == 0 {
    sign + integer.to_string()
  } else {
    let digit = ((absolute - integer.to_double()) * 10.0).trunc().to_int()
    sign + integer.to_string() + "." + digit.to_string()
  }
}

///|
fn test_function_handler(name : String) -> @runtime.Mf2FunctionHandler {
  @runtime.Mf2FunctionHandler::new(name~, resolve=(_context, operand, options) => {
    guard operand is Some(operand) else {
      return Err(@runtime.Mf2FunctionBadOperand(":\{name} requires an operand"))
    }
    guard message_value_number(operand.raw()) is Some(input) else {
      return Err(
        @runtime.Mf2FunctionBadOperand(":\{name} requires a numeric operand"),
      )
    }
    let inherited = operand.inherited_options()
    let mut decimal_places = match
      inherited_option(inherited, "test:decimalPlaces") {
      Some("1") => 1
      _ => 0
    }
    let mut fails_format = inherited_option(inherited, "test:failsFormat") ==
      Some("true")
    let mut fails_select = inherited_option(inherited, "test:failsSelect") ==
      Some("true")
    for option in options {
      match option.name {
        "decimalPlaces" =>
          match option.value {
            "0" => decimal_places = 0
            "1" => decimal_places = 1
            _ =>
              return Err(
                @runtime.Mf2FunctionBadOption("decimalPlaces must be 0 or 1"),
              )
          }
        "fails" =>
          match option.value {
            "never" => {
              fails_format = false
              fails_select = false
            }
            "format" => fails_format = true
            "select" => fails_select = true
            "always" => {
              fails_format = true
              fails_select = true
            }
            _ =>
              return Err(
                @runtime.Mf2FunctionBadOption("fails has an invalid value"),
              )
          }
        _ => ()
      }
    }
    let formatted = test_number_string(input, decimal_places)
    let format = if name == "test:select" {
      () => {
        Err(@runtime.Mf2FunctionUnsupported(":test:select is not formattable"))
      }
    } else if fails_format {
      () => {
        Err(@runtime.Mf2FunctionBadOption("test function formatting failed"))
      }
    } else {
      () => Ok(@runtime.FormatterOutput::{ value: formatted, parts: [] })
    }
    let match_key = if name == "test:format" {
      None
    } else if fails_select {
      Some(_key => {
        Err(@runtime.Mf2FunctionBadSelector("test function selection failed"))
      })
    } else {
      Some(key => {
        let matches = if decimal_places == 1 {
          key == "1" || key == "1.0"
        } else {
          key == "1"
        }
        Ok(input == 1.0 && matches)
      })
    }
    let better_than = if name == "test:format" {
      None
    } else {
      Some((left, _right) => Ok(left == "1.0"))
    }
    Ok(
      @runtime.Mf2FunctionValue::new(
        raw=Some(@runtime.DoubleValue(input)),
        format~,
        match_key~,
        better_than~,
        inherited_options=[
          { name: "test:input", value: input.to_string() },
          { name: "test:decimalPlaces", value: decimal_places.to_string() },
          { name: "test:failsFormat", value: fails_format.to_string() },
          { name: "test:failsSelect", value: fails_select.to_string() },
        ],
      ),
    )
  })
}

///|
fn browser_registry() -> @runtime.Mf2FunctionRegistry {
  let registry = @runtime.Mf2FunctionRegistry::new(@runtime_js.formatter())
  for name in ["test:function", "test:select", "test:format"] {
    match registry.register_custom(test_function_handler(name)) {
      Ok(_) => ()
      Err(message) => abort(message)
    }
  }
  registry
}

///|
fn fixture_direction(locale : String) -> @runtime.Mf2Direction {
  if locale == "ar" ||
    locale.has_prefix("ar-") ||
    locale == "he" ||
    locale.has_prefix("he-") ||
    locale == "fa" ||
    locale.has_prefix("fa-") ||
    locale == "ur" ||
    locale.has_prefix("ur-") {
    @runtime.Mf2RightToLeft
  } else {
    @runtime.Mf2LeftToRight
  }
}

///|
fn fixture_field(value : String) -> String {
  "\{value.length()}:" + value
}

///|
fn part_signatures(parts : Array[@runtime.Mf2FormattedPart]) -> Array[String] {
  parts.map(part => {
    match part {
      @runtime.Mf2FormattedText(value) => "text|" + fixture_field(value)
      @runtime.Mf2FormattedBidiIsolation(value) =>
        "bidi|" + fixture_field(value)
      @runtime.Mf2FormattedExpressionPart(value) =>
        if value.fallback {
          "fallback|" + fixture_field(value.value)
        } else {
          let direction = match value.direction {
            @runtime.Mf2LeftToRight => "ltr"
            @runtime.Mf2RightToLeft => "rtl"
            @runtime.Mf2DirectionUnknown => "unknown"
          }
          "expression|" +
          fixture_field(value.function_name.unwrap_or("")) +
          "|" +
          direction +
          "|" +
          fixture_field(value.id.unwrap_or("")) +
          "|" +
          fixture_field(value.value)
        }
      @runtime.Mf2FormattedMarkupPart(value) => {
        let kind = match value.kind {
          @runtime.Mf2MarkupOpen => "open"
          @runtime.Mf2MarkupClose => "close"
          @runtime.Mf2MarkupStandalone => "standalone"
        }
        "markup|" +
        kind +
        "|" +
        fixture_field(value.name) +
        "|" +
        fixture_field(value.id.unwrap_or(""))
      }
    }
  })
}

///|
fn number_fields(parts : Array[@runtime.Mf2FormattedPart]) -> Array[String] {
  let fields : Array[String] = []
  for part in parts {
    match part {
      @runtime.Mf2FormattedExpressionPart(expression) =>
        for field in expression.fields {
          fields.push(field.kind + "|" + field.value)
        }
      _ => ()
    }
  }
  fields
}

///|
fn run_syntax_case(object : Map[String, Json]) -> Json {
  let source = json_string(object, "source")
  let errors = match @runtime.parse_mf2_syntax(source) {
    Err(error) => [error_code(error)]
    Ok(model) =>
      if json_string(object, "kind") == "data-model" {
        @runtime.validate_mf2_model(model).map(error_code)
      } else {
        []
      }
  }
  Json::object({
    "id": Json::string(json_string(object, "id")),
    "errorCodes": Json::array(errors.map(Json::string)),
  })
}

///|
fn run_format_case(
  object : Map[String, Json],
  registry : @runtime.Mf2FunctionRegistry,
) -> Json {
  let locale = json_string(object, "locale")
  let isolation = match object.get("bidiIsolation") {
    Some(String("none")) => @runtime.Mf2NoBidiIsolation
    _ => @runtime.Mf2DefaultBidiIsolation
  }
  let context = match
    @runtime.Mf2FormattingContext::new(
      locale~,
      inputs=fixture_inputs(object.get("params")),
      direction=fixture_direction(locale),
      time_zone="UTC",
      bidi_isolation=isolation,
    ) {
    Ok(value) => value
    Err(error) => abort(error.message)
  }
  let result = @runtime.format_mf2(
    json_string(object, "source"),
    context,
    registry,
  )
  Json::object({
    "id": Json::string(json_string(object, "id")),
    "value": Json::string(result.value),
    "errorCodes": Json::array(
      result.errors.map(error => Json::string(error_code(error))),
    ),
    "partSignatures": Json::array(
      part_signatures(result.parts).map(Json::string),
    ),
    "numberFields": Json::array(number_fields(result.parts).map(Json::string)),
  })
}

///|
fn main {
  let fixture = try @json.parse(browser_fixture_source()) catch {
    _ => abort("invalid browser conformance fixture JSON")
  } noraise {
    value => value
  }
  guard fixture is Array(cases) else {
    abort("browser conformance fixture root must be an array")
  }
  let registry = browser_registry()
  let results = cases.map(raw => {
    guard raw is Object(object) else {
      abort("browser conformance case must be an object")
    }
    match json_string(object, "kind") {
      "syntax" | "data-model" => run_syntax_case(object)
      "format" => run_format_case(object, registry)
      kind => abort("unsupported browser conformance kind: \{kind}")
    }
  })
  publish_browser_results(Json::array(results).stringify())
}
