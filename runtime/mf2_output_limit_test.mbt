///|
fn output_limit_context(
  inputs~ : Array[@runtime.Mf2Input] = [],
  fallback~ : String = "",
  bidi~ : @runtime.Mf2BidiIsolation = Mf2NoBidiIsolation,
) -> @runtime.Mf2FormattingContext {
  match
    @runtime.Mf2FormattingContext::new(
      locale="en-US",
      inputs~,
      fallback~,
      bidi_isolation=bidi,
    ) {
    Ok(context) => context
    Err(error) => abort(error.message)
  }
}

///|
fn output_limit_format(
  source : String,
  context : @runtime.Mf2FormattingContext,
  registry : @runtime.Mf2FunctionRegistry,
  model : Bool,
) -> @runtime.Mf2FormatResult {
  if model {
    match @runtime.parse_valid_mf2_model(source) {
      Ok(parsed) => @runtime.format_mf2_model(parsed, context, registry)
      Err(_) => abort("output-limit test source must be valid")
    }
  } else {
    @runtime.format_mf2(source, context, registry)
  }
}

///|
fn output_limit_assert_fallback(
  result : @runtime.Mf2FormatResult,
) -> Unit raise {
  assert_eq(result.value, "{�}")
  assert_eq(result.parts.length(), 1)
  guard result.parts[0] is Mf2FormattedExpressionPart(part) else {
    fail("expected one whole-message fallback expression")
  }
  assert_eq(part.value, result.value)
  assert_true(part.fallback)
  assert_eq(part.fields, [])
  let limits = result.errors.filter(error => error.code == Mf2LimitCode)
  assert_eq(limits.length(), 1)
  assert_eq(limits[0].kind, Mf2LimitError)
  assert_eq(limits[0].offset, 0)
  assert_eq(limits[0].message, "formatted output exceeds the 65536-byte limit")
}

///|
test "output budget accepts exact UTF-8 boundaries and rejects the next byte" {
  let values = [
    "x".repeat(65536),
    "é".repeat(32768),
    "界".repeat(21845) + "x",
    "😀".repeat(16384),
  ]
  for model in [false, true] {
    for value in values {
      let context = output_limit_context(inputs=[
        @runtime.Mf2Input::new("x", TextValue(value)),
      ])
      let registry = @runtime.Mf2FunctionRegistry::portable()
      let exact = output_limit_format("{$x}", context, registry, model)
      assert_eq(exact.value, value)
      assert_eq(exact.errors, [])
      output_limit_assert_fallback(
        output_limit_format("{$x}!", context, registry, model),
      )
      let over = output_limit_context(inputs=[
        @runtime.Mf2Input::new("x", TextValue(value + "!")),
      ])
      output_limit_assert_fallback(
        output_limit_format("{$x}", over, registry, model),
      )
    }
  }
}

///|
test "output budget reserves both bidi controls before appending an expression" {
  for model in [false, true] {
    let registry = @runtime.Mf2FunctionRegistry::portable()
    let value = "x".repeat(@runtime.MF2_MAX_OUTPUT_BYTES - 6)
    let context = output_limit_context(
      inputs=[@runtime.Mf2Input::new("x", TextValue(value))],
      bidi=Mf2DefaultBidiIsolation,
    )
    let exact = output_limit_format("{$x}", context, registry, model)
    assert_eq(exact.value, "\u{2068}" + value + "\u{2069}")
    assert_eq(exact.errors, [])
    assert_eq(exact.parts.length(), 3)
    let over = output_limit_context(
      inputs=[@runtime.Mf2Input::new("x", TextValue(value + "!"))],
      bidi=Mf2DefaultBidiIsolation,
    )
    output_limit_assert_fallback(
      output_limit_format("{$x}", over, registry, model),
    )
  }
}

///|
test "output budget pairs surrogate halves across expression and markup boundaries" {
  let high = String::from_array([(0xD83D).unsafe_to_char()])
  let low = String::from_array([(0xDE00).unsafe_to_char()])
  for model in [false, true] {
    for source in ["{$high}{$low}", "{$high}{#marker /}{$low}"] {
      let prefix = "x".repeat(@runtime.MF2_MAX_OUTPUT_BYTES - 4)
      let context = output_limit_context(inputs=[
        @runtime.Mf2Input::new("high", TextValue(prefix + high)),
        @runtime.Mf2Input::new("low", TextValue(low)),
      ])
      let registry = @runtime.Mf2FunctionRegistry::portable()
      let exact = output_limit_format(source, context, registry, model)
      assert_eq(exact.value, prefix + "😀")
      assert_eq(exact.errors, [])
      output_limit_assert_fallback(
        output_limit_format(source + "!", context, registry, model),
      )
    }
  }
}

///|
#cfg(target="js")
test "output budget keeps JavaScript unpaired surrogate encoding semantics" {
  let high = String::from_array([(0xD83D).unsafe_to_char()])
  let low = String::from_array([(0xDE00).unsafe_to_char()])
  for model in [false, true] {
    for lone in [high, low] {
      let value = "x".repeat(@runtime.MF2_MAX_OUTPUT_BYTES - 3) + lone
      let context = output_limit_context(inputs=[
        @runtime.Mf2Input::new("x", TextValue(value)),
      ])
      let registry = @runtime.Mf2FunctionRegistry::portable()
      let exact = output_limit_format("{$x}", context, registry, model)
      assert_eq(exact.value, value)
      assert_eq(exact.errors, [])
      output_limit_assert_fallback(
        output_limit_format("{$x}!", context, registry, model),
      )
    }
    // A visible separator prevents the two surrogate halves from pairing.
    let context = output_limit_context(inputs=[
      @runtime.Mf2Input::new(
        "high",
        TextValue("x".repeat(@runtime.MF2_MAX_OUTPUT_BYTES - 6) + high),
      ),
      @runtime.Mf2Input::new("low", TextValue(low)),
    ])
    output_limit_assert_fallback(
      output_limit_format(
        "{$high}!{$low}",
        context,
        @runtime.Mf2FunctionRegistry::portable(),
        model,
      ),
    )
    // Bidi controls also separate the halves: each is three replacement
    // bytes, in addition to four three-byte isolation controls.
    let prefix = "x".repeat(@runtime.MF2_MAX_OUTPUT_BYTES - 18)
    for extra in ["", "!"] {
      let isolated = output_limit_context(
        inputs=[
          @runtime.Mf2Input::new("high", TextValue(prefix + extra + high)),
          @runtime.Mf2Input::new("low", TextValue(low)),
        ],
        bidi=Mf2DefaultBidiIsolation,
      )
      let result = output_limit_format(
        "{$high}{$low}",
        isolated,
        @runtime.Mf2FunctionRegistry::portable(),
        model,
      )
      if extra.is_empty() {
        assert_eq(
          result.value,
          "\u{2068}" + prefix + high + "\u{2069}\u{2068}" + low + "\u{2069}",
        )
        assert_eq(result.errors, [])
      } else {
        output_limit_assert_fallback(result)
      }
    }
  }
}

///|
#cfg(not(target="js"))
test "panic bounded output preserves non-JavaScript unpaired surrogate behavior" {
  let high = String::from_array([(0xD83D).unsafe_to_char()])
  ignore(
    @runtime.format_mf2_standalone(
      "{$x}",
      output_limit_context(inputs=[@runtime.Mf2Input::new("x", TextValue(high))]),
    ),
  )
}

///|
test "output budget stops resolving and rendering after the first overflowing expression" {
  let value = "x".repeat(1024)
  for model in [false, true] {
    let calls = [0, 0]
    let registry = @runtime.Mf2FunctionRegistry::portable()
    assert_eq(
      registry.register_custom(
        @runtime.Mf2FunctionHandler::new(name="app:chunk", resolve=(
          _context,
          _operand,
          _options,
        ) => {
          calls[0] = calls[0] + 1
          Ok(
            @runtime.Mf2FunctionValue::new(format=() => {
              calls[1] = calls[1] + 1
              Ok({ value, parts: [{ kind: "text", value, }], })
            }),
          )
        }),
      ),
      Ok(()),
    )
    output_limit_assert_fallback(
      output_limit_format(
        "{:app:chunk}".repeat(4096),
        output_limit_context(),
        registry,
        model,
      ),
    )
    assert_eq(calls, [65, 65])
  }
}

///|
test "output budget preserves discovered errors and does not evaluate the tail" {
  for model in [false, true] {
    let calls = [0]
    let registry = @runtime.Mf2FunctionRegistry::portable()
    assert_eq(
      registry.register_custom(
        @runtime.Mf2FunctionHandler::new(name="app:tail", resolve=(
          _context,
          _operand,
          _options,
        ) => {
          calls[0] = calls[0] + 1
          Err(Mf2FunctionBadOperand("tail must not execute"))
        }),
      ),
      Ok(()),
    )
    let result = output_limit_format(
      "{$missing}{$large}{:app:tail}",
      output_limit_context(inputs=[
        @runtime.Mf2Input::new("large", TextValue("x".repeat(65536))),
      ]),
      registry,
      model,
    )
    output_limit_assert_fallback(result)
    assert_eq(result.errors.map(error => error.code), [
      Mf2UnresolvedVariableCode,
      Mf2LimitCode,
    ])
    assert_eq(calls, [0])
  }
}

///|
test "whole-message fallback observes the UTF-8 budget including braces" {
  for fallback in ["x".repeat(65534), "界".repeat(21844) + "é"] {
    let exact = @runtime.format_mf2_standalone(
      "{{missing",
      output_limit_context(fallback~),
    )
    assert_eq(exact.value, "{" + fallback + "}")
    assert_eq(exact.errors.map(error => error.code), [Mf2SyntaxCode])
    for over in [fallback + "!", fallback.repeat(16)] {
      let result = @runtime.format_mf2_standalone(
        "{{missing",
        output_limit_context(fallback=over),
      )
      assert_eq(result.value, "{�}")
      assert_eq(result.parts.length(), 1)
      assert_eq(result.errors.map(error => error.code), [Mf2SyntaxCode])
    }
  }
  let result = @runtime.format_mf2_standalone(
    "{$x}",
    output_limit_context(
      inputs=[@runtime.Mf2Input::new("x", TextValue("x".repeat(65537)))],
      fallback="message-id",
    ),
  )
  assert_eq(result.value, "{message-id}")
  assert_eq(result.errors.map(error => error.code), [Mf2LimitCode])
  assert_eq(result.parts.length(), 1)
}
