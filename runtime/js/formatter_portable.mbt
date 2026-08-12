///|
/// Returns the portable fallback formatter on non-JavaScript documentation
/// and tooling targets. Generated application facades restrict this package
/// to JavaScript and therefore use the `Intl` implementation instead.
pub fn formatter() -> @runtime.Formatter {
  @runtime.Formatter::basic()
}
