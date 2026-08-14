///|
test "cached Intl number formatting" (bench : @bench.T) {
  let intl = formatter()
  // Prime the cache so the benchmark measures the steady-state hot path.
  ignore((intl.format_number)("en-US", 1234.5, []))
  bench.bench(name="intl-number-cache-hit", fn() {
    bench.keep((intl.format_number)("en-US", 1234.5, []))
  })
}

///|
test "MF2 default number registry formatting" (bench : @bench.T) {
  let model = match @runtime.parse_valid_mf2_model("{1234.5 :number}") {
    Ok(value) => value
    Err(_) => fail("default-function benchmark model must parse")
  }
  let context = match
    @runtime.Mf2FormattingContext::new(
      locale="en-US",
      bidi_isolation=@runtime.Mf2NoBidiIsolation,
    ) {
    Ok(value) => value
    Err(_) => fail("default-function benchmark context must be valid")
  }
  let registry = mf2_registry()
  ignore(@runtime.format_mf2_model(model, context, registry))
  bench.bench(name="mf2-default-number-format", fn() {
    bench.keep(@runtime.format_mf2_model(model, context, registry))
  })
}
