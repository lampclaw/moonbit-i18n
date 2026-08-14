///|
priv struct Mf2TestFunctionState {
  input : Double
  decimal_places : Int
  fails_format : Bool
  fails_select : Bool
}

///|
fn mf2_test_provider() -> Mf2FunctionProvider {
  {
    resolve: (context, name, operand, options) => {
      ignore(context)
      match name {
        "test:function" | "test:select" | "test:format" =>
          mf2_resolve_test_function(name, operand, options)
        "string" => mf2_resolve_test_string(operand)
        "number" => mf2_resolve_test_number(context.direction, operand, options)
        _ => Mf2ProviderUnknown
      }
    },
  }
}

///|
fn mf2_resolve_test_string(operand : Mf2ResolvedValue?) -> Mf2ProviderResult {
  guard operand is Some(value) else {
    return Mf2ProviderFailure(
      Mf2HandlerBadOperand(":string requires an operand"),
    )
  }
  guard value.raw is Some(raw) else {
    return Mf2ProviderFailure(
      Mf2HandlerBadOperand(":string operand could not be unwrapped"),
    )
  }
  let rendered = message_value_to_string(raw)
  Mf2ProviderValue({
    raw: Some(TextValue(rendered)),
    render: () => Ok(rendered),
    match_key: Some(key => Ok(@normalization.nfc(rendered) == key)),
    better_than: Some((_left, _right) => Ok(false)),
    direction: Mf2DirectionUnknown,
    isolate: false,
    id: None,
    options: [],
    metadata: [],
    fallback_source: None,
    function_name: Some("string"),
  })
}

///|
fn mf2_resolve_test_number(
  direction : Mf2Direction,
  operand : Mf2ResolvedValue?,
  options : Array[Mf2ResolvedOption],
) -> Mf2ProviderResult {
  guard operand is Some(value) else {
    return Mf2ProviderFailure(
      Mf2HandlerBadOperand(":number requires an operand"),
    )
  }
  let number = match value.raw {
    Some(IntValue(value)) => Some(value.to_double())
    Some(DoubleValue(value)) => Some(value)
    Some(TextValue(value)) => parse_numeric_literal(value)
    _ => None
  }
  guard number is Some(number) else {
    return Mf2ProviderFailure(
      Mf2HandlerBadOperand(":number requires a numeric operand"),
    )
  }
  let mut minimum_fraction_digits = 0
  for option in options {
    if option.name == "minimumFractionDigits" {
      match option.value {
        "0" => minimum_fraction_digits = 0
        "1" => minimum_fraction_digits = 1
        _ =>
          return Mf2ProviderFailure(
            Mf2HandlerBadOption(
              "test :number supports minimumFractionDigits 0 or 1",
            ),
          )
      }
    }
  }
  let rendered = mf2_test_number_string(number, minimum_fraction_digits)
  Mf2ProviderValue({
    raw: Some(DoubleValue(number)),
    render: () => Ok(rendered),
    match_key: Some(key => {
      Ok(
        match parse_numeric_literal(key) {
          Some(candidate) => candidate == number
          None => false
        },
      )
    }),
    better_than: Some((_left, _right) => Ok(false)),
    direction,
    isolate: false,
    id: None,
    options: [],
    metadata: [],
    fallback_source: None,
    function_name: Some("number"),
  })
}

///|
fn mf2_resolve_test_function(
  name : String,
  operand : Mf2ResolvedValue?,
  options : Array[Mf2ResolvedOption],
) -> Mf2ProviderResult {
  guard operand is Some(operand) else {
    return Mf2ProviderFailure(
      Mf2HandlerBadOperand(":\{name} requires an operand"),
    )
  }
  let mut state = match mf2_test_state_from_operand(operand) {
    Some(value) => value
    None =>
      return Mf2ProviderFailure(
        Mf2HandlerBadOperand(":\{name} requires a numeric operand"),
      )
  }
  for option in options {
    match option.name {
      "decimalPlaces" =>
        match option.value {
          "0" => state = { ..state, decimal_places: 0 }
          "1" => state = { ..state, decimal_places: 1 }
          _ =>
            return Mf2ProviderFailure(
              Mf2HandlerBadOption("decimalPlaces must be 0 or 1"),
            )
        }
      "fails" =>
        match option.value {
          "never" =>
            state = { ..state, fails_format: false, fails_select: false }
          "format" => state = { ..state, fails_format: true }
          "select" => state = { ..state, fails_select: true }
          "always" =>
            state = { ..state, fails_format: true, fails_select: true }
          _ =>
            return Mf2ProviderFailure(
              Mf2HandlerBadOption("fails has an invalid value"),
            )
        }
      _ => ()
    }
  }
  let formatted = mf2_test_number_string(state.input, state.decimal_places)
  let render : () -> Result[String, Mf2HandlerFailure] = if name ==
    "test:select" {
    () => Err(Mf2HandlerUnsupported(":test:select is not formattable"))
  } else if state.fails_format {
    () => Err(Mf2HandlerBadOption("test function formatting failed"))
  } else {
    () => Ok(formatted)
  }
  let match_key : ((String) -> Result[Bool, Mf2HandlerFailure])? = if name ==
    "test:format" {
    None
  } else if state.fails_select {
    Some(_key => Err(Mf2HandlerBadSelector("test function selection failed")))
  } else {
    Some(key => {
      let matches = if state.decimal_places == 1 {
        key == "1" || key == "1.0"
      } else {
        key == "1"
      }
      Ok(state.input == 1.0 && matches)
    })
  }
  let better_than : ((String, String) -> Result[Bool, Mf2HandlerFailure])? = if name ==
    "test:format" {
    None
  } else {
    Some((left, _right) => Ok(left == "1.0"))
  }
  Mf2ProviderValue({
    raw: Some(DoubleValue(state.input)),
    render,
    match_key,
    better_than,
    direction: Mf2DirectionUnknown,
    isolate: false,
    id: None,
    options: [],
    metadata: [
      { name: "test:input", value: state.input.to_string() },
      { name: "test:decimalPlaces", value: state.decimal_places.to_string() },
      { name: "test:failsFormat", value: state.fails_format.to_string() },
      { name: "test:failsSelect", value: state.fails_select.to_string() },
    ],
    fallback_source: None,
    function_name: Some(name),
  })
}

///|
fn mf2_test_state_from_operand(
  operand : Mf2ResolvedValue,
) -> Mf2TestFunctionState? {
  match option_value(operand.metadata, "test:input") {
    Some(input) => {
      let number = parse_numeric_literal(input)
      guard number is Some(number) else { return None }
      Some({
        input: number,
        decimal_places: if option_value(operand.metadata, "test:decimalPlaces") ==
          Some("1") {
          1
        } else {
          0
        },
        fails_format: option_value(operand.metadata, "test:failsFormat") ==
        Some("true"),
        fails_select: option_value(operand.metadata, "test:failsSelect") ==
        Some("true"),
      })
    }
    None => {
      let input = match operand.raw {
        Some(IntValue(value)) => Some(value.to_double())
        Some(DoubleValue(value)) => Some(value)
        Some(TextValue(value)) => parse_numeric_literal(value)
        _ => None
      }
      match input {
        Some(input) =>
          Some({
            input,
            decimal_places: 0,
            fails_format: false,
            fails_select: false,
          })
        None => None
      }
    }
  }
}

///|
fn mf2_test_number_string(value : Double, decimal_places : Int) -> String {
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
fn mf2_test_context(
  inputs? : Array[Mf2Input] = [],
  direction? : Mf2Direction = Mf2DirectionUnknown,
  bidi_isolation? : Mf2BidiIsolation = Mf2NoBidiIsolation,
) -> Mf2FormattingContext {
  match
    Mf2FormattingContext::new(
      locale="en-US",
      inputs~,
      direction~,
      bidi_isolation~,
    ) {
    Ok(value) => value
    Err(error) => abort(error.message)
  }
}

///|
fn mf2_fixture_context(
  locale : String,
  inputs : Array[Mf2Input],
  bidi_isolation : Mf2BidiIsolation,
) -> Mf2FormattingContext {
  let direction = if locale == "ar" ||
    locale.has_prefix("ar-") ||
    locale == "he" ||
    locale.has_prefix("he-") ||
    locale == "fa" ||
    locale.has_prefix("fa-") ||
    locale == "ur" ||
    locale.has_prefix("ur-") {
    Mf2RightToLeft
  } else {
    Mf2LeftToRight
  }
  match
    Mf2FormattingContext::new(locale~, inputs~, direction~, bidi_isolation~) {
    Ok(value) => value
    Err(error) => abort(error.message)
  }
}

///|
fn mf2_fixture_field(value : String) -> String {
  "\{value.length()}:" + value
}

///|
fn mf2_fixture_part_signatures(
  parts : Array[Mf2FormattedPart],
) -> Array[String] {
  parts.map(part => {
    match part {
      Mf2FormattedText(value) => "text|" + mf2_fixture_field(value)
      Mf2FormattedBidiIsolation(value) => "bidi|" + mf2_fixture_field(value)
      Mf2FormattedExpressionPart(value) =>
        if value.fallback {
          "fallback|" + mf2_fixture_field(value.value)
        } else {
          let direction = match value.direction {
            Mf2LeftToRight => "ltr"
            Mf2RightToLeft => "rtl"
            Mf2DirectionUnknown => "unknown"
          }
          "expression|" +
          mf2_fixture_field(
            match value.function_name {
              Some(name) => name
              None => ""
            },
          ) +
          "|" +
          direction +
          "|" +
          mf2_fixture_field(
            match value.id {
              Some(id) => id
              None => ""
            },
          ) +
          "|" +
          mf2_fixture_field(value.value)
        }
      Mf2FormattedMarkupPart(value) => {
        let kind = match value.kind {
          Mf2MarkupOpen => "open"
          Mf2MarkupClose => "close"
          Mf2MarkupStandalone => "standalone"
        }
        "markup|" +
        kind +
        "|" +
        mf2_fixture_field(value.name) +
        "|" +
        mf2_fixture_field(
          match value.id {
            Some(id) => id
            None => ""
          },
        )
      }
    }
  })
}

///|
test "standalone resolver implements normative pattern ranking" {
  let result = format_mf2_with_provider(
    ".local $x = {1 :test:select decimalPlaces=1} .match $x 1 {{one}} 1.0 {{one-point-zero}} * {{other}}",
    mf2_test_context(),
    mf2_test_provider(),
  )
  assert_eq(result.value, "one-point-zero")
  assert_eq(result.errors, [])
}

///|
test "standalone resolver compares multiple selectors in source order" {
  let result = format_mf2_with_provider(
    ".local $x = {1 :test:function} .local $y = {0 :test:function} .match $x $y 1 1 {{1,1}} 1 * {{1,*}} * 1 {{*,1}} * * {{*,*}}",
    mf2_test_context(),
    mf2_test_provider(),
  )
  assert_eq(result.value, "1,*")
  assert_eq(result.errors, [])
}

///|
test "selector failure selects catch-all and reports bad-selector" {
  let result = format_mf2_with_provider(
    ".local $x = {1 :test:select fails=select} .match $x 1 {{one}} * {{other}}",
    mf2_test_context(),
    mf2_test_provider(),
  )
  assert_eq(result.value, "other")
  assert_true(result.errors.any(error => error.code == Mf2BadSelectorCode))
}

///|
test "function formatting failures produce expression fallback" {
  let result = format_mf2_with_provider(
    "{42 :test:function fails=format}",
    mf2_test_context(),
    mf2_test_provider(),
  )
  assert_eq(result.value, "{|42|}")
  assert_true(result.errors.any(error => error.code == Mf2BadOptionCode))
}

///|
test "declaration fallback is represented by its bound variable" {
  let result = format_mf2_with_provider(
    ".local $var = {|val| :test:undefined} {{{$var}}}",
    mf2_test_context(),
    mf2_test_provider(),
  )
  assert_eq(result.value, "{$var}")
  assert_true(result.errors.any(error => error.code == Mf2UnknownFunctionCode))
}

///|
test "u:dir and u:id control structured expression output" {
  let result = format_mf2_with_provider(
    "hello {world :string u:dir=ltr u:id=foo @note=label}",
    mf2_test_context(
      direction=Mf2LeftToRight,
      bidi_isolation=Mf2DefaultBidiIsolation,
    ),
    mf2_test_provider(),
  )
  assert_eq(result.value, "hello \u{2066}world\u{2069}")
  assert_eq(result.errors, [])
  guard result.parts[2] is Mf2FormattedExpressionPart(expression) else {
    fail("expected expression part")
  }
  assert_eq(expression.direction, Mf2LeftToRight)
  assert_eq(expression.id, Some("foo"))
  assert_eq(expression.attributes, [{ name: "note", value: Some("label") }])
}

///|
test "unselected patterns are not resolved" {
  let result = format_mf2_with_provider(
    ".local $x = {1 :test:function} .match $x 1 {{ok}} * {{{:undefined}}}",
    mf2_test_context(),
    mf2_test_provider(),
  )
  assert_eq(result.value, "ok")
  assert_eq(result.errors, [])
}

///|
test "declaration expressions are evaluated at most once" {
  let calls = [0]
  let provider = Mf2FunctionProvider::{
    resolve: (_context, name, operand, _options) => {
      if name != "test:counter" {
        return Mf2ProviderUnknown
      }
      calls[0] = calls[0] + 1
      guard operand is Some(value) else {
        return Mf2ProviderFailure(Mf2HandlerBadOperand("missing operand"))
      }
      Mf2ProviderValue(value)
    },
  }
  let result = format_mf2_with_provider(
    ".local $x = {one :test:counter} {{ {$x} {$x} }}",
    mf2_test_context(),
    provider,
  )
  assert_eq(result.value, " one one ")
  assert_eq(result.errors, [])
  assert_eq(calls[0], 1)
}
