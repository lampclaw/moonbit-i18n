///|
test "formats MF2 variables and escapes" {
  let result = format_mf2_message(
    "Hello, {$name}. Curly: \\{ok\\}",
    "en-US",
    [{ name: "name", value: TextValue("Luca") }],
    Formatter::basic(),
  )
  assert_true(result == Ok("Hello, Luca. Curly: {ok}"))
}

///|
test "formats MF2 value functions" {
  let result = format_mf2_message(
    "{$count :number} / {$whole :integer} / {$when :datetime} / {$enabled}",
    "en-US",
    [
      { name: "count", value: DoubleValue(2.5) },
      { name: "whole", value: DoubleValue(3.9) },
      { name: "when", value: DateTimeValue("2026-08-06") },
      { name: "enabled", value: BoolValue(true) },
    ],
    Formatter::basic(),
  )
  assert_true(result == Ok("2.5 / 3 / 2026-08-06 / true"))
}

///|
test "validates MF2 text messages" {
  assert_true(validate_mf2_message("Hello {$name}", ["name"]) is Ok(_))
  assert_true(
    format_mf2_message("Hello {$name}", "en-US", [], Formatter::basic())
    is Err("unknown variable: name"),
  )
  assert_true(
    format_mf2_message("{#bold}Hi{/bold}", "en-US", [], Formatter::basic())
    is Err("MF2 markup requires the rich message API"),
  )
}

///|
test "passes locale and options to a custom formatter" {
  let formatter : Formatter = {
    format_number: (locale, value, options) => {
      "number=\{locale}:\{value}:\{options[0].name}=\{options[0].value}"
    },
    format_datetime: (locale, value, options) => {
      "date=\{locale}:\{value}:\{options[0].value}"
    },
    plural_category: (_, _, _) => "other",
  }
  assert_true(
    format_mf2_message(
      "{$amount :number style=compact}",
      "fr-FR",
      [{ name: "amount", value: IntValue(12) }],
      formatter,
    ) ==
    Ok("number=fr-FR:12:style=compact"),
  )
  assert_true(
    format_mf2_message(
      "{$date :datetime dateStyle=long}",
      "zh-CN",
      [{ name: "date", value: DateTimeValue("2026-08-06") }],
      formatter,
    ) ==
    Ok("date=zh-CN:2026-08-06:long"),
  )
}

///|
test "reports malformed MF2 patterns" {
  assert_true(
    format_mf2_message("unfinished \\", "en-US", [], Formatter::basic())
    is Err("trailing escape"),
  )
  assert_true(
    format_mf2_message("unclosed {$name", "en-US", [], Formatter::basic())
    is Err("unclosed expression"),
  )
  assert_true(
    format_mf2_message("unexpected }", "en-US", [], Formatter::basic())
    is Err("unmatched closing brace"),
  )
}
