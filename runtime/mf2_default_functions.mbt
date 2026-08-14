///|
/// Resolves the Unicode MF2 default functions pinned by
/// `MF2_DEFAULT_REGISTRY_PROFILE`.
fn mf2_resolve_default_function(
  registry : Mf2FunctionRegistry,
  context : Mf2FunctionContext,
  name : String,
  operand : Mf2ResolvedValue?,
  options : Array[Mf2ResolvedOption],
) -> Mf2ProviderResult {
  match name {
    "string" => mf2_resolve_string_function(context, operand, options)
    "number" | "integer" | "offset" | "currency" | "percent" =>
      mf2_resolve_number_function(
        registry.formatter,
        context,
        name,
        operand,
        options,
      )
    "date" | "time" | "datetime" =>
      mf2_resolve_datetime_function(
        registry.formatter,
        context,
        name,
        operand,
        options,
      )
    _ => Mf2ProviderUnknown
  }
}

///|
fn mf2_resolve_string_function(
  context : Mf2FunctionContext,
  operand : Mf2ResolvedValue?,
  options : Array[Mf2ResolvedOption],
) -> Mf2ProviderResult {
  ignore(context)
  guard operand is Some(operand) else {
    return Mf2ProviderFailure(
      Mf2HandlerBadOperand(":string requires an operand"),
    )
  }
  guard operand.raw is Some(raw) else {
    return Mf2ProviderFailure(
      Mf2HandlerBadOperand(":string operand could not be unwrapped"),
    )
  }
  // `:string` defines no built-in options. Unknown future or namespaced
  // options are ignored, as permitted by the default-function contract.
  ignore(options)
  let rendered = message_value_to_string(raw)
  let normalized = @normalization.nfc(rendered)
  Mf2ProviderValue(
    {
      raw: Some(TextValue(rendered)),
      render: () => Ok({ value: rendered, parts: [] }),
      match_key: Some(key => Ok(normalized == key)),
      better_than: Some((_left, _right) => Ok(false)),
      direction: operand.direction,
      isolate: false,
      id: None,
      options: [],
      metadata: [],
      fallback_source: None,
      function_name: Some("string"),
    },
    [],
  )
}

///|
priv struct Mf2NumericOperand {
  value : Double
  inherited : Array[FormatOption]
  producer : String?
  direction : Mf2Direction
}

///|
fn mf2_unwrap_numeric_operand(
  function_name : String,
  operand : Mf2ResolvedValue?,
) -> Result[Mf2NumericOperand, Mf2HandlerFailure] {
  guard operand is Some(operand) else {
    return Err(
      Mf2HandlerBadOperand(":\{function_name} requires a numeric operand"),
    )
  }
  let number = match operand.raw {
    Some(IntValue(value)) => value.to_double()
    Some(DoubleValue(value)) => value
    Some(TextValue(value)) =>
      match parse_numeric_literal(value) {
        Some(number) => number
        None =>
          return Err(
            Mf2HandlerBadOperand(
              ":\{function_name} requires a finite numeric operand",
            ),
          )
      }
    _ =>
      return Err(
        Mf2HandlerBadOperand(
          ":\{function_name} requires a finite numeric operand",
        ),
      )
  }
  if number.is_nan() || number.is_inf() {
    return Err(
      Mf2HandlerBadOperand(
        ":\{function_name} requires a finite numeric operand",
      ),
    )
  }
  Ok({
    value: number,
    inherited: operand.metadata.copy(),
    producer: operand.function_name,
    direction: operand.direction,
  })
}

///|
fn mf2_resolve_number_function(
  formatter : Formatter,
  context : Mf2FunctionContext,
  function_name : String,
  operand : Mf2ResolvedValue?,
  own_options : Array[Mf2ResolvedOption],
) -> Mf2ProviderResult {
  let numeric = match mf2_unwrap_numeric_operand(function_name, operand) {
    Ok(value) => value
    Err(failure) => return Mf2ProviderFailure(failure)
  }
  if function_name == "offset" {
    return mf2_resolve_offset_function(formatter, context, numeric, own_options)
  }
  if function_name == "currency" {
    return mf2_resolve_currency_function(
      formatter, context, numeric, own_options,
    )
  }
  let issues : Array[Mf2HandlerFailure] = []
  let inherited = mf2_number_inherited_options(function_name, numeric.inherited)
  let merged = inherited.copy()
  let own_select = mf2_find_resolved_option(own_options, "select")
  for option in own_options {
    if mf2_number_option_known(function_name, option.name) {
      match mf2_validate_number_option(function_name, option) {
        Ok(normalized) => mf2_replace_format_option(merged, normalized)
        Err(failure) => issues.push(failure)
      }
    }
  }
  let mut selectable = function_name != "currency"
  let mut select_mode = "plural"
  if function_name != "percent" {
    match own_select {
      Some(option) =>
        if !option.literal {
          issues.push(
            Mf2HandlerBadOption(
              ":\{function_name} select must be set by a literal",
            ),
          )
          selectable = false
          mf2_remove_format_option(merged, "select")
        } else {
          match mf2_option_value(merged, "select") {
            Some(value) => select_mode = value
            None => ()
          }
        }
      None =>
        match mf2_option_value(inherited, "select") {
          Some(_) => {
            issues.push(
              Mf2HandlerBadOption(
                ":\{function_name} cannot inherit the select option",
              ),
            )
            selectable = false
            mf2_remove_format_option(merged, "select")
          }
          None => ()
        }
    }
  }
  let value = if function_name == "integer" {
    numeric.value.trunc()
  } else {
    numeric.value
  }
  let semantic_options = merged.copy()
  if function_name == "percent" &&
    mf2_option_value(semantic_options, "minimumFractionDigits") is None &&
    mf2_option_value(semantic_options, "maximumFractionDigits") is None {
    semantic_options.push({ name: "minimumFractionDigits", value: "0" })
    semantic_options.push({ name: "maximumFractionDigits", value: "0" })
  }
  let formatter_options = mf2_number_formatter_options(
    function_name, semantic_options,
  )
  let selection_value = if function_name == "percent" {
    value * 100.0
  } else {
    value
  }
  let exact = mf2_exact_number_serialization(selection_value, semantic_options)
  let match_key = if selectable {
    Some(key => {
      mf2_number_matches(
        formatter,
        context.locales[0],
        selection_value,
        exact,
        select_mode,
        semantic_options,
        key,
      )
    })
  } else {
    None
  }
  let better_than = if selectable {
    Some((left, right) => {
      Ok(
        parse_numeric_literal(left) is Some(_) &&
        parse_numeric_literal(right) is None,
      )
    })
  } else {
    None
  }
  let raw = if function_name == "integer" {
    DoubleValue(value)
  } else {
    DoubleValue(numeric.value)
  }
  Mf2ProviderValue(
    {
      raw: Some(raw),
      render: () => {
        match
          (formatter.format_number_to_parts)(
            context.locales[0],
            value,
            formatter_options,
          ) {
          Ok(output) => Ok(output)
          Err(issue) => Err(mf2_formatter_issue_to_handler(issue))
        }
      },
      match_key,
      better_than,
      direction: numeric.direction,
      isolate: false,
      id: None,
      options: [],
      metadata: semantic_options,
      fallback_source: None,
      function_name: Some(function_name),
    },
    issues,
  )
}

///|
fn mf2_resolve_offset_function(
  formatter : Formatter,
  context : Mf2FunctionContext,
  numeric : Mf2NumericOperand,
  options : Array[Mf2ResolvedOption],
) -> Mf2ProviderResult {
  let mut operator = ""
  let mut amount = 0.0
  for option in options {
    if option.name == "add" || option.name == "subtract" {
      if !operator.is_empty() {
        return Mf2ProviderFailure(
          Mf2HandlerBadOption(":offset requires exactly one of add or subtract"),
        )
      }
      guard mf2_digit_size_option(option.value) else {
        return Mf2ProviderFailure(
          Mf2HandlerBadOption(
            ":offset \{option.name} must be a digit-size option",
          ),
        )
      }
      operator = option.name
      amount = match parse_numeric_literal(option.value) {
        Some(value) => value
        None => 0.0
      }
    }
  }
  if operator.is_empty() {
    return Mf2ProviderFailure(
      Mf2HandlerBadOption(":offset requires exactly one of add or subtract"),
    )
  }
  let value = if operator == "add" {
    numeric.value + amount
  } else {
    numeric.value - amount
  }
  if value.is_nan() || value.is_inf() {
    return Mf2ProviderFailure(
      Mf2HandlerUnsupported(":offset result exceeds the numeric range"),
    )
  }
  let semantic_options = mf2_number_inherited_options(
    "number",
    numeric.inherited,
  )
  let issues : Array[Mf2HandlerFailure] = []
  let mut selectable = true
  let mut select_mode = "plural"
  match mf2_option_value(semantic_options, "select") {
    Some(_) => {
      issues.push(
        Mf2HandlerBadOption(":offset cannot inherit the select option"),
      )
      selectable = false
      mf2_remove_format_option(semantic_options, "select")
    }
    None => ()
  }
  match mf2_option_value(semantic_options, "select") {
    Some(value) => select_mode = value
    None => ()
  }
  let formatter_options = mf2_number_formatter_options(
    "number", semantic_options,
  )
  let exact = mf2_exact_number_serialization(value, semantic_options)
  Mf2ProviderValue(
    {
      raw: Some(DoubleValue(value)),
      render: () => {
        match
          (formatter.format_number_to_parts)(
            context.locales[0],
            value,
            formatter_options,
          ) {
          Ok(output) => Ok(output)
          Err(issue) => Err(mf2_formatter_issue_to_handler(issue))
        }
      },
      match_key: if selectable {
        Some(key => {
          mf2_number_matches(
            formatter,
            context.locales[0],
            value,
            exact,
            select_mode,
            semantic_options,
            key,
          )
        })
      } else {
        None
      },
      better_than: if selectable {
        Some((left, right) => {
          Ok(
            parse_numeric_literal(left) is Some(_) &&
            parse_numeric_literal(right) is None,
          )
        })
      } else {
        None
      },
      direction: numeric.direction,
      isolate: false,
      id: None,
      options: [],
      metadata: semantic_options,
      fallback_source: None,
      function_name: Some("offset"),
    },
    issues,
  )
}

///|
fn mf2_resolve_currency_function(
  formatter : Formatter,
  context : Mf2FunctionContext,
  numeric : Mf2NumericOperand,
  own_options : Array[Mf2ResolvedOption],
) -> Mf2ProviderResult {
  let inherited = mf2_number_inherited_options("currency", numeric.inherited)
  let typed_currency = numeric.producer == Some("currency") &&
    mf2_option_value(inherited, "currency") is Some(_)
  let own_currency = mf2_find_resolved_option(own_options, "currency")
  if typed_currency && own_currency is Some(_) {
    return Mf2ProviderFailure(
      Mf2HandlerBadOption(":currency cannot override an operand currency"),
    )
  }
  let merged = inherited.copy()
  let issues : Array[Mf2HandlerFailure] = []
  for option in own_options {
    if mf2_number_option_known("currency", option.name) {
      match mf2_validate_number_option("currency", option) {
        Ok(normalized) => mf2_replace_format_option(merged, normalized)
        Err(failure) => issues.push(failure)
      }
    }
  }
  guard mf2_option_value(merged, "currency") is Some(currency) else {
    return Mf2ProviderFailure(
      Mf2HandlerBadOperand(
        ":currency requires a currency option for a numeric operand",
      ),
    )
  }
  guard mf2_currency_identifier(currency) else {
    return Mf2ProviderFailure(
      Mf2HandlerBadOption(":currency currency must contain three ASCII letters"),
    )
  }
  let semantic_options = merged.copy()
  let formatter_options = mf2_number_formatter_options(
    "currency", semantic_options,
  )
  Mf2ProviderValue(
    {
      raw: Some(DoubleValue(numeric.value)),
      render: () => {
        match
          (formatter.format_number_to_parts)(
            context.locales[0],
            numeric.value,
            formatter_options,
          ) {
          Ok(output) => Ok(output)
          Err(issue) => Err(mf2_formatter_issue_to_handler(issue))
        }
      },
      match_key: None,
      better_than: None,
      direction: numeric.direction,
      isolate: false,
      id: None,
      options: [],
      metadata: semantic_options,
      fallback_source: None,
      function_name: Some("currency"),
    },
    issues,
  )
}

///|
fn mf2_number_inherited_options(
  function_name : String,
  inherited : Array[FormatOption],
) -> Array[FormatOption] {
  let result : Array[FormatOption] = []
  for option in inherited {
    let discarded = match function_name {
      "integer" =>
        option.name == "minimumFractionDigits" ||
        option.name == "maximumFractionDigits" ||
        option.name == "minimumSignificantDigits"
      "percent" =>
        option.name == "minimumIntegerDigits" ||
        option.name == "roundingIncrement" ||
        option.name == "select"
      _ => false
    }
    if !discarded && mf2_number_option_known(function_name, option.name) {
      mf2_replace_format_option(result, option)
    }
  }
  result
}

///|
fn mf2_number_option_known(function_name : String, name : String) -> Bool {
  match function_name {
    "number" =>
      name == "select" ||
      name == "signDisplay" ||
      name == "useGrouping" ||
      name == "minimumIntegerDigits" ||
      name == "minimumFractionDigits" ||
      name == "maximumFractionDigits" ||
      name == "minimumSignificantDigits" ||
      name == "maximumSignificantDigits" ||
      name == "trailingZeroDisplay" ||
      name == "roundingPriority" ||
      name == "roundingIncrement" ||
      name == "roundingMode"
    "integer" =>
      name == "select" ||
      name == "signDisplay" ||
      name == "useGrouping" ||
      name == "minimumIntegerDigits" ||
      name == "maximumSignificantDigits"
    "currency" =>
      name == "currency" ||
      name == "currencySign" ||
      name == "currencyDisplay" ||
      name == "useGrouping" ||
      name == "minimumIntegerDigits" ||
      name == "fractionDigits" ||
      name == "minimumSignificantDigits" ||
      name == "maximumSignificantDigits" ||
      name == "trailingZeroDisplay" ||
      name == "roundingPriority" ||
      name == "roundingIncrement" ||
      name == "roundingMode"
    "percent" =>
      name == "signDisplay" ||
      name == "useGrouping" ||
      name == "minimumFractionDigits" ||
      name == "maximumFractionDigits" ||
      name == "minimumSignificantDigits" ||
      name == "maximumSignificantDigits" ||
      name == "trailingZeroDisplay" ||
      name == "roundingPriority" ||
      name == "roundingMode"
    _ => false
  }
}

///|
fn mf2_validate_number_option(
  function_name : String,
  option : Mf2ResolvedOption,
) -> Result[FormatOption, Mf2HandlerFailure] {
  let value = option.value
  let valid = match option.name {
    "select" => value == "plural" || value == "ordinal" || value == "exact"
    "signDisplay" =>
      value == "auto" ||
      value == "always" ||
      value == "exceptZero" ||
      value == "negative" ||
      value == "never"
    "useGrouping" =>
      value == "auto" ||
      value == "always" ||
      value == "never" ||
      value == "min2"
    "minimumIntegerDigits"
    | "minimumSignificantDigits"
    | "maximumSignificantDigits" =>
      mf2_digit_size_option(value) &&
      (match parse_numeric_literal(value) {
        Some(number) => number <= 21.0
        None => false
      })
    "minimumFractionDigits" | "maximumFractionDigits" =>
      mf2_digit_size_option(value)
    "trailingZeroDisplay" => value == "auto" || value == "stripIfInteger"
    "roundingPriority" =>
      value == "auto" || value == "morePrecision" || value == "lessPrecision"
    "roundingIncrement" => mf2_rounding_increment(value)
    "roundingMode" =>
      value == "ceil" ||
      value == "floor" ||
      value == "expand" ||
      value == "trunc" ||
      value == "halfCeil" ||
      value == "halfFloor" ||
      value == "halfExpand" ||
      value == "halfTrunc" ||
      value == "halfEven"
    "currency" => mf2_currency_identifier(value)
    "currencySign" => value == "accounting" || value == "standard"
    "currencyDisplay" =>
      value == "narrowSymbol" ||
      value == "symbol" ||
      value == "name" ||
      value == "code" ||
      value == "never"
    "fractionDigits" => value == "auto" || mf2_digit_size_option(value)
    _ => true
  }
  if !valid {
    return Err(
      Mf2HandlerBadOption(
        "invalid :\{function_name} option \{option.name}=\{value}",
      ),
    )
  }
  let normalized = match option.name {
    "minimumIntegerDigits"
    | "minimumSignificantDigits"
    | "maximumSignificantDigits" if value == "0" => "1"
    _ => value
  }
  Ok({ name: option.name, value: normalized })
}

///|
fn mf2_number_formatter_options(
  function_name : String,
  semantic : Array[FormatOption],
) -> Array[FormatOption] {
  let result : Array[FormatOption] = []
  for option in semantic {
    if option.name == "select" || option.name == "fractionDigits" {
      continue
    }
    result.push(option)
  }
  match mf2_option_value(semantic, "fractionDigits") {
    Some(value) if value != "auto" => {
      mf2_replace_format_option(result, { name: "minimumFractionDigits", value })
      mf2_replace_format_option(result, { name: "maximumFractionDigits", value })
    }
    _ => ()
  }
  match function_name {
    "integer" => result.push({ name: "integer", value: "true" })
    "currency" => result.push({ name: "style", value: "currency" })
    "percent" => result.push({ name: "style", value: "percent" })
    _ => ()
  }
  result
}

///|
fn mf2_number_matches(
  formatter : Formatter,
  locale : String,
  value : Double,
  exact : String,
  select_mode : String,
  options : Array[FormatOption],
  key : String,
) -> Result[Bool, Mf2HandlerFailure] {
  if parse_numeric_literal(key) is Some(_) {
    return Ok(key == exact)
  }
  if !mf2_plural_keyword(key) {
    return Err(Mf2HandlerBadVariantKey("invalid numeric variant key: \{key}"))
  }
  if select_mode == "exact" {
    return Ok(false)
  }
  let plural_options = options.filter(option => {
    option.name != "select" &&
    option.name != "signDisplay" &&
    option.name != "useGrouping" &&
    option.name != "trailingZeroDisplay" &&
    option.name != "currency" &&
    option.name != "currencySign" &&
    option.name != "currencyDisplay" &&
    option.name != "fractionDigits"
  })
  match
    (formatter.plural_category_with_options)(
      locale,
      value,
      select_mode == "ordinal",
      plural_options,
    ) {
    Ok(category) => Ok(category == key)
    Err(issue) => Err(mf2_formatter_issue_to_handler(issue))
  }
}

///|
fn mf2_exact_number_serialization(
  value : Double,
  options : Array[FormatOption],
) -> String {
  let constrained = mf2_option_value(options, "minimumFractionDigits")
    is Some(_) ||
    mf2_option_value(options, "minimumIntegerDigits") is Some(_) ||
    mf2_option_value(options, "minimumSignificantDigits") is Some(_) ||
    mf2_option_value(options, "maximumSignificantDigits") is Some(_)
  if !constrained && value == 0.0 {
    "0"
  } else if !constrained && value.trunc() == value {
    value.trunc().to_string()
  } else {
    value.to_string()
  }
}

///|
fn mf2_plural_keyword(value : String) -> Bool {
  value == "zero" ||
  value == "one" ||
  value == "two" ||
  value == "few" ||
  value == "many" ||
  value == "other"
}

///|
fn mf2_digit_size_option(value : String) -> Bool {
  let chars = value.to_array()
  if chars.is_empty() || chars.length() > 2 {
    return false
  }
  if chars.length() == 2 && chars[0] == '0' {
    return false
  }
  chars.all(char => char >= '0' && char <= '9')
}

///|
fn mf2_rounding_increment(value : String) -> Bool {
  value == "1" ||
  value == "2" ||
  value == "5" ||
  value == "10" ||
  value == "20" ||
  value == "25" ||
  value == "50" ||
  value == "100" ||
  value == "200" ||
  value == "250" ||
  value == "500" ||
  value == "1000" ||
  value == "2000" ||
  value == "2500" ||
  value == "5000"
}

///|
fn mf2_currency_identifier(value : String) -> Bool {
  let chars = value.to_array()
  if chars.length() != 3 {
    return false
  }
  chars.all(char => (char >= 'a' && char <= 'z') || (char >= 'A' && char <= 'Z'))
}

///|
fn mf2_find_resolved_option(
  options : Array[Mf2ResolvedOption],
  name : String,
) -> Mf2ResolvedOption? {
  for option in options {
    if option.name == name {
      return Some(option)
    }
  }
  None
}

///|
fn mf2_option_value(options : Array[FormatOption], name : String) -> String? {
  for option in options {
    if option.name == name {
      return Some(option.value)
    }
  }
  None
}

///|
fn mf2_replace_format_option(
  options : Array[FormatOption],
  value : FormatOption,
) -> Unit {
  for index = 0; index < options.length(); index = index + 1 {
    if options[index].name == value.name {
      options[index] = value
      return
    }
  }
  options.push(value)
}

///|
fn mf2_remove_format_option(
  options : Array[FormatOption],
  name : String,
) -> Unit {
  let mut index = 0
  while index < options.length() {
    if options[index].name == name {
      ignore(options.remove(index))
    } else {
      index = index + 1
    }
  }
}

///|
fn mf2_formatter_issue_to_handler(issue : FormatterIssue) -> Mf2HandlerFailure {
  match issue {
    UnsupportedOperation(message) => Mf2HandlerUnsupported(message)
    InvalidFormatterOption(message) => Mf2HandlerBadOption(message)
    PlatformFormatterFailure(message) => Mf2HandlerFormatting(message)
  }
}

///|
priv struct Mf2DateLiteralInfo {
  has_zone : Bool
}

///|
fn mf2_resolve_datetime_function(
  formatter : Formatter,
  context : Mf2FunctionContext,
  function_name : String,
  operand : Mf2ResolvedValue?,
  own_options : Array[Mf2ResolvedOption],
) -> Mf2ProviderResult {
  guard operand is Some(operand) else {
    return Mf2ProviderFailure(
      Mf2HandlerBadOperand(":\{function_name} requires a date/time operand"),
    )
  }
  guard operand.raw is Some(raw) else {
    return Mf2ProviderFailure(
      Mf2HandlerBadOperand(":\{function_name} requires a date/time operand"),
    )
  }
  let has_zone = match raw {
    InstantMillis(_) => true
    TextValue(value) =>
      match mf2_validate_date_literal(value) {
        Some(info) => info.has_zone
        None =>
          return Mf2ProviderFailure(
            Mf2HandlerBadOperand(
              ":\{function_name} requires an ISO 8601 date/time operand",
            ),
          )
      }
    _ =>
      return Mf2ProviderFailure(
        Mf2HandlerBadOperand(":\{function_name} requires a date/time operand"),
      )
  }
  let issues : Array[Mf2HandlerFailure] = []
  let semantic = mf2_datetime_inherited_options(operand.metadata)
  for option in own_options {
    if !mf2_datetime_option_known(function_name, option.name) {
      continue
    }
    if mf2_datetime_option_requires_literal(function_name, option.name) &&
      !option.literal {
      issues.push(
        Mf2HandlerBadOption(
          ":\{function_name} option \{option.name} must be a literal",
        ),
      )
      continue
    }
    match mf2_validate_datetime_option(function_name, option) {
      Ok(value) => mf2_replace_format_option(semantic, value)
      Err(failure) => issues.push(failure)
    }
  }
  let mut resolved_time_zone = context.time_zone
  match mf2_option_value(semantic, "timeZone") {
    Some("input") =>
      if has_zone {
        resolved_time_zone = "input"
      } else {
        issues.push(
          Mf2HandlerBadOperand(
            ":\{function_name} timeZone=input requires a zoned operand",
          ),
        )
      }
    Some(value) => resolved_time_zone = value
    None => ()
  }
  let formatter_options = mf2_datetime_formatter_options(
    function_name, semantic, resolved_time_zone,
  )
  Mf2ProviderValue(
    {
      raw: Some(raw),
      render: () => {
        match
          (formatter.format_datetime_value)(
            context.locales[0],
            raw,
            formatter_options,
          ) {
          Ok(output) => Ok(output)
          Err(issue) => Err(mf2_formatter_issue_to_handler(issue))
        }
      },
      match_key: None,
      better_than: None,
      direction: operand.direction,
      isolate: false,
      id: None,
      options: [],
      metadata: semantic,
      fallback_source: None,
      function_name: Some(function_name),
    },
    issues,
  )
}

///|
fn mf2_datetime_inherited_options(
  inherited : Array[FormatOption],
) -> Array[FormatOption] {
  inherited.filter(option => {
    option.name == "timeZone" ||
    option.name == "hour12" ||
    option.name == "calendar"
  })
}

///|
fn mf2_datetime_option_known(function_name : String, name : String) -> Bool {
  let is_override = name == "timeZone" || name == "hour12" || name == "calendar"
  match function_name {
    "datetime" =>
      is_override ||
      name == "dateFields" ||
      name == "dateLength" ||
      name == "timePrecision" ||
      name == "timeZoneStyle"
    "date" =>
      name == "timeZone" ||
      name == "calendar" ||
      name == "fields" ||
      name == "length"
    "time" => is_override || name == "precision" || name == "timeZoneStyle"
    _ => false
  }
}

///|
fn mf2_datetime_option_requires_literal(
  function_name : String,
  name : String,
) -> Bool {
  match function_name {
    "datetime" =>
      name == "dateFields" ||
      name == "dateLength" ||
      name == "timePrecision" ||
      name == "timeZoneStyle"
    "date" => name == "fields" || name == "length"
    "time" => name == "precision" || name == "timeZoneStyle"
    _ => false
  }
}

///|
fn mf2_validate_datetime_option(
  function_name : String,
  option : Mf2ResolvedOption,
) -> Result[FormatOption, Mf2HandlerFailure] {
  let value = option.value
  let valid = match option.name {
    "dateFields" | "fields" =>
      value == "weekday" ||
      value == "day-weekday" ||
      value == "month-day" ||
      value == "month-day-weekday" ||
      value == "year-month-day" ||
      value == "year-month-day-weekday"
    "dateLength" | "length" =>
      value == "long" || value == "medium" || value == "short"
    "timePrecision" | "precision" =>
      value == "hour" || value == "minute" || value == "second"
    "timeZoneStyle" => value == "long" || value == "short"
    "timeZone" => !value.is_empty()
    "hour12" => value == "true" || value == "false"
    "calendar" => mf2_unicode_uvalue(value)
    _ => true
  }
  if valid {
    Ok({ name: option.name, value })
  } else {
    Err(
      Mf2HandlerBadOption(
        "invalid :\{function_name} option \{option.name}=\{value}",
      ),
    )
  }
}

///|
fn mf2_datetime_formatter_options(
  function_name : String,
  semantic : Array[FormatOption],
  time_zone : String,
) -> Array[FormatOption] {
  let result : Array[FormatOption] = []
  result.push({ name: "timeZone", value: time_zone })
  for option in semantic {
    if option.name == "hour12" || option.name == "calendar" {
      result.push(option)
    }
  }
  let date_fields = match function_name {
    "datetime" =>
      match mf2_option_value(semantic, "dateFields") {
        Some(value) => value
        None => "year-month-day"
      }
    "date" =>
      match mf2_option_value(semantic, "fields") {
        Some(value) => value
        None => "year-month-day"
      }
    _ => ""
  }
  let date_length = match function_name {
    "datetime" =>
      match mf2_option_value(semantic, "dateLength") {
        Some(value) => value
        None => "medium"
      }
    "date" =>
      match mf2_option_value(semantic, "length") {
        Some(value) => value
        None => "medium"
      }
    _ => ""
  }
  if function_name == "date" || function_name == "datetime" {
    mf2_add_date_fields(result, date_fields, date_length)
  }
  if function_name == "time" || function_name == "datetime" {
    let precision = match function_name {
      "datetime" =>
        match mf2_option_value(semantic, "timePrecision") {
          Some(value) => value
          None => "minute"
        }
      _ =>
        match mf2_option_value(semantic, "precision") {
          Some(value) => value
          None => "minute"
        }
    }
    result.push({ name: "hour", value: "numeric" })
    if precision == "minute" || precision == "second" {
      result.push({ name: "minute", value: "2-digit" })
    }
    if precision == "second" {
      result.push({ name: "second", value: "2-digit" })
    }
    match mf2_option_value(semantic, "timeZoneStyle") {
      Some(value) => result.push({ name: "timeZoneName", value })
      None => ()
    }
  }
  result
}

///|
fn mf2_add_date_fields(
  result : Array[FormatOption],
  fields : String,
  length : String,
) -> Unit {
  let weekday = fields == "weekday" ||
    fields == "day-weekday" ||
    fields == "month-day-weekday" ||
    fields == "year-month-day-weekday"
  let day = fields == "day-weekday" ||
    fields == "month-day" ||
    fields == "month-day-weekday" ||
    fields == "year-month-day" ||
    fields == "year-month-day-weekday"
  let month = fields == "month-day" ||
    fields == "month-day-weekday" ||
    fields == "year-month-day" ||
    fields == "year-month-day-weekday"
  let year = fields == "year-month-day" || fields == "year-month-day-weekday"
  if weekday {
    result.push({
      name: "weekday",
      value: if length == "long" {
        "long"
      } else {
        "short"
      },
    })
  }
  if year {
    result.push({
      name: "year",
      value: if length == "short" {
        "2-digit"
      } else {
        "numeric"
      },
    })
  }
  if month {
    result.push({
      name: "month",
      value: match length {
        "long" => "long"
        "medium" => "short"
        _ => "numeric"
      },
    })
  }
  if day {
    result.push({ name: "day", value: "numeric" })
  }
}

///|
fn mf2_unicode_uvalue(value : String) -> Bool {
  let parts : Array[String] = value
    .split("-")
    .map(part => part.to_owned())
    .collect()
  if parts.is_empty() {
    return false
  }
  parts.all(part => {
    let chars = part.to_array()
    chars.length() >= 3 &&
    chars.length() <= 8 &&
    chars.all(char => {
      (char >= 'a' && char <= 'z') ||
      (char >= 'A' && char <= 'Z') ||
      (char >= '0' && char <= '9')
    })
  })
}

///|
fn mf2_validate_date_literal(value : String) -> Mf2DateLiteralInfo? {
  let chars = value.to_array()
  if chars.length() != 10 && chars.length() < 19 {
    return None
  }
  guard mf2_ascii_digits(chars, 0, 4) &&
    chars[4] == '-' &&
    mf2_ascii_digits(chars, 5, 2) &&
    chars[7] == '-' &&
    mf2_ascii_digits(chars, 8, 2) else {
    return None
  }
  let year = mf2_ascii_number(chars, 0, 4)
  let month = mf2_ascii_number(chars, 5, 2)
  let day = mf2_ascii_number(chars, 8, 2)
  if year == 0 ||
    month < 1 ||
    month > 12 ||
    day < 1 ||
    day > mf2_days_in_month(year, month) {
    return None
  }
  if chars.length() == 10 {
    return Some({ has_zone: false })
  }
  guard chars[10] == 'T' &&
    mf2_ascii_digits(chars, 11, 2) &&
    chars[13] == ':' &&
    mf2_ascii_digits(chars, 14, 2) &&
    chars[16] == ':' &&
    mf2_ascii_digits(chars, 17, 2) else {
    return None
  }
  let hour = mf2_ascii_number(chars, 11, 2)
  let minute = mf2_ascii_number(chars, 14, 2)
  let second = mf2_ascii_number(chars, 17, 2)
  if hour > 23 || minute > 59 || second > 59 {
    return None
  }
  let mut cursor = 19
  if cursor < chars.length() && chars[cursor] == '.' {
    cursor = cursor + 1
    let start = cursor
    while cursor < chars.length() &&
          chars[cursor] >= '0' &&
          chars[cursor] <= '9' {
      cursor = cursor + 1
    }
    let digits = cursor - start
    if digits < 1 || digits > 3 {
      return None
    }
  }
  if cursor == chars.length() {
    return Some({ has_zone: false })
  }
  if chars[cursor] == 'Z' && cursor + 1 == chars.length() {
    return Some({ has_zone: true })
  }
  guard (chars[cursor] == '+' || chars[cursor] == '-') &&
    cursor + 6 == chars.length() &&
    mf2_ascii_digits(chars, cursor + 1, 2) &&
    chars[cursor + 3] == ':' &&
    mf2_ascii_digits(chars, cursor + 4, 2) else {
    return None
  }
  let zone_hour = mf2_ascii_number(chars, cursor + 1, 2)
  let zone_minute = mf2_ascii_number(chars, cursor + 4, 2)
  if zone_hour > 14 || zone_minute > 59 || (zone_hour == 14 && zone_minute != 0) {
    None
  } else {
    Some({ has_zone: true })
  }
}

///|
fn mf2_ascii_digits(chars : Array[Char], start : Int, length : Int) -> Bool {
  if start < 0 || length < 0 || start + length > chars.length() {
    return false
  }
  for index = start; index < start + length; index = index + 1 {
    if chars[index] < '0' || chars[index] > '9' {
      return false
    }
  }
  true
}

///|
fn mf2_ascii_number(chars : Array[Char], start : Int, length : Int) -> Int {
  let mut value = 0
  for index = start; index < start + length; index = index + 1 {
    value = value * 10 + chars[index].to_int() - '0'.to_int()
  }
  value
}

///|
fn mf2_days_in_month(year : Int, month : Int) -> Int {
  match month {
    2 =>
      if year % 400 == 0 || (year % 4 == 0 && year % 100 != 0) {
        29
      } else {
        28
      }
    4 | 6 | 9 | 11 => 30
    _ => 31
  }
}
