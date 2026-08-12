///|
test "formats safe MF2 rich parts" {
  let result = format_mf2_rich(
    "This is {#bold}important{/bold}, {$name}. {#icon name=star /}",
    "en-US",
    [{ name: "name", value: TextValue("Luca") }],
    Formatter::basic(),
  )
  guard result is Ok(parts) else { fail("rich formatting failed") }
  assert_eq(parts.length(), 6)
  assert_true(parts[1] is RichOpen("bold", _))
  assert_true(parts[3] is RichClose("bold"))
  assert_true(parts[4] is RichText(", Luca. "))
  assert_true(parts[5] is RichStandalone("icon", _))
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
    is Err("invalid function option: invalid"),
  )
  assert_eq(
    format_mf2_rich(
      ".input {$count}\n.match $count\n* {{items}}",
      "en-US",
      [{ name: "count", value: IntValue(2) }],
      Formatter::basic(),
    ),
    Ok([RichText("items")]),
  )
}

///|
test "rich tag validation checks ordering and completeness" {
  assert_true(
    validate_rich_tags([RichClose("b")], ["b"])
    is Err("unexpected closing rich tag: b"),
  )
  assert_true(
    validate_rich_tags([RichOpen("b", []), RichOpen("i", []), RichClose("b")], [
      "b", "i",
    ])
    is Err("mismatched closing rich tag: expected i, got b"),
  )
  assert_true(
    validate_rich_tags([RichOpen("b", [])], ["b"])
    is Err("unclosed rich tag: b"),
  )
  assert_true(
    validate_rich_tags([RichStandalone("icon", [])], ["icon"]) is Ok(_),
  )
}

///|
test "rich tag allowlists are bounded and canonical" {
  assert_true(validate_rich_tags([], ["same", "same"]) is Err(_))
  assert_true(validate_rich_tags([], ["bad tag"]) is Err(_))
  let tags : Array[String] = []
  for i = 0; i <= MF2_MAX_CONTRACT_TAGS; i = i + 1 {
    tags.push("tag\{i}")
  }
  assert_true(validate_rich_tags([], tags) is Err(_))
}
