///|
/// Returns the portable fallback formatter on non-JavaScript documentation
/// and tooling targets. Generated application facades restrict this package
/// to JavaScript and therefore use the `Intl` implementation instead.
pub fn formatter() -> @runtime.Formatter {
  @runtime.Formatter::basic()
}

///|
/// Creates the pinned MF2 registry with the portable basic formatter.
pub fn mf2_registry() -> @runtime.Mf2FunctionRegistry {
  @runtime.Mf2FunctionRegistry::portable()
}

///|
/// Formats standalone MF2 source with the portable default registry.
pub fn format_mf2(
  source : String,
  context : @runtime.Mf2FormattingContext,
) -> @runtime.Mf2FormatResult {
  @runtime.format_mf2(source, context, mf2_registry())
}

///|
/// Formats a validated MF2 model with the portable default registry.
pub fn format_mf2_model(
  model : @runtime.Mf2MessageModel,
  context : @runtime.Mf2FormattingContext,
) -> @runtime.Mf2FormatResult {
  @runtime.format_mf2_model(model, context, mf2_registry())
}
