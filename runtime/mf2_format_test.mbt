///|
fn standalone_context(
  inputs? : Array[Mf2Input] = [],
  direction? : Mf2Direction = Mf2DirectionUnknown,
  fallback? : String = "",
  bidi_isolation? : Mf2BidiIsolation = Mf2DefaultBidiIsolation,
) -> Mf2FormattingContext {
  match
    Mf2FormattingContext::new(
      locale="en-US",
      inputs~,
      direction~,
      fallback~,
      bidi_isolation~,
    ) {
    Ok(value) => value
    Err(error) => abort(error.message)
  }
}

///|
test "standalone MF2 formats literals with default bidi isolation" {
  let result = format_mf2_standalone(
    "Hello {world}",
    standalone_context(direction=Mf2LeftToRight),
  )
  assert_eq(result.value, "Hello \u{2068}world\u{2069}")
  assert_eq(result.errors, [])
  assert_eq(result.parts.length(), 4)
  assert_eq(result.parts[0], Mf2FormattedText("Hello "))
  assert_eq(result.parts[1], Mf2FormattedBidiIsolation("\u{2068}"))
  assert_eq(result.parts[3], Mf2FormattedBidiIsolation("\u{2069}"))
}

///|
test "standalone MF2 no-isolation strategy is explicit" {
  let result = format_mf2_standalone(
    "Hello {$name}",
    standalone_context(
      inputs=[Mf2Input::new("name", TextValue("MoonBit"))],
      direction=Mf2LeftToRight,
      bidi_isolation=Mf2NoBidiIsolation,
    ),
  )
  assert_eq(result.value, "Hello MoonBit")
  assert_eq(result.errors, [])
}

///|
test "standalone MF2 emits runtime fallback values and errors" {
  let unresolved = format_mf2_standalone(
    "Hello {$name}",
    standalone_context(bidi_isolation=Mf2NoBidiIsolation),
  )
  assert_eq(unresolved.value, "Hello {$name}")
  assert_true(
    unresolved.errors.any(error => error.code == Mf2UnresolvedVariableCode),
  )
  let unknown = format_mf2_standalone(
    "{42 :missing}",
    standalone_context(bidi_isolation=Mf2NoBidiIsolation),
  )
  assert_eq(unknown.value, "{|42|}")
  assert_true(unknown.errors.any(error => error.code == Mf2UnknownFunctionCode))
  let function_only = format_mf2_standalone(
    "{:missing}",
    standalone_context(bidi_isolation=Mf2NoBidiIsolation),
  )
  assert_eq(function_only.value, "{:missing}")
}

///|
test "standalone MF2 invalid messages use message fallback" {
  let invalid = format_mf2_standalone(
    "{{missing",
    standalone_context(bidi_isolation=Mf2NoBidiIsolation),
  )
  assert_eq(invalid.value, "{�}")
  assert_eq(invalid.errors[0].code, Mf2SyntaxCode)
  let configured = format_mf2_standalone(
    ".input {$x} .match $x one {{one}} * {{other}}",
    standalone_context(fallback="message-id", bidi_isolation=Mf2NoBidiIsolation),
  )
  assert_eq(configured.value, "{message-id}")
  assert_true(
    configured.errors.any(error => {
      error.code == Mf2MissingSelectorAnnotationCode
    }),
  )
}

///|
test "standalone structured output preserves inert markup and attributes" {
  let source = "{#link href=$url u:id=hero @role=button}Hi {name @title=label}{/link @closed}"
  let result = format_mf2_standalone(
    source,
    standalone_context(
      inputs=[Mf2Input::new("url", TextValue("/safe"))],
      bidi_isolation=Mf2NoBidiIsolation,
    ),
  )
  assert_eq(result.value, "Hi name")
  assert_eq(result.errors, [])
  assert_eq(result.parts.length(), 4)
  guard result.parts[0] is Mf2FormattedMarkupPart(open) else {
    fail("expected inert opening markup")
  }
  assert_eq(open.kind, Mf2MarkupOpen)
  assert_eq(open.name, "link")
  assert_eq(open.id, Some("hero"))
  assert_eq(open.options, [{ name: "href", value: "/safe" }])
  assert_eq(open.attributes, [{ name: "role", value: Some("button") }])
  guard result.parts[2] is Mf2FormattedExpressionPart(expression) else {
    fail("expected structured expression")
  }
  assert_eq(expression.attributes, [{ name: "title", value: Some("label") }])
  guard result.parts[3] is Mf2FormattedMarkupPart(close) else {
    fail("expected inert closing markup")
  }
  assert_eq(close.kind, Mf2MarkupClose)
  assert_eq(close.attributes, [{ name: "closed", value: None }])
}

///|
test "u:dir on markup is reported but never executed" {
  let result = format_mf2_standalone(
    "{#b u:dir=rtl}safe{/b}",
    standalone_context(bidi_isolation=Mf2NoBidiIsolation),
  )
  assert_eq(result.value, "safe")
  assert_true(result.errors.any(error => error.code == Mf2BadOptionCode))
}

///|
test "standalone formatting context enforces strict locale syntax" {
  assert_true(Mf2FormattingContext::new(locale="en_US") is Err(_))
  guard Mf2FormattingContext::new(locale="iw-BU", fallback_locales=["ZH_hant"])
    is Err(separator) else {
    fail("fallback locales are strict too")
  }
  assert_eq(separator.code, LocaleSyntaxCode)
  let context = match
    Mf2FormattingContext::new(locale="iw-BU", fallback_locales=["zh-Hant"]) {
    Ok(value) => value
    Err(error) => fail(error.message)
  }
  assert_eq(context.locale(), "he-MM")
  assert_eq(context.locales(), ["he-MM", "zh-Hant"])
}

///|
test "standalone formatter enforces input and output limits" {
  let inputs : Array[Mf2Input] = []
  for i = 0; i <= MF2_MAX_ARGUMENTS; i = i + 1 {
    inputs.push(Mf2Input::new("value\{i}", TextValue("x")))
  }
  let too_many = format_mf2_standalone(
    "ok",
    standalone_context(inputs~, bidi_isolation=Mf2NoBidiIsolation),
  )
  assert_eq(too_many.value, "{�}")
  assert_true(too_many.errors.any(error => error.code == Mf2LimitCode))
  let large = format_mf2_standalone(
    "{$value}",
    standalone_context(
      inputs=[
        Mf2Input::new("value", TextValue("x".repeat(MF2_MAX_OUTPUT_BYTES + 1))),
      ],
      bidi_isolation=Mf2NoBidiIsolation,
    ),
  )
  assert_eq(large.value, "{�}")
  assert_true(large.errors.any(error => error.code == Mf2LimitCode))
}
