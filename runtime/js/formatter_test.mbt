///|
#cfg(target="js")
test "formats numbers and plural categories with bounded Intl adapters" {
  let formatter = formatter()
  assert_eq((formatter.format_number)("en-US", 1234.5, []), Ok("1,234.5"))
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
