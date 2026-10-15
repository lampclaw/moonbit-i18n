///|
test "formats safe MF2 rich parts" {
  let result = @runtime.format_mf2_rich(
    "This is {#bold}important{/bold}, {$name}. {#icon name=star /}",
    "en-US",
    [{ name: "name", value: TextValue("Luca"), }],
    @runtime.Formatter::basic(),
  )
  guard result is Ok(parts) else { fail("rich formatting failed") }
  assert_eq(parts.length(), 6)
  assert_true(parts[1] is RichOpen("bold", _))
  assert_true(parts[3] is RichClose("bold"))
  assert_true(parts[4] is RichText(", Luca. "))
  assert_true(parts[5] is RichStandalone("icon", _))
  assert_true(@runtime.validate_rich_tags(parts, ["bold", "icon"]) is Ok(_))
}

///|
test "rejects unregistered rich tags" {
  let parts : Array[@runtime.RichPart] = [
    RichOpen("script", []),
    RichText("x"),
    RichClose("script"),
  ]
  assert_true(
    @runtime.validate_rich_tags(parts, ["bold"])
    is Err("rich message uses an unregistered tag: script"),
  )
}

///|
test "reports malformed rich messages" {
  assert_true(
    @runtime.format_mf2_rich(
      "broken {#tag",
      "en-US",
      [],
      @runtime.Formatter::basic(),
    )
    is Err("unclosed expression"),
  )
  assert_true(
    @runtime.format_mf2_rich(
      "broken }",
      "en-US",
      [],
      @runtime.Formatter::basic(),
    )
    is Err("unmatched closing brace"),
  )
  assert_true(
    @runtime.format_mf2_rich(
      "{#icon invalid /}",
      "en-US",
      [],
      @runtime.Formatter::basic(),
    )
    is Err("invalid function option: invalid"),
  )
  assert_eq(
    @runtime.format_mf2_rich(
      ".input {$count}\n.match $count\n* {{items}}",
      "en-US",
      [{ name: "count", value: IntValue(2), }],
      @runtime.Formatter::basic(),
    ),
    Ok([RichText("items")]),
  )
}

///|
test "rich tag validation checks ordering and completeness" {
  assert_true(
    @runtime.validate_rich_tags([RichClose("b")], ["b"])
    is Err("unexpected closing rich tag: b"),
  )
  assert_true(
    @runtime.validate_rich_tags(
      [RichOpen("b", []), RichOpen("i", []), RichClose("b")],
      ["b", "i"],
    )
    is Err("mismatched closing rich tag: expected i, got b"),
  )
  assert_true(
    @runtime.validate_rich_tags([RichOpen("b", [])], ["b"])
    is Err("unclosed rich tag: b"),
  )
  assert_true(
    @runtime.validate_rich_tags([RichStandalone("icon", [])], ["icon"]) is Ok(_),
  )
}

///|
test "rich tag allowlists are bounded and canonical" {
  assert_true(@runtime.validate_rich_tags([], ["same", "same"]) is Err(_))
  assert_true(@runtime.validate_rich_tags([], ["bad tag"]) is Err(_))
  let tags : Array[String] = []
  for i = 0; i <= @runtime.MF2_MAX_CONTRACT_TAGS; i = i + 1 {
    tags.push("tag\{i}")
  }
  assert_true(@runtime.validate_rich_tags([], tags) is Err(_))
}
