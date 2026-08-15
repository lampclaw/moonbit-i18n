///|
#cfg(target="js")
test "formats numbers and plural categories with bounded Intl adapters" {
  let formatter = formatter()
  assert_eq((formatter.format_number)("en-US", 1234.5, []), Ok("1,234.5"))
  assert_eq(
    (formatter.format_number)("en-US", 1234.5, [
      { name: "useGrouping", value: "true" },
    ]),
    Ok("1,234.5"),
  )
  assert_eq(
    (formatter.format_number)("en-US", 1234.5, [
      { name: "useGrouping", value: "false" },
    ]),
    Ok("1234.5"),
  )
  assert_eq((formatter.plural_category)("en-US", 1.0, false), Ok("one"))
  assert_eq((formatter.plural_category)("en-US", 2.0, false), Ok("other"))
  assert_eq(
    @runtime.format_mf2_message("{4.9 :integer}", "en-US", [], formatter),
    Ok("4"),
  )
}

///|
#cfg(target="js")
test "formats InstantMillis using deterministic UTC defaults" {
  let formatter = formatter()
  assert_eq(
    (formatter.format_datetime)("en-US", 1785974400000L, [
      { name: "timeZone", value: "UTC" },
      { name: "dateStyle", value: "long" },
    ]),
    Ok("August 6, 2026"),
  )
}

///|
#cfg(target="js")
test "Intl exceptions and invalid options stay inside the Result boundary" {
  let formatter = formatter()
  assert_true(
    (formatter.format_number)("not_a_locale!", 1.0, [])
    is Err(PlatformFormatterFailure(_)),
  )
  assert_true(
    (formatter.format_number)("en-US", 1.0, [
      { name: "maximumFractionDigits", value: "bogus" },
    ])
    is Err(InvalidFormatterOption(_)),
  )
  assert_true(
    (formatter.format_datetime)("en-US", 0L, [
      { name: "timeZone", value: "Not/AZone" },
    ])
    is Err(InvalidFormatterOption(_)),
  )
  assert_true(
    (formatter.format_number)("en-US", 1.0, [{ name: "style", value: "bogus" }])
    is Err(InvalidFormatterOption(_)),
  )
  assert_true(
    (formatter.plural_category_with_options)("en-US", 1.0, false, [
      { name: "unknown", value: "value" },
    ])
    is Err(InvalidFormatterOption(_)),
  )
}

///|
#cfg(target="js")
test "pinned MF2 defaults format and select through Intl" {
  let context = match
    @runtime.Mf2FormattingContext::new(
      locale="en-US",
      bidi_isolation=@runtime.Mf2NoBidiIsolation,
    ) {
    Ok(value) => value
    Err(error) => abort(error.message)
  }
  let number = format_mf2(
    "hello {4.2 :number minimumFractionDigits=2}", context,
  )
  assert_eq(number.value, "hello 4.20")
  assert_eq(number.errors, [])
  guard number.parts[1] is @runtime.Mf2FormattedExpressionPart(expression) else {
    fail("expected structured numeric expression")
  }
  assert_true(expression.fields.any(part => part.kind == "integer"))
  assert_true(expression.fields.any(part => part.kind == "fraction"))
  let integer = format_mf2("{-4.9 :integer}", context)
  assert_eq(integer.value, "-4")
  assert_eq(integer.errors, [])
  let currency = format_mf2("{42 :currency currency=EUR}", context)
  assert_eq(currency.value, "€42.00")
  assert_eq(currency.errors, [])
  let percent = format_mf2("{0.42 :percent}", context)
  assert_eq(percent.value, "42%")
  assert_eq(percent.errors, [])
  let selected = format_mf2(
    ".input {$n :number} .match $n 1 {{exact}} one {{plural}} * {{other}}",
    match
      @runtime.Mf2FormattingContext::new(
        locale="en-US",
        inputs=[@runtime.Mf2Input::new("n", @runtime.DoubleValue(1.0))],
        bidi_isolation=@runtime.Mf2NoBidiIsolation,
      ) {
      Ok(value) => value
      Err(error) => abort(error.message)
    },
  )
  assert_eq(selected.value, "exact")
  assert_eq(selected.errors, [])
}

///|
#cfg(target="js")
test "draft date defaults use semantic fields and deterministic UTC" {
  let context = match
    @runtime.Mf2FormattingContext::new(
      locale="en-US",
      time_zone="UTC",
      bidi_isolation=@runtime.Mf2NoBidiIsolation,
    ) {
    Ok(value) => value
    Err(error) => abort(error.message)
  }
  let date = format_mf2("{|2006-01-02| :date length=long}", context)
  assert_eq(date.value, "January 2, 2006")
  assert_eq(date.errors, [])
  let datetime = format_mf2(
    "{|2006-01-02T15:04:06Z| :datetime timePrecision=second timeZoneStyle=short}",
    context,
  )
  assert_eq(datetime.errors, [])
  assert_true(datetime.value.contains("2006"))
  assert_true(datetime.value.contains("3:04:06"))
  let invalid = format_mf2("{|2006-02-30| :date}", context)
  assert_true(
    invalid.errors.any(error => error.code == @runtime.Mf2BadOperandCode),
  )
}

///|
#cfg(target="js")
test "standards-mode catalogs format through the generated-runtime path" {
  let hash = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
  let runtime = @runtime.I18n::new(
    fallback_locale_code="en-US",
    contract_hash=hash,
    profile=@runtime.MF2_STANDARD_MESSAGE_PROFILE,
    formatter=formatter(),
  )
  let catalog = @runtime.Catalog::from_generated_entries(
    locale_code="en-US",
    contract_hash=hash,
    profile=@runtime.MF2_STANDARD_MESSAGE_PROFILE,
    entries=[
      { id: "number", message: "Total {$value :number}" },
      {
        id: "plural",
        message: ".input {$count :number} .match $count one {{One item}} * {{{$count} items}}",
      },
      { id: "rich", message: "{#strong}Typed{/strong} output" },
    ],
    direction="ltr",
  )
  assert_true(runtime.install_generated_catalog(catalog) is Ok(_))
  let translator = runtime.translator("en-US")
  guard translator.try_t("number", [
      { name: "value", value: @runtime.DoubleValue(1234.5) },
    ])
    is Ok(number) else {
    fail("standards-mode number should format")
  }
  assert_true(number.contains("1,234.5"))
  let experimental = @runtime.I18n::new(
    fallback_locale_code="en-US",
    contract_hash=hash,
    profile=@runtime.MF2_EXPERIMENTAL_DATETIME_MESSAGE_PROFILE,
    formatter=formatter(),
  )
  let date_catalog = @runtime.Catalog::from_generated_entries(
    locale_code="en-US",
    contract_hash=hash,
    profile=@runtime.MF2_EXPERIMENTAL_DATETIME_MESSAGE_PROFILE,
    direction="ltr",
    entries=[
      {
        id: "date",
        message: "Updated {$when :date length=medium timeZone=UTC}",
      },
    ],
  )
  assert_true(experimental.install_generated_catalog(date_catalog) is Ok(_))
  guard experimental
    .translator("en-US")
    .try_t("date", [
      { name: "when", value: @runtime.InstantMillis(1785974400000L) },
    ])
    is Ok(date) else {
    fail("experimental standards-mode date should format")
  }
  assert_true(date.contains("Aug"))
  assert_eq(
    translator.try_t("plural", [{ name: "count", value: @runtime.IntValue(1) }]),
    Ok("One item"),
  )
  assert_eq(
    translator.try_t_parts("rich", []),
    Ok([
      @runtime.Open("strong", []),
      @runtime.Text("Typed"),
      @runtime.Close("strong"),
      @runtime.Text(" output"),
    ]),
  )
  let private_catalog = @runtime.Catalog::from_generated_entries(
    locale_code="en-US",
    contract_hash=hash,
    profile=@runtime.MF2_STANDARD_MESSAGE_PROFILE,
    entries=[{ id: "private", message: "{$when :lampclaw:datetime}" }],
  )
  assert_true(runtime.install_generated_catalog(private_catalog) is Err(_))
}

///|
#cfg(target="js")
test "locale-formatted values use the formatter context direction" {
  let context = match
    @runtime.Mf2FormattingContext::new(
      locale="en-US",
      direction=@runtime.Mf2LeftToRight,
    ) {
    Ok(value) => value
    Err(error) => abort(error.message)
  }
  let result = @runtime.format_mf2(
    "{1 :number}",
    context,
    @runtime.Mf2FunctionRegistry::new(formatter()),
  )
  assert_eq(result.value, "1")
  assert_eq(result.errors, [])
}

///|
#cfg(target="js")
test "stable numeric option surface maps to Node 26 Intl semantics" {
  let context = match
    @runtime.Mf2FormattingContext::new(
      locale="en-US",
      bidi_isolation=@runtime.Mf2NoBidiIsolation,
    ) {
    Ok(value) => value
    Err(error) => abort(error.message)
  }
  let rounded = format_mf2(
    "{1234.56 :number useGrouping=never signDisplay=always maximumFractionDigits=1 roundingMode=floor}",
    context,
  )
  assert_eq(rounded.value, "+1234.5")
  assert_eq(rounded.errors, [])
  let hidden_currency = format_mf2(
    "{42 :currency currency=EUR currencyDisplay=never fractionDigits=2}", context,
  )
  assert_eq(hidden_currency.value, "42.00")
  assert_eq(hidden_currency.errors, [])
  guard hidden_currency.parts[0]
    is @runtime.Mf2FormattedExpressionPart(currency_expression) else {
    fail("expected structured currency expression")
  }
  assert_true(
    !currency_expression.fields.any(field => field.kind == "currency"),
  )
  let inherited = format_mf2(
    ".local $n = {42 :number signDisplay=always minimumFractionDigits=2} {{{$n :number maximumFractionDigits=3}}}",
    context,
  )
  assert_eq(inherited.value, "+42.00")
  assert_eq(inherited.errors, [])
  let bad_select = format_mf2(
    ".local $mode = {exact} {{value {1 :number select=$mode}}}", context,
  )
  assert_eq(bad_select.value, "value 1")
  assert_eq(bad_select.errors.map(error => error.code), [
    @runtime.Mf2BadOptionCode,
  ])
  let supported_options = [
    "{1.2 :number signDisplay=negative}", "{1234 :number useGrouping=min2}", "{1.2 :number minimumIntegerDigits=3}",
    "{1.2 :number minimumFractionDigits=2}", "{1.2 :number maximumFractionDigits=1}",
    "{1.2 :number minimumSignificantDigits=3}", "{1.234 :number maximumSignificantDigits=3}",
    "{1 :number minimumFractionDigits=2 trailingZeroDisplay=stripIfInteger}", "{1.2 :number minimumFractionDigits=2 minimumSignificantDigits=3 roundingPriority=morePrecision}",
    "{1.23 :number minimumFractionDigits=2 maximumFractionDigits=2 roundingIncrement=5}",
    "{1.25 :number maximumFractionDigits=1 roundingMode=halfEven}", "{1234 :integer signDisplay=exceptZero useGrouping=always minimumIntegerDigits=5 maximumSignificantDigits=4}",
    "{42 :currency currency=EUR currencySign=accounting}", "{42 :currency currency=EUR currencyDisplay=narrowSymbol}",
    "{42 :currency currency=EUR currencyDisplay=symbol}", "{42 :currency currency=EUR currencyDisplay=name}",
    "{42 :currency currency=EUR currencyDisplay=code}", "{42 :currency currency=EUR currencyDisplay=never}",
    "{42 :currency currency=EUR useGrouping=never minimumIntegerDigits=3}", "{42 :currency currency=EUR fractionDigits=auto}",
    "{42 :currency currency=EUR fractionDigits=2}", "{42 :currency currency=EUR minimumSignificantDigits=2 maximumSignificantDigits=3}",
    "{42 :currency currency=EUR fractionDigits=2 trailingZeroDisplay=stripIfInteger}",
    "{42 :currency currency=EUR minimumFractionDigits=2 minimumSignificantDigits=3 roundingPriority=lessPrecision}",
    "{42.12 :currency currency=EUR fractionDigits=2 roundingIncrement=5}", "{42.15 :currency currency=EUR fractionDigits=1 roundingMode=halfFloor}",
    "{0.42 :percent signDisplay=always useGrouping=auto}", "{0.421 :percent minimumFractionDigits=2 maximumFractionDigits=2}",
    "{0.421 :percent minimumSignificantDigits=2 maximumSignificantDigits=3}", "{0.42 :percent minimumFractionDigits=2 trailingZeroDisplay=stripIfInteger}",
    "{0.421 :percent minimumFractionDigits=2 minimumSignificantDigits=3 roundingPriority=morePrecision}",
    "{0.425 :percent maximumFractionDigits=1 roundingMode=halfEven}",
  ]
  for message in supported_options {
    let rendered = format_mf2(message, context)
    if !rendered.errors.is_empty() {
      fail("Node 26 rejected supported MF2 options in: \{message}")
    }
  }
}

///|
#cfg(not(target="js"))
test "portable formatter fallback stays deterministic" {
  let portable = formatter()
  assert_eq((portable.format_number)("en-US", 1234.5, []), Ok("1234.5"))
  assert_true(
    (portable.plural_category)("en-US", 1.0, false)
    is Err(UnsupportedOperation(_)),
  )
  assert_true(
    (portable.format_datetime)("en-US", 1785974400000L, [])
    is Err(UnsupportedOperation(_)),
  )
}
