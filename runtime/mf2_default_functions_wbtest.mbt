///|
fn mf2_test_resolved_option(
  name : String,
  value : String,
  literal? : Bool = true,
) -> Mf2ResolvedOption {
  { name, raw: Some(TextValue(value)), value, literal }
}

///|
test "default numeric option validators cover the pinned stable vocabulary" {
  let valid = [
    mf2_test_resolved_option("select", "ordinal"),
    mf2_test_resolved_option("signDisplay", "negative"),
    mf2_test_resolved_option("useGrouping", "min2"),
    mf2_test_resolved_option("minimumFractionDigits", "2"),
    mf2_test_resolved_option("trailingZeroDisplay", "stripIfInteger"),
    mf2_test_resolved_option("roundingPriority", "morePrecision"),
    mf2_test_resolved_option("roundingIncrement", "2500"),
    mf2_test_resolved_option("roundingMode", "halfEven"),
    mf2_test_resolved_option("currency", "eur"),
    mf2_test_resolved_option("currencySign", "accounting"),
    mf2_test_resolved_option("currencyDisplay", "never"),
    mf2_test_resolved_option("fractionDigits", "auto"),
    mf2_test_resolved_option("future:option", "value"),
  ]
  for option in valid {
    assert_true(mf2_validate_number_option("currency", option) is Ok(_))
  }
  let invalid = [
    mf2_test_resolved_option("select", "cardinal"),
    mf2_test_resolved_option("signDisplay", "sometimes"),
    mf2_test_resolved_option("useGrouping", "true"),
    mf2_test_resolved_option("minimumIntegerDigits", "01"),
    mf2_test_resolved_option("maximumSignificantDigits", "99"),
    mf2_test_resolved_option("trailingZeroDisplay", "strip"),
    mf2_test_resolved_option("roundingPriority", "middle"),
    mf2_test_resolved_option("roundingIncrement", "3"),
    mf2_test_resolved_option("roundingMode", "bankers"),
    mf2_test_resolved_option("currency", "EU"),
    mf2_test_resolved_option("currencySign", "negative"),
    mf2_test_resolved_option("currencyDisplay", "hidden"),
    mf2_test_resolved_option("fractionDigits", "100"),
  ]
  for option in invalid {
    assert_true(mf2_validate_number_option("currency", option) is Err(_))
  }
  guard mf2_validate_number_option(
      "number",
      mf2_test_resolved_option("minimumIntegerDigits", "0"),
    )
    is Ok(normalized) else {
    fail("zero minimum integer digits must be normalized")
  }
  assert_eq(normalized, { name: "minimumIntegerDigits", value: "1" })
  assert_true(mf2_digit_size_option("0"))
  assert_true(mf2_digit_size_option("99"))
  assert_true(!mf2_digit_size_option("00"))
  assert_true(!mf2_digit_size_option("100"))
  assert_true(!mf2_currency_identifier("EU"))
  assert_true(!mf2_number_option_known("unknown", "select"))
}

///|
test "numeric metadata transforms and selection failures are explicit" {
  let semantic : Array[FormatOption] = [
    { name: "fractionDigits", value: "2" },
    { name: "select", value: "exact" },
  ]
  let currency = mf2_number_formatter_options("currency", semantic)
  assert_eq(mf2_option_value(currency, "style"), Some("currency"))
  assert_eq(mf2_option_value(currency, "minimumFractionDigits"), Some("2"))
  assert_eq(mf2_option_value(currency, "maximumFractionDigits"), Some("2"))
  let integer = mf2_number_formatter_options("integer", [])
  assert_eq(mf2_option_value(integer, "integer"), Some("true"))
  let percent = mf2_number_formatter_options("percent", [])
  assert_eq(mf2_option_value(percent, "style"), Some("percent"))
  let inherited : Array[FormatOption] = [
    { name: "minimumFractionDigits", value: "2" },
    { name: "minimumSignificantDigits", value: "3" },
    { name: "maximumSignificantDigits", value: "4" },
    { name: "minimumIntegerDigits", value: "5" },
    { name: "roundingIncrement", value: "5" },
    { name: "select", value: "exact" },
  ]
  let as_integer = mf2_number_inherited_options("integer", inherited)
  assert_eq(mf2_option_value(as_integer, "minimumFractionDigits"), None)
  assert_eq(mf2_option_value(as_integer, "maximumSignificantDigits"), Some("4"))
  let as_percent = mf2_number_inherited_options("percent", inherited)
  assert_eq(mf2_option_value(as_percent, "minimumIntegerDigits"), None)
  assert_eq(mf2_option_value(as_percent, "roundingIncrement"), None)
  assert_eq(mf2_option_value(as_percent, "select"), None)
  assert_eq(mf2_exact_number_serialization(42.0, []), "42")
  assert_eq(mf2_exact_number_serialization(-0.0, []), "0")
  assert_eq(
    mf2_exact_number_serialization(42.0, [
      { name: "minimumFractionDigits", value: "2" },
    ]),
    "42",
  )
  assert_true(
    mf2_number_matches(
      Formatter::basic(),
      "en-US",
      42.0,
      "42",
      "exact",
      [],
      "42",
    )
    is Ok(true),
  )
  assert_true(
    mf2_number_matches(
      Formatter::basic(),
      "en-US",
      42.0,
      "42",
      "exact",
      [],
      "one",
    )
    is Ok(false),
  )
  assert_true(
    mf2_number_matches(
      Formatter::basic(),
      "en-US",
      42.0,
      "42",
      "plural",
      [],
      "invalid",
    )
    is Err(Mf2HandlerBadVariantKey(_)),
  )
  assert_true(
    mf2_number_matches(
      Formatter::basic(),
      "en-US",
      42.0,
      "42",
      "plural",
      [],
      "other",
    )
    is Err(Mf2HandlerUnsupported(_)),
  )
}

///|
test "strict ISO date literal validation covers calendar fraction and offset edges" {
  for
    value in [
      "2000-02-29", "2006-01-02T15:04:06", "2006-01-02T15:04:06.1Z", "2006-01-02T15:04:06.123+14:00",
      "2006-01-02T15:04:06-05:30",
    ] {
    assert_true(mf2_validate_date_literal(value) is Some(_))
  }
  for
    value in [
      "", "0000-01-01", "1900-02-29", "2006-04-31", "2006/01/02", "2006-01-02T24:00:00",
      "2006-01-02T15:60:00", "2006-01-02T15:04:60", "2006-01-02T15:04:06.", "2006-01-02T15:04:06.1234Z",
      "2006-01-02T15:04:06+14:01", "2006-01-02T15:04:06+15:00", "2006-01-02T15:04:06+1:00",
    ] {
    assert_true(mf2_validate_date_literal(value) is None)
  }
  assert_eq(mf2_days_in_month(2000, 2), 29)
  assert_eq(mf2_days_in_month(2001, 2), 28)
  assert_eq(mf2_days_in_month(2001, 4), 30)
  assert_true(!mf2_ascii_digits(['1'], -1, 1))
  assert_true(!mf2_ascii_digits(['x'], 0, 1))
}

///|
test "formatter issue mapping and raw operand validation are total" {
  assert_true(
    mf2_formatter_issue_to_handler(UnsupportedOperation("u"))
    is Mf2HandlerUnsupported("u"),
  )
  assert_true(
    mf2_formatter_issue_to_handler(InvalidFormatterOption("o"))
    is Mf2HandlerBadOption("o"),
  )
  assert_true(
    mf2_formatter_issue_to_handler(PlatformFormatterFailure("p"))
    is Mf2HandlerFormatting("p"),
  )
  assert_true(
    mf2_unwrap_numeric_operand(
      "number",
      Some(mf2_plain_resolved(IntValue(4), Mf2DirectionUnknown)),
    )
    is Ok(_),
  )
  assert_true(
    mf2_unwrap_numeric_operand(
      "number",
      Some(mf2_plain_resolved(BoolValue(true), Mf2DirectionUnknown)),
    )
    is Err(Mf2HandlerBadOperand(_)),
  )
  assert_true(
    mf2_unwrap_numeric_operand(
      "number",
      Some(mf2_plain_resolved(DoubleValue(0.0 / 0.0), Mf2DirectionUnknown)),
    )
    is Err(Mf2HandlerBadOperand(_)),
  )
}
