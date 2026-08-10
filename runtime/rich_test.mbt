///|
test "formats safe MF2 rich parts" {
  let result = format_mf2_rich(
    "This is {#bold}important{/bold}, {$name}. {#icon name=star /}",
    "en-US",
    [{ name: "name", value: TextValue("Luca") }],
    Formatter::basic(),
  )
  guard result is Ok(parts) else { fail("rich formatting failed") }
  assert_eq(parts.length(), 8)
  assert_true(parts[1] is RichOpen("bold", _))
  assert_true(parts[3] is RichClose("bold"))
  assert_true(parts[5] is RichText("Luca"))
  assert_true(parts[7] is RichStandalone("icon", _))
  assert_true(validate_rich_tags(parts, ["bold", "icon"]) is Ok(_))
}

///|
test "rejects unregistered rich tags" {
  let parts : Array[RichPart] = [
    RichOpen("script", []),
    RichText("x"),
    RichClose("script"),
  ]
  assert_true(
    validate_rich_tags(parts, ["bold"])
    is Err("rich message uses an unregistered tag: script"),
  )
}

///|
test "reports malformed rich messages" {
  assert_true(
    format_mf2_rich("broken {#tag", "en-US", [], Formatter::basic())
    is Err("unclosed expression"),
  )
  assert_true(
    format_mf2_rich("broken }", "en-US", [], Formatter::basic())
    is Err("unmatched closing brace"),
  )
  assert_true(
    format_mf2_rich("{#icon invalid /}", "en-US", [], Formatter::basic())
    is Err("invalid markup option: invalid"),
  )
  assert_true(
    format_mf2_rich(
      ".input {$count}\n.match $count\n* {{items}}",
      "en-US",
      [{ name: "count", value: IntValue(2) }],
      Formatter::basic(),
    )
    is Err("rich match messages are not supported yet"),
  )
}
