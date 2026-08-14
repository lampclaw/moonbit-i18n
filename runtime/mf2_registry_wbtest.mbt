///|
test "public and private custom failure mappings preserve every category" {
  let public_failures = [
    Mf2FunctionBadOperand("operand"),
    Mf2FunctionBadOption("option"),
    Mf2FunctionBadSelector("selector"),
    Mf2FunctionBadVariantKey("key"),
    Mf2FunctionUnsupported("unsupported"),
    Mf2FunctionFormatting("formatting"),
  ]
  for failure in public_failures {
    assert_eq(
      mf2_private_failure_to_public(mf2_public_failure_to_private(failure)),
      failure,
    )
  }
}

///|
test "custom selector adapters expose metadata callbacks issues and model entrypoint" {
  let registry = Mf2FunctionRegistry::portable()
  let handler = Mf2FunctionHandler::new(name="app:select", resolve=(
    context,
    operand,
    options,
  ) => {
    if context.locales != ["en-US"] || context.time_zone != "UTC" {
      return Err(Mf2FunctionFormatting("unexpected context"))
    }
    guard operand is Some(operand) else {
      return Err(Mf2FunctionBadOperand("missing"))
    }
    ignore(operand.function_name())
    ignore(operand.inherited_options())
    if !options.is_empty() {
      return Err(Mf2FunctionBadOption("unexpected options"))
    }
    Ok(
      Mf2FunctionValue::new(
        raw=operand.raw(),
        issues=[Mf2FunctionBadOption("non-fatal")],
        match_key=Some(key => Ok(key == "a" || key == "b")),
        better_than=Some((left, _right) => Ok(left == "b")),
        format=() => operand.format(),
      ),
    )
  })
  assert_eq(registry.register_custom(handler), Ok(()))
  let context = match
    Mf2FormattingContext::new(locale="en-US", bidi_isolation=Mf2NoBidiIsolation) {
    Ok(value) => value
    Err(error) => abort(error.message)
  }
  let source = ".local $x = {value :app:select} .match $x a {{A}} b {{B}} * {{X}}"
  let model = match parse_valid_mf2_model(source) {
    Ok(value) => value
    Err(_) => fail("custom selector model must parse")
  }
  let result = format_mf2_model(model, context, registry)
  assert_eq(result.value, "B")
  assert_eq(result.errors.map(error => error.code), [Mf2BadOptionCode])
}

///|
test "custom handler and callback failures remain typed" {
  let context = match
    Mf2FormattingContext::new(locale="en-US", bidi_isolation=Mf2NoBidiIsolation) {
    Ok(value) => value
    Err(error) => abort(error.message)
  }
  let failure_registry = Mf2FunctionRegistry::portable()
  ignore(
    failure_registry.register_custom(
      Mf2FunctionHandler::new(name="app:fail", resolve=(
        _context,
        _operand,
        _options,
      ) => Err(Mf2FunctionBadOperand("failed"))),
    ),
  )
  let failed = format_mf2("{value :app:fail}", context, failure_registry)
  assert_eq(failed.errors.map(error => error.code), [Mf2BadOperandCode])
  let render_registry = Mf2FunctionRegistry::portable()
  ignore(
    render_registry.register_custom(
      Mf2FunctionHandler::new(name="app:render", resolve=(
        _context,
        _operand,
        _options,
      ) => {
        Ok(
          Mf2FunctionValue::new(format=() => {
            Err(Mf2FunctionFormatting("failed render"))
          }),
        )
      }),
    ),
  )
  let rendered = format_mf2("{value :app:render}", context, render_registry)
  assert_eq(rendered.errors.map(error => error.code), [Mf2FormattingCode])
  let selector_registry = Mf2FunctionRegistry::portable()
  ignore(
    selector_registry.register_custom(
      Mf2FunctionHandler::new(name="app:selector", resolve=(
        _context,
        _operand,
        _options,
      ) => {
        Ok(
          Mf2FunctionValue::new(
            format=() => Ok({ value: "value", parts: [] }),
            match_key=Some(_key => Err(Mf2FunctionBadVariantKey("invalid key"))),
            better_than=Some((_left, _right) => {
              Err(Mf2FunctionBadSelector("ranking failed"))
            }),
          ),
        )
      }),
    ),
  )
  let selected = format_mf2(
    ".local $x = {value :app:selector} .match $x key {{K}} * {{X}}", context, selector_registry,
  )
  assert_true(selected.errors.any(error => error.code == Mf2BadVariantKeyCode))
}
