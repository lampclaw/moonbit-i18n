///|
fn mf2_registry_test_context() -> Mf2FormattingContext {
  match
    Mf2FormattingContext::new(locale="en-US", bidi_isolation=Mf2NoBidiIsolation) {
    Ok(value) => value
    Err(error) => abort(error.message)
  }
}

///|
test "portable registry exposes pinned defaults and namespaced custom handlers" {
  assert_eq(
    MF2_DEFAULT_REGISTRY_PROFILE,
    "unicode-mf2-ldml48.2-default-functions-v1",
  )
  let registry = Mf2FunctionRegistry::portable()
  let handler = Mf2FunctionHandler::new(name="app:echo", resolve=(
    _context,
    operand,
    options,
  ) => {
    guard operand is Some(operand) else {
      return Err(Mf2FunctionBadOperand("missing echo operand"))
    }
    let mut prefix = ""
    for option in options {
      if option.name == "prefix" {
        prefix = option.value
      }
    }
    Ok(
      Mf2FunctionValue::new(raw=operand.raw(), direction=operand.direction(), format=() => {
        match operand.format() {
          Ok(output) => Ok({ value: prefix + output.value, parts: [] })
          Err(failure) => Err(failure)
        }
      }),
    )
  })
  assert_eq(registry.register_custom(handler), Ok(()))
  assert_eq(registry.custom_names(), ["app:echo"])
  let result = format_mf2(
    "{hello :app:echo prefix=hi-}",
    mf2_registry_test_context(),
    registry,
  )
  assert_eq(result.value, "hi-hello")
  assert_eq(result.errors, [])
}

///|
test "custom registry rejects reserved unnamespaced and normalized duplicates" {
  let registry = Mf2FunctionRegistry::portable()
  let make = name => {
    Mf2FunctionHandler::new(name~, resolve=(_context, _operand, _options) => {
      Ok(Mf2FunctionValue::text("ok"))
    })
  }
  assert_true(registry.register_custom(make("plain")) is Err(_))
  assert_true(registry.register_custom(make("u:reserved")) is Err(_))
  assert_eq(registry.register_custom(make("app:café")), Ok(()))
  assert_true(registry.register_custom(make("app:cafe\u{301}")) is Err(_))
}
