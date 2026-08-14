///|
/// Pinned Unicode MessageFormat resolution and formatting-core profile.
pub const MF2_RESOLUTION_PROFILE : String = "unicode-mf2-ldml48.2-resolution-v1"

///|
/// Maximum UTF-8 size emitted by one standalone MF2 formatting operation.
pub const MF2_MAX_OUTPUT_BYTES : Int = 65536

///|
/// Direction metadata used by MF2 bidirectional isolation.
pub(all) enum Mf2Direction {
  /// Left-to-right formatted value or message context.
  Mf2LeftToRight
  /// Right-to-left formatted value or message context.
  Mf2RightToLeft
  /// Directionality is not known without inspecting formatted text.
  Mf2DirectionUnknown
} derive(Eq, Debug)

///|
/// Bidirectional isolation strategy for standalone MF2 formatting.
pub(all) enum Mf2BidiIsolation {
  /// Apply the normative default Unicode-isolate strategy.
  Mf2DefaultBidiIsolation
  /// Emit no added bidirectional controls.
  Mf2NoBidiIsolation
} derive(Eq, Debug)

///|
/// One named input value with explicit direction metadata.
pub(all) struct Mf2Input {
  /// NFC-normalized variable name without `$`.
  name : String
  /// Typed input value.
  value : MessageValue
  /// Direction metadata supplied by the application, not inferred from text.
  direction : Mf2Direction
} derive(Eq, Debug)

///|
/// Creates one standalone MF2 input. Names are normalized to Unicode NFC.
pub fn Mf2Input::new(
  name : String,
  value : MessageValue,
  direction? : Mf2Direction = Mf2DirectionUnknown,
) -> Mf2Input {
  { name: @normalization.nfc(name), value, direction }
}

///|
/// Immutable standalone MF2 formatting context.
pub struct Mf2FormattingContext {
  locales : Array[String]
  inputs : Array[Mf2Input]
  direction : Mf2Direction
  time_zone : String
  fallback : String
  bidi_isolation : Mf2BidiIsolation
}

///|
/// Creates a strict formatting context and canonicalizes its locale chain.
/// The first locale is current; later entries are passed to function
/// providers as ordered fallback locales.
pub fn Mf2FormattingContext::new(
  locale~ : String,
  fallback_locales? : Array[String] = [],
  inputs? : Array[Mf2Input] = [],
  direction? : Mf2Direction = Mf2DirectionUnknown,
  time_zone? : String = "UTC",
  fallback? : String = "",
  bidi_isolation? : Mf2BidiIsolation = Mf2DefaultBidiIsolation,
) -> Result[Mf2FormattingContext, LocaleError] {
  let locales : Array[String] = []
  let primary = match canonicalize_locale_tag(locale) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  locales.push(primary)
  for fallback_locale in fallback_locales {
    let canonical = match canonicalize_locale_tag(fallback_locale) {
      Ok(value) => value
      Err(error) => return Err(error)
    }
    if !locales.contains(canonical) {
      locales.push(canonical)
    }
  }
  Ok({
    locales,
    inputs: inputs.copy(),
    direction,
    time_zone,
    fallback,
    bidi_isolation,
  })
}

///|
/// Returns the canonical current locale.
pub fn Mf2FormattingContext::locale(self : Mf2FormattingContext) -> String {
  self.locales[0]
}

///|
/// Returns a copy of the canonical current and fallback locale chain.
pub fn Mf2FormattingContext::locales(
  self : Mf2FormattingContext,
) -> Array[String] {
  self.locales.copy()
}

///|
/// Returns the application-provided default time-zone identifier.
pub fn Mf2FormattingContext::time_zone(self : Mf2FormattingContext) -> String {
  self.time_zone
}

///|
/// One resolved expression in structured MF2 output.
pub(all) struct Mf2FormattedExpression {
  /// Formatted or fallback string representation.
  value : String
  /// Function identifier without `:`, or `None` for an unannotated value.
  function_name : String?
  /// Direction metadata used for isolation.
  direction : Mf2Direction
  /// Resolved `u:id`, if present and valid.
  id : String?
  /// Resolved non-`u:` options retained as inert structured data.
  options : Array[FormatOption]
  /// Ordered platform formatter fields, such as number or date parts.
  fields : Array[FormatterPart]
  /// Source attributes retained as inert structured data.
  attributes : Array[Mf2ModelAttribute]
  /// Whether `value` is the braces-included normative fallback rendering.
  fallback : Bool
} derive(Eq, Debug)

///|
/// One resolved markup placeholder in structured MF2 output.
pub(all) struct Mf2FormattedMarkup {
  /// Open, close, or standalone markup kind.
  kind : Mf2ModelMarkupKind
  /// Markup identifier without syntax sigils.
  name : String
  /// Resolved non-`u:` options retained as inert structured data.
  options : Array[FormatOption]
  /// Source attributes retained as inert structured data.
  attributes : Array[Mf2ModelAttribute]
  /// Resolved `u:id`, if present and valid.
  id : String?
} derive(Eq, Debug)

///|
/// One safe, renderer-independent part of standalone MF2 output.
pub(all) enum Mf2FormattedPart {
  /// Literal pattern text.
  Mf2FormattedText(String)
  /// Resolved expression data; no renderer callback is executed.
  Mf2FormattedExpressionPart(Mf2FormattedExpression)
  /// Inert markup event; this is never interpreted as HTML or DOM source.
  Mf2FormattedMarkupPart(Mf2FormattedMarkup)
  /// LRI, RLI, FSI, or PDI inserted by the selected bidi strategy.
  Mf2FormattedBidiIsolation(String)
} derive(Eq, Debug)

///|
/// Best-effort standalone formatting output and every discovered error.
pub(all) struct Mf2FormatResult {
  /// Concatenated plain-text output. Markup contributes an empty string.
  value : String
  /// Structured text, expression, markup, and bidi-control parts.
  parts : Array[Mf2FormattedPart]
  /// Deterministically ordered syntax, model, resolution, or function errors.
  errors : Array[Mf2Error]
} derive(Eq, Debug)

///|
priv enum Mf2HandlerFailure {
  Mf2HandlerBadOperand(String)
  Mf2HandlerBadOption(String)
  Mf2HandlerBadSelector(String)
  Mf2HandlerBadVariantKey(String)
  Mf2HandlerUnsupported(String)
  Mf2HandlerFormatting(String)
}

///|
priv struct Mf2ResolvedOption {
  name : String
  raw : MessageValue?
  value : String
  literal : Bool
}

///|
priv struct Mf2ResolvedValue {
  raw : MessageValue?
  render : () -> Result[FormatterOutput, Mf2HandlerFailure]
  match_key : ((String) -> Result[Bool, Mf2HandlerFailure])?
  better_than : ((String, String) -> Result[Bool, Mf2HandlerFailure])?
  direction : Mf2Direction
  isolate : Bool
  id : String?
  options : Array[FormatOption]
  metadata : Array[FormatOption]
  fallback_source : String?
  function_name : String?
}

///|
priv struct Mf2FunctionContext {
  locales : Array[String]
  direction : Mf2Direction
  time_zone : String
}

///|
priv enum Mf2ProviderResult {
  Mf2ProviderUnknown
  Mf2ProviderFailure(Mf2HandlerFailure)
  Mf2ProviderValue(Mf2ResolvedValue, Array[Mf2HandlerFailure])
}

///|
priv struct Mf2FunctionProvider {
  resolve : (
    Mf2FunctionContext,
    String,
    Mf2ResolvedValue?,
    Array[Mf2ResolvedOption],
  ) -> Mf2ProviderResult
}

///|
/// Parses, validates, and best-effort formats source using the portable
/// pinned default registry. Locale-neutral string and basic numeric behavior
/// is available on every target; CLDR-dependent operations report an explicit
/// unsupported-operation error unless a platform registry is supplied.
pub fn format_mf2_standalone(
  source : String,
  context : Mf2FormattingContext,
) -> Mf2FormatResult {
  format_mf2(source, context, Mf2FunctionRegistry::portable())
}

///|
/// Validates and best-effort formats an interchange model using the
/// standalone resolution profile.
pub fn format_mf2_model_standalone(
  model : Mf2MessageModel,
  context : Mf2FormattingContext,
) -> Mf2FormatResult {
  format_mf2_model(model, context, Mf2FunctionRegistry::portable())
}

///|
fn format_mf2_with_provider(
  source : String,
  context : Mf2FormattingContext,
  provider : Mf2FunctionProvider,
) -> Mf2FormatResult {
  let model = match parse_mf2_syntax(source) {
    Ok(value) => value
    Err(error) => return mf2_message_fallback(context, [error])
  }
  format_mf2_model_with_provider(model, context, provider)
}

///|
fn format_mf2_model_with_provider(
  model : Mf2MessageModel,
  context : Mf2FormattingContext,
  provider : Mf2FunctionProvider,
) -> Mf2FormatResult {
  let shape_errors = validate_mf2_model_shape(model)
  if !shape_errors.is_empty() {
    return mf2_message_fallback(context, shape_errors)
  }
  let model_errors = validate_mf2_model(model)
  if !model_errors.is_empty() {
    return mf2_message_fallback(context, model_errors)
  }
  let errors : Array[Mf2Error] = []
  let inputs = mf2_resolve_inputs(context.inputs, errors)
  if errors.any(error => error.kind == Mf2LimitError) {
    return mf2_message_fallback(context, errors)
  }
  let declarations = match model {
    Mf2PatternMessage(value, _) | Mf2SelectMessage(value, _, _) => value
  }
  let bindings : Map[String, Mf2ResolvedValue] = Map([])
  for declaration in declarations {
    let (name, expression) = match declaration {
      Mf2ModelInput(name, expression) | Mf2ModelLocal(name, expression) =>
        (name, expression)
    }
    let resolved = mf2_resolve_expression(
      expression, bindings, inputs, context, provider, errors,
    )
    bindings[name] = resolved
  }
  let pattern = match model {
    Mf2PatternMessage(_, pattern) => pattern
    Mf2SelectMessage(_, selectors, variants) =>
      mf2_select_pattern(selectors, variants, bindings, inputs, errors)
  }
  let result = mf2_format_pattern(
    pattern, bindings, inputs, context, provider, errors,
  )
  if @utf8.encode(result.value).length() > MF2_MAX_OUTPUT_BYTES {
    errors.push({
      kind: Mf2LimitError,
      code: Mf2LimitCode,
      message: "formatted output exceeds the \{MF2_MAX_OUTPUT_BYTES}-byte limit",
      offset: 0,
    })
    mf2_message_fallback(context, errors)
  } else {
    result
  }
}

///|
priv struct Mf2UniversalResolution {
  handler_options : Array[Mf2ResolvedOption]
  structured_options : Array[FormatOption]
  direction : Mf2Direction?
  isolate : Bool
  id : String?
}

///|
fn mf2_resolve_inputs(
  configured : Array[Mf2Input],
  errors : Array[Mf2Error],
) -> Map[String, Mf2ResolvedValue] {
  let inputs : Map[String, Mf2ResolvedValue] = Map([])
  if configured.length() > MF2_MAX_ARGUMENTS {
    errors.push({
      kind: Mf2LimitError,
      code: Mf2LimitCode,
      message: "formatting exceeds the \{MF2_MAX_ARGUMENTS}-input limit",
      offset: 0,
    })
    return inputs
  }
  for input in configured {
    let name = @normalization.nfc(input.name)
    let name_errors : Array[Mf2Error] = []
    validate_mf2_model_name(name, false, 0, name_errors)
    if !name_errors.is_empty() {
      errors.push({
        kind: Mf2ResolutionError,
        code: Mf2ResolutionCode,
        message: "invalid MF2 input name: \{input.name}",
        offset: 0,
      })
      continue
    }
    if inputs.contains(name) {
      errors.push({
        kind: Mf2ResolutionError,
        code: Mf2ResolutionCode,
        message: "duplicate MF2 input: \{name}",
        offset: 0,
      })
      continue
    }
    inputs[name] = mf2_plain_resolved(input.value, input.direction)
  }
  inputs
}

///|
fn mf2_plain_resolved(
  value : MessageValue,
  direction : Mf2Direction,
) -> Mf2ResolvedValue {
  let rendered = message_value_to_string(value)
  {
    raw: Some(value),
    render: () => Ok({ value: rendered, parts: [] }),
    match_key: None,
    better_than: None,
    direction,
    isolate: false,
    id: None,
    options: [],
    metadata: [],
    fallback_source: None,
    function_name: None,
  }
}

///|
fn mf2_fallback_resolved(source : String) -> Mf2ResolvedValue {
  let rendered = "{" + source + "}"
  {
    raw: None,
    render: () => Ok({ value: rendered, parts: [] }),
    match_key: None,
    better_than: None,
    direction: Mf2DirectionUnknown,
    isolate: false,
    id: None,
    options: [],
    metadata: [],
    fallback_source: Some(source),
    function_name: None,
  }
}

///|
fn mf2_resolve_variable(
  name : String,
  bindings : Map[String, Mf2ResolvedValue],
  inputs : Map[String, Mf2ResolvedValue],
  offset : Int,
  errors : Array[Mf2Error],
) -> Mf2ResolvedValue {
  let resolved = match bindings.get(name) {
    Some(value) => Some(value)
    None => inputs.get(name)
  }
  match resolved {
    Some(value) =>
      if value.fallback_source is Some(_) {
        let fallback = mf2_fallback_resolved("$" + name)
        { ..fallback, function_name: value.function_name }
      } else {
        value
      }
    None => {
      errors.push({
        kind: Mf2ResolutionError,
        code: Mf2UnresolvedVariableCode,
        message: "unresolved MF2 variable: $\{name}",
        offset,
      })
      mf2_fallback_resolved("$" + name)
    }
  }
}

///|
fn mf2_resolve_expression(
  expression : Mf2ModelExpression,
  bindings : Map[String, Mf2ResolvedValue],
  inputs : Map[String, Mf2ResolvedValue],
  context : Mf2FormattingContext,
  provider : Mf2FunctionProvider,
  errors : Array[Mf2Error],
) -> Mf2ResolvedValue {
  let operand = match expression.arg {
    Some(Mf2ModelLiteral(value)) =>
      Some(mf2_plain_resolved(TextValue(value), Mf2DirectionUnknown))
    Some(Mf2ModelVariable(name)) =>
      Some(
        mf2_resolve_variable(name, bindings, inputs, expression.offset, errors),
      )
    None => None
  }
  match expression.function_ref {
    None =>
      match operand {
        Some(value) => value
        None => mf2_fallback_resolved("�")
      }
    Some(function_ref) => {
      match operand {
        Some(value) if value.fallback_source is Some(_) => {
          if function_ref.name != "string" {
            errors.push({
              kind: Mf2FormattingError,
              code: Mf2BadOperandCode,
              message: "MF2 function operand did not resolve: :\{function_ref.name}",
              offset: expression.offset,
            })
          }
          let fallback = mf2_expression_fallback(expression)
          return if function_ref.name == "string" {
            { ..fallback, function_name: Some("string") }
          } else {
            fallback
          }
        }
        _ => ()
      }
      let resolved_options = mf2_resolve_options(
        function_ref.options,
        bindings,
        inputs,
        expression.offset,
        errors,
      )
      let universal = mf2_resolve_universal_options(
        resolved_options,
        false,
        expression.offset,
        errors,
      )
      let base_direction = match universal.direction {
        Some(value) => value
        None =>
          match operand {
            Some(value) if value.direction != Mf2DirectionUnknown =>
              value.direction
            _ => context.direction
          }
      }
      let function_context = Mf2FunctionContext::{
        locales: context.locales.copy(),
        direction: base_direction,
        time_zone: context.time_zone,
      }
      let provided = (provider.resolve)(
        function_context,
        function_ref.name,
        operand,
        universal.handler_options,
      )
      let value = match provided {
        Mf2ProviderUnknown => {
          errors.push({
            kind: Mf2ResolutionError,
            code: Mf2UnknownFunctionCode,
            message: "unknown MF2 function: :\{function_ref.name}",
            offset: expression.offset,
          })
          return mf2_expression_fallback(expression)
        }
        Mf2ProviderFailure(failure) => {
          mf2_push_handler_failure(errors, failure, expression.offset)
          return mf2_expression_fallback(expression)
        }
        Mf2ProviderValue(value, issues) => {
          for issue in issues {
            mf2_push_handler_failure(errors, issue, expression.offset)
          }
          value
        }
      }
      {
        ..value,
        direction: match universal.direction {
          Some(direction) => direction
          None => value.direction
        },
        isolate: value.isolate || universal.isolate,
        id: match universal.id {
          Some(id) => Some(id)
          None => value.id
        },
        options: universal.structured_options,
        fallback_source: None,
        function_name: Some(function_ref.name),
      }
    }
  }
}

///|
fn mf2_expression_fallback(expression : Mf2ModelExpression) -> Mf2ResolvedValue {
  let source = match expression.arg {
    Some(Mf2ModelVariable(name)) => "$" + name
    Some(Mf2ModelLiteral(value)) =>
      "|" +
      value.replace_all(old="\\", new="\\\\").replace_all(old="|", new="\\|") +
      "|"
    None =>
      match expression.function_ref {
        Some(function_ref) => ":" + function_ref.name
        None => "�"
      }
  }
  mf2_fallback_resolved(source)
}

///|
fn mf2_resolve_options(
  options : Array[Mf2ModelOption],
  bindings : Map[String, Mf2ResolvedValue],
  inputs : Map[String, Mf2ResolvedValue],
  offset : Int,
  errors : Array[Mf2Error],
) -> Array[Mf2ResolvedOption] {
  let result : Array[Mf2ResolvedOption] = []
  for option in options {
    match option.value {
      Mf2ModelLiteral(value) =>
        result.push({
          name: option.name,
          raw: Some(TextValue(value)),
          value,
          literal: true,
        })
      Mf2ModelVariable(name) => {
        let resolved = mf2_resolve_variable(
          name, bindings, inputs, offset, errors,
        )
        if resolved.fallback_source is Some(_) {
          errors.push({
            kind: Mf2FormattingError,
            code: Mf2BadOptionCode,
            message: "MF2 option omitted because $\{name} did not resolve",
            offset,
          })
          continue
        }
        let value = match resolved.raw {
          Some(raw) => message_value_to_string(raw)
          None =>
            match (resolved.render)() {
              Ok(output) => output.value
              Err(failure) => {
                mf2_push_handler_failure(errors, failure, offset)
                errors.push({
                  kind: Mf2FormattingError,
                  code: Mf2BadOptionCode,
                  message: "MF2 option variable could not be unwrapped: $\{name}",
                  offset,
                })
                continue
              }
            }
        }
        result.push({
          name: option.name,
          raw: resolved.raw,
          value,
          literal: false,
        })
      }
    }
  }
  result
}

///|
fn mf2_resolve_universal_options(
  options : Array[Mf2ResolvedOption],
  markup : Bool,
  offset : Int,
  errors : Array[Mf2Error],
) -> Mf2UniversalResolution {
  let handler_options : Array[Mf2ResolvedOption] = []
  let structured_options : Array[FormatOption] = []
  let mut direction : Mf2Direction? = None
  let mut isolate = false
  let mut id : String? = None
  for option in options {
    match option.name {
      "u:id" =>
        match option.raw {
          Some(_) => id = Some(option.value)
          None =>
            errors.push({
              kind: Mf2FormattingError,
              code: Mf2BadOptionCode,
              message: "u:id requires a string-resolvable value",
              offset,
            })
        }
      "u:dir" =>
        if markup {
          errors.push({
            kind: Mf2FormattingError,
            code: Mf2BadOptionCode,
            message: "u:dir is not valid on markup",
            offset,
          })
        } else {
          match option.value {
            "ltr" => {
              direction = Some(Mf2LeftToRight)
              isolate = true
            }
            "rtl" => {
              direction = Some(Mf2RightToLeft)
              isolate = true
            }
            "auto" => {
              direction = Some(Mf2DirectionUnknown)
              isolate = true
            }
            "inherit" => {
              direction = None
              isolate = false
            }
            _ =>
              errors.push({
                kind: Mf2FormattingError,
                code: Mf2BadOptionCode,
                message: "invalid u:dir option: \{option.value}",
                offset,
              })
          }
        }
      _ => {
        handler_options.push(option)
        structured_options.push({ name: option.name, value: option.value })
      }
    }
  }
  { handler_options, structured_options, direction, isolate, id }
}

///|
fn mf2_push_handler_failure(
  errors : Array[Mf2Error],
  failure : Mf2HandlerFailure,
  offset : Int,
) -> Unit {
  let (kind, code, message) = match failure {
    Mf2HandlerBadOperand(message) =>
      (Mf2FormattingError, Mf2BadOperandCode, message)
    Mf2HandlerBadOption(message) =>
      (Mf2FormattingError, Mf2BadOptionCode, message)
    Mf2HandlerBadSelector(message) =>
      (Mf2ResolutionError, Mf2BadSelectorCode, message)
    Mf2HandlerBadVariantKey(message) =>
      (Mf2FormattingError, Mf2BadVariantKeyCode, message)
    Mf2HandlerUnsupported(message) =>
      (Mf2FormattingError, Mf2UnsupportedOperationCode, message)
    Mf2HandlerFormatting(message) =>
      (Mf2FormattingError, Mf2FormattingCode, message)
  }
  if errors.any(error => {
      error.code == code && error.message == message && error.offset == offset
    }) {
    return
  }
  errors.push({ kind, code, message, offset })
}

///|
fn mf2_message_fallback(
  context : Mf2FormattingContext,
  errors : Array[Mf2Error],
) -> Mf2FormatResult {
  let source = if context.fallback.is_empty() ||
    @utf8.encode(context.fallback).length() + 2 > MF2_MAX_OUTPUT_BYTES {
    "�"
  } else {
    context.fallback
  }
  let value = "{" + source + "}"
  {
    value,
    parts: [
      Mf2FormattedExpressionPart({
        value,
        function_name: None,
        direction: Mf2DirectionUnknown,
        id: None,
        options: [],
        fields: [],
        attributes: [],
        fallback: true,
      }),
    ],
    errors: errors.copy(),
  }
}

///|
fn mf2_select_pattern(
  selector_names : Array[String],
  variants : Array[Mf2ModelVariant],
  bindings : Map[String, Mf2ResolvedValue],
  inputs : Map[String, Mf2ResolvedValue],
  errors : Array[Mf2Error],
) -> Mf2ModelPattern {
  let selectors : Array[Mf2ResolvedValue?] = []
  for name in selector_names {
    let value = mf2_resolve_variable(name, bindings, inputs, 0, errors)
    if value.fallback_source is Some(_) || value.match_key is None {
      if !(value.fallback_source is Some(_) &&
        value.function_name == Some("string")) {
        mf2_push_bad_selector_once(
          errors,
          "MF2 selector does not support selection: $\{name}",
        )
      }
      selectors.push(None)
    } else {
      selectors.push(Some(value))
    }
  }
  let mut best_pattern : Mf2ModelPattern? = None
  let mut best_keys : Array[Mf2ModelVariantKey] = []
  for variant in variants {
    if !mf2_variant_matches(selectors, variant.keys, errors) {
      continue
    }
    if best_pattern is None ||
      mf2_variant_better(selectors, variant.keys, best_keys, errors) {
      best_pattern = Some(variant.value)
      best_keys = variant.keys
    }
  }
  match best_pattern {
    Some(pattern) => pattern
    None =>
      match variants.last() {
        Some(variant) => variant.value
        None => { parts: [] }
      }
  }
}

///|
fn mf2_variant_matches(
  selectors : Array[Mf2ResolvedValue?],
  keys : Array[Mf2ModelVariantKey],
  errors : Array[Mf2Error],
) -> Bool {
  for i = 0; i < keys.length(); i = i + 1 {
    match keys[i] {
      Mf2ModelCatchallKey => ()
      Mf2ModelLiteralKey(key) => {
        guard selectors[i] is Some(selector) else { return false }
        guard selector.match_key is Some(match_key) else { return false }
        match match_key(@normalization.nfc(key)) {
          Ok(true) => ()
          Ok(false) => return false
          Err(failure) => {
            mf2_push_handler_failure(errors, failure, 0)
            return false
          }
        }
      }
    }
  }
  true
}

///|
fn mf2_variant_better(
  selectors : Array[Mf2ResolvedValue?],
  candidate : Array[Mf2ModelVariantKey],
  current : Array[Mf2ModelVariantKey],
  errors : Array[Mf2Error],
) -> Bool {
  for i = 0; i < candidate.length(); i = i + 1 {
    let left = candidate[i]
    let right = current[i]
    match (left, right) {
      (Mf2ModelCatchallKey, Mf2ModelCatchallKey) => continue
      (Mf2ModelCatchallKey, Mf2ModelLiteralKey(_)) => return false
      (Mf2ModelLiteralKey(_), Mf2ModelCatchallKey) => return true
      (Mf2ModelLiteralKey(left_key), Mf2ModelLiteralKey(right_key)) => {
        let left_normalized = @normalization.nfc(left_key)
        let right_normalized = @normalization.nfc(right_key)
        if left_normalized == right_normalized {
          continue
        }
        guard selectors[i] is Some(selector) else { return false }
        guard selector.better_than is Some(better_than) else { return false }
        match better_than(left_normalized, right_normalized) {
          Ok(value) => return value
          Err(failure) => {
            mf2_push_handler_failure(errors, failure, 0)
            return false
          }
        }
      }
    }
  }
  false
}

///|
fn mf2_push_bad_selector_once(
  errors : Array[Mf2Error],
  message : String,
) -> Unit {
  if errors.any(error => {
      error.code == Mf2BadSelectorCode && error.message == message
    }) {
    return
  }
  errors.push({
    kind: Mf2ResolutionError,
    code: Mf2BadSelectorCode,
    message,
    offset: 0,
  })
}

///|
fn mf2_format_pattern(
  pattern : Mf2ModelPattern,
  bindings : Map[String, Mf2ResolvedValue],
  inputs : Map[String, Mf2ResolvedValue],
  context : Mf2FormattingContext,
  provider : Mf2FunctionProvider,
  errors : Array[Mf2Error],
) -> Mf2FormatResult {
  let out = StringBuilder::new()
  let parts : Array[Mf2FormattedPart] = []
  for part in pattern.parts {
    match part {
      Mf2ModelText(value) => {
        out.write_string(value)
        parts.push(Mf2FormattedText(value))
      }
      Mf2ModelExpressionPart(expression) => {
        let resolved = mf2_resolve_expression(
          expression, bindings, inputs, context, provider, errors,
        )
        let (formatted, final_value) = match (resolved.render)() {
          Ok(output) => (output, resolved)
          Err(failure) => {
            mf2_push_handler_failure(errors, failure, expression.offset)
            let fallback = mf2_expression_fallback(expression)
            let output = match (fallback.render)() {
              Ok(value) => value
              Err(_) => FormatterOutput::{ value: "{�}", parts: [] }
            }
            (output, fallback)
          }
        }
        let isolation = mf2_bidi_start(final_value, context)
        match isolation {
          Some(start) => {
            out.write_string(start)
            parts.push(Mf2FormattedBidiIsolation(start))
          }
          None => ()
        }
        out.write_string(formatted.value)
        parts.push(
          Mf2FormattedExpressionPart({
            value: formatted.value,
            function_name: match final_value.function_name {
              Some(name) => Some(name)
              None =>
                match expression.function_ref {
                  Some(function_ref) => Some(function_ref.name)
                  None => None
                }
            },
            direction: final_value.direction,
            id: final_value.id,
            options: final_value.options.copy(),
            fields: formatted.parts.copy(),
            attributes: expression.attributes.copy(),
            fallback: final_value.fallback_source is Some(_),
          }),
        )
        if isolation is Some(_) {
          out.write_string("\u{2069}")
          parts.push(Mf2FormattedBidiIsolation("\u{2069}"))
        }
      }
      Mf2ModelMarkupPart(markup) => {
        let options = mf2_resolve_options(
          markup.options,
          bindings,
          inputs,
          markup.offset,
          errors,
        )
        let universal = mf2_resolve_universal_options(
          options,
          true,
          markup.offset,
          errors,
        )
        parts.push(
          Mf2FormattedMarkupPart({
            kind: markup.kind,
            name: markup.name,
            options: universal.structured_options,
            attributes: markup.attributes.copy(),
            id: universal.id,
          }),
        )
      }
    }
  }
  { value: out.to_string(), parts, errors: errors.copy() }
}

///|
fn mf2_bidi_start(
  value : Mf2ResolvedValue,
  context : Mf2FormattingContext,
) -> String? {
  if context.bidi_isolation == Mf2NoBidiIsolation {
    return None
  }
  match value.direction {
    Mf2LeftToRight =>
      if context.direction == Mf2LeftToRight && !value.isolate {
        None
      } else {
        Some("\u{2066}")
      }
    Mf2RightToLeft => Some("\u{2067}")
    Mf2DirectionUnknown => Some("\u{2068}")
  }
}
