///|
/// Pinned default-function registry profile implemented by the 0.7 runtime.
pub const MF2_DEFAULT_REGISTRY_PROFILE : String = "unicode-mf2-ldml48.2-default-functions-v1"

///|
/// Portable context passed to a registered MF2 function handler.
pub(all) struct Mf2FunctionCallContext {
  /// Canonical current locale followed by canonical fallback locales.
  locales : Array[String]
  /// Direction inherited by the expression before `u:dir` overrides.
  direction : Mf2Direction
  /// Application-provided default time-zone identifier.
  time_zone : String
} derive(Eq, Debug)

///|
/// One resolved option passed to a registered MF2 function handler.
pub(all) struct Mf2FunctionOption {
  /// NFC-normalized option identifier.
  name : String
  /// String representation of the resolved value.
  value : String
  /// Typed input value when one remains available.
  raw : MessageValue?
  /// Whether the source option value was a literal rather than a variable.
  literal : Bool
} derive(Eq, Debug)

///|
/// Failure category available to portable custom-function handlers.
pub(all) enum Mf2FunctionFailure {
  /// The operand is missing or has an unsupported type or value.
  Mf2FunctionBadOperand(String)
  /// An option name or value is invalid for this function.
  Mf2FunctionBadOption(String)
  /// The resolved value cannot act as a selector.
  Mf2FunctionBadSelector(String)
  /// A matcher key is invalid for this selector.
  Mf2FunctionBadVariantKey(String)
  /// The selected backend cannot provide a required semantic operation.
  Mf2FunctionUnsupported(String)
  /// The platform formatter failed operationally.
  Mf2FunctionFormatting(String)
} derive(Eq, Debug)

///|
/// Resolved operand passed to a portable custom-function handler.
pub struct Mf2FunctionOperand {
  raw : MessageValue?
  format : () -> Result[FormatterOutput, Mf2FunctionFailure]
  direction : Mf2Direction
  function_name : String?
  inherited_options : Array[FormatOption]
}

///|
/// Returns the typed value carried by this operand, if one is available.
pub fn Mf2FunctionOperand::raw(self : Mf2FunctionOperand) -> MessageValue? {
  self.raw
}

///|
/// Lazily formats this operand exactly when the custom handler requests it.
pub fn Mf2FunctionOperand::format(
  self : Mf2FunctionOperand,
) -> Result[FormatterOutput, Mf2FunctionFailure] {
  (self.format)()
}

///|
/// Returns the operand's explicit or inherited direction metadata.
pub fn Mf2FunctionOperand::direction(self : Mf2FunctionOperand) -> Mf2Direction {
  self.direction
}

///|
/// Returns the function that produced this operand, if it was annotated.
pub fn Mf2FunctionOperand::function_name(self : Mf2FunctionOperand) -> String? {
  self.function_name
}

///|
/// Returns a copy of the options inherited from the producing function.
pub fn Mf2FunctionOperand::inherited_options(
  self : Mf2FunctionOperand,
) -> Array[FormatOption] {
  self.inherited_options.copy()
}

///|
/// Resolved value returned by a portable custom-function handler.
pub struct Mf2FunctionValue {
  raw : MessageValue?
  format : () -> Result[FormatterOutput, Mf2FunctionFailure]
  match_key : ((String) -> Result[Bool, Mf2FunctionFailure])?
  better_than : ((String, String) -> Result[Bool, Mf2FunctionFailure])?
  direction : Mf2Direction
  isolate : Bool
  id : String?
  inherited_options : Array[FormatOption]
  issues : Array[Mf2FunctionFailure]
}

///|
/// Creates a lazily formatted custom-function value with optional selection
/// callbacks and non-fatal issues.
pub fn Mf2FunctionValue::new(
  format~ : () -> Result[FormatterOutput, Mf2FunctionFailure],
  raw? : MessageValue? = None,
  match_key? : ((String) -> Result[Bool, Mf2FunctionFailure])? = None,
  better_than? : ((String, String) -> Result[Bool, Mf2FunctionFailure])? = None,
  direction? : Mf2Direction = Mf2DirectionUnknown,
  isolate? : Bool = false,
  id? : String? = None,
  inherited_options? : Array[FormatOption] = [],
  issues? : Array[Mf2FunctionFailure] = [],
) -> Mf2FunctionValue {
  {
    raw,
    format,
    match_key,
    better_than,
    direction,
    isolate,
    id,
    inherited_options: inherited_options.copy(),
    issues: issues.copy(),
  }
}

///|
/// Creates a format-only text value for a simple custom function.
pub fn Mf2FunctionValue::text(
  value : String,
  direction? : Mf2Direction = Mf2DirectionUnknown,
) -> Mf2FunctionValue {
  Mf2FunctionValue::new(raw=Some(TextValue(value)), direction~, format=() => {
    Ok({ value, parts: [] })
  })
}

///|
/// One named portable custom-function callback.
pub struct Mf2FunctionHandler {
  name : String
  resolve : (
    Mf2FunctionCallContext,
    Mf2FunctionOperand?,
    Array[Mf2FunctionOption],
  ) -> Result[Mf2FunctionValue, Mf2FunctionFailure]
}

///|
/// Creates a custom handler. `register_custom` performs name and collision
/// validation so construction itself cannot mutate a registry.
pub fn Mf2FunctionHandler::new(
  name~ : String,
  resolve~ : (
    Mf2FunctionCallContext,
    Mf2FunctionOperand?,
    Array[Mf2FunctionOption],
  ) -> Result[Mf2FunctionValue, Mf2FunctionFailure],
) -> Mf2FunctionHandler {
  { name: @normalization.nfc(name), resolve }
}

///|
/// Default functions plus an application-owned set of namespaced handlers.
pub struct Mf2FunctionRegistry {
  formatter : Formatter
  custom_handlers : Array[Mf2FunctionHandler]
}

///|
/// Creates the pinned default registry using a platform formatter provider.
pub fn Mf2FunctionRegistry::new(formatter : Formatter) -> Mf2FunctionRegistry {
  { formatter, custom_handlers: [] }
}

///|
/// Creates the default registry with the portable basic formatter.
///
/// String, exact numeric, and offset semantics remain available, while CLDR
/// plural/date behavior reports an explicit unsupported-operation issue.
pub fn Mf2FunctionRegistry::portable() -> Mf2FunctionRegistry {
  Mf2FunctionRegistry::new(Formatter::basic())
}

///|
/// Registers one application-owned namespaced function.
///
/// Custom identifiers must contain a namespace separator, cannot use the
/// reserved `u` namespace, and cannot collide after Unicode NFC
/// normalization. Custom functions are never part of the Unicode conformance
/// claim represented by `MF2_DEFAULT_REGISTRY_PROFILE`.
pub fn Mf2FunctionRegistry::register_custom(
  self : Mf2FunctionRegistry,
  handler : Mf2FunctionHandler,
) -> Result[Unit, String] {
  let name = @normalization.nfc(handler.name)
  let pieces : Array[String] = name
    .split(":")
    .map(piece => piece.to_owned())
    .collect()
  if pieces.length() < 2 || pieces.any(piece => piece.is_empty()) {
    return Err("custom MF2 function must use a non-empty namespace: :\{name}")
  }
  if pieces[0] == "u" {
    return Err("the Unicode u namespace is reserved: :\{name}")
  }
  match parse_mf2_syntax("{:" + name + "}") {
    Ok(_) => ()
    Err(_) => return Err("invalid custom MF2 function identifier: :\{name}")
  }
  if self.custom_handlers.any(existing => existing.name == name) {
    return Err("duplicate custom MF2 function: :\{name}")
  }
  self.custom_handlers.push({ ..handler, name, })
  Ok(())
}

///|
/// Returns the NFC-normalized custom function names in registration order.
pub fn Mf2FunctionRegistry::custom_names(
  self : Mf2FunctionRegistry,
) -> Array[String] {
  self.custom_handlers.map(handler => handler.name)
}

///|
/// Formats source with the pinned default registry and any registered custom
/// functions.
pub fn format_mf2(
  source : String,
  context : Mf2FormattingContext,
  registry : Mf2FunctionRegistry,
) -> Mf2FormatResult {
  format_mf2_with_provider(source, context, mf2_registry_provider(registry))
}

///|
/// Formats an already validated interchange model with an explicit registry.
pub fn format_mf2_model(
  model : Mf2MessageModel,
  context : Mf2FormattingContext,
  registry : Mf2FunctionRegistry,
) -> Mf2FormatResult {
  format_mf2_model_with_provider(
    model,
    context,
    mf2_registry_provider(registry),
  )
}

///|
fn mf2_registry_provider(registry : Mf2FunctionRegistry) -> Mf2FunctionProvider {
  {
    resolve: (context, name, operand, options) => {
      match
        mf2_resolve_default_function(registry, context, name, operand, options) {
        Mf2ProviderUnknown =>
          mf2_resolve_custom_function(registry, context, name, operand, options)
        result => result
      }
    },
  }
}

///|
fn mf2_resolve_custom_function(
  registry : Mf2FunctionRegistry,
  context : Mf2FunctionContext,
  name : String,
  operand : Mf2ResolvedValue?,
  options : Array[Mf2ResolvedOption],
) -> Mf2ProviderResult {
  let normalized = @normalization.nfc(name)
  let mut selected : Mf2FunctionHandler? = None
  for handler in registry.custom_handlers {
    if handler.name == normalized {
      selected = Some(handler)
      break
    }
  }
  guard selected is Some(handler) else { return Mf2ProviderUnknown }
  let call_context = Mf2FunctionCallContext::{
    locales: context.locales.copy(),
    direction: context.direction,
    time_zone: context.time_zone,
  }
  let call_operand = operand.map(value => Mf2FunctionOperand::{
    raw: value.raw,
    format: () => {
      match (value.render)() {
        Ok(output) => Ok(output)
        Err(failure) => Err(mf2_private_failure_to_public(failure))
      }
    },
    direction: value.direction,
    function_name: value.function_name,
    inherited_options: value.metadata.copy(),
  })
  let call_options = options.map(option => Mf2FunctionOption::{
    name: option.name,
    value: option.value,
    raw: option.raw,
    literal: option.literal,
  })
  match (handler.resolve)(call_context, call_operand, call_options) {
    Err(failure) => Mf2ProviderFailure(mf2_public_failure_to_private(failure))
    Ok(value) =>
      Mf2ProviderValue(
        {
          raw: value.raw,
          render: () => {
            match (value.format)() {
              Ok(output) => Ok(output)
              Err(failure) => Err(mf2_public_failure_to_private(failure))
            }
          },
          match_key: value.match_key.map(callback => {
            key => {
              match callback(key) {
                Ok(result) => Ok(result)
                Err(failure) => Err(mf2_public_failure_to_private(failure))
              }
            }
          }),
          better_than: value.better_than.map(callback => {
            (left, right) => {
              match callback(left, right) {
                Ok(result) => Ok(result)
                Err(failure) => Err(mf2_public_failure_to_private(failure))
              }
            }
          }),
          direction: value.direction,
          isolate: value.isolate,
          id: value.id,
          options: [],
          metadata: value.inherited_options.copy(),
          fallback_source: None,
          function_name: Some(normalized),
        },
        value.issues.map(mf2_public_failure_to_private),
      )
  }
}

///|
fn mf2_private_failure_to_public(
  failure : Mf2HandlerFailure,
) -> Mf2FunctionFailure {
  match failure {
    Mf2HandlerBadOperand(message) => Mf2FunctionBadOperand(message)
    Mf2HandlerBadOption(message) => Mf2FunctionBadOption(message)
    Mf2HandlerBadSelector(message) => Mf2FunctionBadSelector(message)
    Mf2HandlerBadVariantKey(message) => Mf2FunctionBadVariantKey(message)
    Mf2HandlerUnsupported(message) => Mf2FunctionUnsupported(message)
    Mf2HandlerFormatting(message) => Mf2FunctionFormatting(message)
  }
}

///|
fn mf2_public_failure_to_private(
  failure : Mf2FunctionFailure,
) -> Mf2HandlerFailure {
  match failure {
    Mf2FunctionBadOperand(message) => Mf2HandlerBadOperand(message)
    Mf2FunctionBadOption(message) => Mf2HandlerBadOption(message)
    Mf2FunctionBadSelector(message) => Mf2HandlerBadSelector(message)
    Mf2FunctionBadVariantKey(message) => Mf2HandlerBadVariantKey(message)
    Mf2FunctionUnsupported(message) => Mf2HandlerUnsupported(message)
    Mf2FunctionFormatting(message) => Mf2HandlerFormatting(message)
  }
}
