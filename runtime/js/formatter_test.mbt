///|
test "formats numbers and plural categories with Intl" {
  let formatter = formatter()
  assert_eq((formatter.format_number)("en-US", 1234.5, []), "1,234.5")
  assert_eq((formatter.plural_category)("en-US", 1.0, false), "one")
  assert_eq((formatter.plural_category)("en-US", 2.0, false), "other")
}

///|
test "formats integer and date options with Intl" {
  let formatter = formatter()
  assert_eq(
    (formatter.format_number)("en-US", 12.8, [
      { name: "integer", value: "true" },
    ]),
    "13",
  )
  assert_eq(
    (formatter.format_datetime)("en-US", "2026-08-06T00:00:00Z", [
      { name: "timeZone", value: "UTC" },
      { name: "year", value: "numeric" },
    ]),
    "2026",
  )
  assert_eq(
    (formatter.format_datetime)("en-US", "not-a-date", []),
    "not-a-date",
  )
}
