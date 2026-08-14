///|
const MF2_REFERENCE_COMMIT : String = "d115a614079678850aac8b52742360e888b8f027"

///|
test "legacy catalog and pinned standalone profile identities are deliberate" {
  assert_eq(CATALOG_PROFILE, "lampclaw-mf2-strict-v1+lampclaw-datetime-v1")
  assert_eq(MF2_STANDARD_MESSAGE_PROFILE, "unicode-mf2-ldml48.2-js-v1")
  assert_true(is_supported_message_profile(CATALOG_PROFILE))
  assert_true(is_supported_message_profile(MF2_STANDARD_MESSAGE_PROFILE))
  assert_eq(MF2_SYNTAX_PROFILE, "unicode-mf2-ldml48.2-syntax-v1")
  assert_eq(MF2_RESOLUTION_PROFILE, "unicode-mf2-ldml48.2-resolution-v1")
  assert_eq(
    MF2_DEFAULT_REGISTRY_PROFILE,
    "unicode-mf2-ldml48.2-default-functions-v1",
  )
  assert_eq(MF2_REFERENCE_COMMIT.length(), 40)
}

///|
test "strict profile preserves its tested overlap with the pinned MF2 syntax" {
  let formatter = Formatter::basic()
  assert_eq(format_mf2_message("", "en-US", [], formatter), Ok(""))
  assert_eq(
    format_mf2_message("hello {world}", "en-US", [], formatter),
    Ok("hello world"),
  )
  assert_eq(
    format_mf2_message("hello {|world|}", "en-US", [], formatter),
    Ok("hello world"),
  )
  assert_eq(
    format_mf2_message(
      "hello {$place}",
      "en-US",
      [{ name: "place", value: TextValue("world") }],
      formatter,
    ),
    Ok("hello world"),
  )
  assert_eq(format_mf2_message("{a}", "en-US", [], formatter), Ok("a"))
}

///|
test "strict profile rejects documented Unicode MF2 differences" {
  let open = MessageContract::open()
  // Attributes, standard date functions, unbalanced markup, and compact
  // complex-message grammar are outside the versioned Lampclaw profile.
  assert_true(compile_mf2_message("{a @c}", open) is Err(_))
  assert_true(compile_mf2_message("{|2006-01-02| :date}", open) is Err(_))
  assert_true(compile_mf2_message("{#tag}content", open) is Err(_))
  assert_true(compile_mf2_message(".input{$x}{{}}", open) is Err(_))
}
