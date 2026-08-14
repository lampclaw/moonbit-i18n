///|
fn test_formatter() -> Formatter {
  {
    format_number: (_locale, value, options) => {
      if option_value_for_test(options, "integer") == Some("true") {
        Ok(value.to_int().to_string())
      } else {
        Ok(value.to_string())
      }
    },
    format_datetime: (_locale, value, _options) => Ok("ms:\{value}"),
    plural_category: (_locale, value, ordinal) => {
      if ordinal {
        let last = value.to_int() % 10
        Ok(
          if last == 1 {
            "one"
          } else if last == 2 {
            "two"
          } else if last == 3 {
            "few"
          } else {
            "other"
          },
        )
      } else {
        Ok(if value == 1.0 { "one" } else { "other" })
      }
    },
    format_number_to_parts: (locale, value, options) => {
      match (test_formatter().format_number)(locale, value, options) {
        Ok(formatted) => Ok({ value: formatted, parts: [] })
        Err(issue) => Err(issue)
      }
    },
    format_datetime_value: (locale, value, options) => {
      match value {
        InstantMillis(value) =>
          match (test_formatter().format_datetime)(locale, value, options) {
            Ok(formatted) => Ok({ value: formatted, parts: [] })
            Err(issue) => Err(issue)
          }
        _ => Err(UnsupportedOperation("test date literal unsupported"))
      }
    },
    plural_category_with_options: (locale, value, ordinal, _options) => {
      (test_formatter().plural_category)(locale, value, ordinal)
    },
  }
}

///|
fn option_value_for_test(
  options : Array[FormatOption],
  name : String,
) -> String? {
  for option in options {
    if option.name == name {
      return Some(option.value)
    }
  }
  None
}

///|
test "compiles and formats MF2 variables, escapes, and stable functions" {
  assert_eq(
    format_mf2_message(
      "Hello, {$name}. Curly: \\{ok\\}",
      "en-US",
      [{ name: "name", value: TextValue("Luca") }],
      test_formatter(),
    ),
    Ok("Hello, Luca. Curly: {ok}"),
  )
  assert_eq(
    format_mf2_message(
      "{$count :number} / {$whole :integer} / {$when :lampclaw:datetime}",
      "en-US",
      [
        { name: "count", value: DoubleValue(2.5) },
        { name: "whole", value: DoubleValue(3.9) },
        { name: "when", value: InstantMillis(42L) },
      ],
      test_formatter(),
    ),
    Ok("2.5 / 3 / ms:42"),
  )
}

///|
test "compile returns structured syntax and contract errors" {
  let contract = MessageContract::new([{ name: "name", typ: "String" }])
  guard compile_mf2_message("Hello {$missing}", contract) is Err(errors) else {
    fail("unknown variables must fail compilation")
  }
  assert_eq(errors[0].kind, Mf2DataModelError)
  assert_true(errors[0].message.contains("unknown variable"))
  assert_true(
    compile_mf2_message("unfinished \\", MessageContract::open()) is Err(_),
  )
}

///|
test "matcher preference is independent of source order" {
  let source = ".input {$count :number}\n.match $count\n* {{fallback}}\none {{category}}\n1 {{exact}}"
  assert_eq(
    format_mf2_message(
      source,
      "en-US",
      [{ name: "count", value: IntValue(1) }],
      test_formatter(),
    ),
    Ok("exact"),
  )
}

///|
test "fractional values never match a truncated integer key" {
  let source = ".input {$count :number select=exact}\n.match $count\n1 {{wrong}}\n* {{right}}"
  assert_eq(
    format_mf2_message(
      source,
      "en-US",
      [{ name: "count", value: DoubleValue(1.5) }],
      Formatter::basic(),
    ),
    Ok("right"),
  )
}

///|
test "input annotations are inherited by later expressions" {
  let formatter : Formatter = {
    format_number: (_locale, value, _options) => Ok("grouped:\{value}"),
    format_datetime: (_, _, _) => Err(UnsupportedOperation("unused")),
    plural_category: (_, _, _) => Ok("other"),
    format_number_to_parts: (_locale, value, _options) => {
      Ok({ value: "grouped:\{value}", parts: [] })
    },
    format_datetime_value: (_, _, _) => Err(UnsupportedOperation("unused")),
    plural_category_with_options: (_, _, _, _) => Ok("other"),
  }
  let source = ".input {$count :number}\n{{Value: {$count}}}"
  assert_eq(
    format_mf2_message(
      source,
      "en-US",
      [{ name: "count", value: IntValue(12000) }],
      formatter,
    ),
    Ok("Value: grouped:12000"),
  )
}

///|
test "local declarations preserve raw values and annotations" {
  let source = ".local $formatted = {$count :number}\n{{There are {$formatted} items.}}"
  assert_eq(
    format_mf2_message(
      source,
      "en-US",
      [{ name: "count", value: IntValue(12) }],
      test_formatter(),
    ),
    Ok("There are 12 items."),
  )
}

///|
test "quoted pattern scanner handles expression-only branches" {
  let source = ".input {$state :string}\n.match $state\n|open| {{${state}}}\n* {{closed}}"
  // Build the expression spelling separately so this test source remains easy
  // to read without relying on host-language interpolation.
  let fixed = source.replace_all(old="${state}", new="{$state}")
  assert_eq(
    format_mf2_message(
      fixed,
      "en-US",
      [{ name: "state", value: TextValue("open") }],
      test_formatter(),
    ),
    Ok("open"),
  )
}

///|
test "all matcher branches are compiled before selection" {
  let args : Array[MessageArg] = [{ name: "count", value: IntValue(1) }]
  let invalid = ".input {$count :number}\n.match $count\none {{One}}\n* {{{$missing}}}"
  assert_true(validate_mf2_message_with_args(invalid, args) is Err(_))
}

///|
test "parts API supports matchers and validates nesting" {
  let source = ".input {$count :number}\n.match $count\none {{{#b}One{/b}}}\n* {{Many}}"
  let compiled = match
    compile_mf2_message(
      source,
      MessageContract::new([{ name: "count", typ: "Int" }], allowed_tags=["b"]),
    ) {
    Ok(value) => value
    Err(_) => fail("expected valid parts message")
  }
  assert_eq(
    format_parts(
      compiled,
      "en-US",
      [{ name: "count", value: IntValue(1) }],
      test_formatter(),
    ),
    Ok([Open("b", []), Text("One"), Close("b")]),
  )
  assert_true(
    compile_mf2_message(
      "{#b}x{/i}",
      MessageContract::new([], allowed_tags=["b", "i"]),
    )
    is Err(_),
  )
}

///|
test "basic formatter reports unsupported CLDR operations" {
  assert_true(
    (Formatter::basic().plural_category)("en-US", 1.0, false)
    is Err(UnsupportedOperation(_)),
  )
  assert_true(
    (Formatter::basic().format_datetime)("en-US", 0L, [])
    is Err(UnsupportedOperation(_)),
  )
}

///|
fn assert_mf2_compile_error(source : String) -> Unit raise {
  guard compile_mf2_message(source, MessageContract::open()) is Err(errors) else {
    fail("expected MF2 compile failure: " + source)
  }
  assert_false(errors.is_empty())
}

///|
test "compiler rejects malformed declarations, matchers, markup, and expressions" {
  let invalid = [
    ".input x\n{{ok}}", ".input {|x|}\n{{ok}}", ".input {$x}\n.input {$x}\n{{ok}}",
    ".local $x {|a|}\n{{ok}}", ".local x = {|a|}\n{{ok}}", ".local $x = a\n{{ok}}",
    ".match\n* {{ok}}", ".input {$x}\n.match x\n* {{ok}}", ".input {$x}\n.match $x $x\n* * {{ok}}",
    ".match $x\n* {{ok}}", ".input {$x}\nplain", ".input {$x}\n{{ok}} trailing",
    ".input {$x}\n.match $x", ".input {$x}\n.match $x\none", ".input {$x}\n.input {$y}\n.match $x $y\none {{bad}}\n* * {{ok}}",
    ".input {$x}\n.match $x\none {{a}}\none {{b}}\n* {{ok}}", ".input {$x}\n.match $x\none {{a}}",
    ".input {$x}\n.match $x\n* {{", "unfinished \\", "bad \\q", "{$x", "bad }", "{}",
    "{$@}", "{#}", "{#@}", "{#tag option /}", "{#tag a=1 a=2 /}", "{/}", "{/tag}",
    "{#b}{/i}", "{#b}", "{|x| :string :number}", "{|x| :unknown}", "{|x| option}",
    "{|x| @=value}", "{|x| option=$@}", "{|x| :number style=decimal style=percent}",
    "{|x| :string option=value}", "{|x| :number select=invalid}", "{|x| :number style=}",
    "{|x| :number style=|open}", "{1 :number useGrouping=yes}", "{1 :number currency=EU}",
    "{1 :offset add=nope}", "{$when :lampclaw:datetime dateStyle=giant}",
  ]
  for source in invalid {
    assert_mf2_compile_error(source)
  }
  assert_mf2_compile_error("x".repeat(MF2_MAX_MESSAGE_BYTES + 1))
  assert_mf2_compile_error("界".repeat(MF2_MAX_MESSAGE_BYTES / 3 + 1))
}

///|
test "compiler enforces typed variables, locals, and markup contracts" {
  let string_contract = MessageContract::new([{ name: "value", typ: "String" }])
  assert_true(compile_mf2_message("{$missing}", string_contract) is Err(_))
  assert_true(
    compile_mf2_message("{$value :number}", string_contract) is Err(_),
  )
  assert_true(
    compile_mf2_message(
      ".local $copy = {$missing}\n{{{$copy}}}", string_contract,
    )
    is Err(_),
  )
  assert_true(
    compile_mf2_message(
      "{#b}ok{/b}",
      MessageContract::new([], allowed_tags=["strong"]),
    )
    is Err(_),
  )
  assert_true(
    compile_mf2_message(
      "{$when :lampclaw:datetime}",
      MessageContract::new([{ name: "when", typ: "InstantMillis" }]),
    )
    is Ok(_),
  )
  assert_true(
    compile_mf2_message(
      "{$value :number style=$missing}",
      MessageContract::new([{ name: "value", typ: "Double" }]),
    )
    is Err(_),
  )
  assert_true(
    compile_mf2_message(
      "{#link label=$missing /}",
      MessageContract::new([], allowed_tags=["link"]),
    )
    is Err(_),
  )
}

///|
test "compiler validates low-level message contracts" {
  assert_true(
    compile_mf2_message(
      "{$value}",
      MessageContract::new([
        { name: "value", typ: "String" },
        { name: "value", typ: "Unknown" },
      ]),
    )
    is Err(_),
  )
  assert_true(
    compile_mf2_message(
      "plain",
      MessageContract::new([], allowed_tags=["bad tag", "same", "same"]),
    )
    is Err(_),
  )
  assert_true(
    validate_mf2_message_with_args("{$value}", [
      { name: "value", value: TextValue("one") },
      { name: "value", value: TextValue("two") },
    ])
    is Err(_),
  )
  let params : Array[MessageParamSpec] = []
  for i = 0; i <= MF2_MAX_CONTRACT_PARAMS; i = i + 1 {
    params.push({ name: "p\{i}", typ: "String" })
  }
  guard compile_mf2_message("plain", MessageContract::new(params))
    is Err(param_errors) else {
    fail("oversized parameter contracts must fail")
  }
  assert_eq(param_errors[0].kind, Mf2LimitError)
  let tags : Array[String] = []
  for i = 0; i <= MF2_MAX_CONTRACT_TAGS; i = i + 1 {
    tags.push("tag\{i}")
  }
  guard compile_mf2_message(
      "plain",
      MessageContract::new([], allowed_tags=tags),
    )
    is Err(tag_errors) else {
    fail("oversized tag contracts must fail")
  }
  assert_eq(tag_errors[0].kind, Mf2LimitError)
  let args : Array[MessageArg] = []
  for i = 0; i <= MF2_MAX_ARGUMENTS; i = i + 1 {
    args.push({ name: "p\{i}", value: TextValue("value") })
  }
  guard compile_mf2_message("plain", MessageContract::open()) is Ok(compiled) else {
    fail("plain message should compile")
  }
  guard format_text(compiled, "en-US", args, test_formatter())
    is Err(argument_error) else {
    fail("oversized formatting argument sets must fail")
  }
  assert_eq(argument_error.kind, Mf2LimitError)
  let options : Array[String] = []
  for i = 0; i <= MF2_MAX_OPTIONS; i = i + 1 {
    options.push("option\{i}=value")
  }
  let markup = "{#tag " + options.join(" ") + " /}"
  guard compile_mf2_message(markup, MessageContract::open())
    is Err(option_errors) else {
    fail("oversized markup option sets must fail")
  }
  assert_eq(option_errors[0].kind, Mf2LimitError)
}

///|
test "core literals, value types, offsets, and inherited options format" {
  assert_eq(
    format_mf2_message(
      "{plain} {|quoted \\| literal|}",
      "en-US",
      [],
      test_formatter(),
    ),
    Ok("plain quoted | literal"),
  )
  assert_eq(
    format_mf2_message(
      "{$text} {$flag} {$instant}",
      "en-US",
      [
        { name: "text", value: TextValue("text") },
        { name: "flag", value: BoolValue(true) },
        { name: "instant", value: InstantMillis(9L) },
      ],
      test_formatter(),
    ),
    Ok("text true 9"),
  )
  assert_eq(
    format_mf2_message(
      "{$value :offset add=3 subtract=1}",
      "en-US",
      [{ name: "value", value: IntValue(10) }],
      test_formatter(),
    ),
    Ok("12"),
  )
  assert_eq(
    format_mf2_message(
      "{4.2 :number} {-4.9 :integer} {41 :offset add=1}",
      "en-US",
      [],
      test_formatter(),
    ),
    Ok("4.2 -4 42"),
  )
  for invalid in ["{00 :number}", "{1. :number}", "{+1 :number}"] {
    assert_mf2_compile_error(invalid)
  }
  assert_eq(
    format_mf2_message(
      ".input {$value :number style=$style}\n{{{$value :number maximumFractionDigits=2}}}",
      "en-US",
      [
        { name: "value", value: DoubleValue(1.25) },
        { name: "style", value: TextValue("decimal") },
      ],
      test_formatter(),
    ),
    Ok("1.25"),
  )
}

///|
test "integer and offset selectors use the same adjusted value as formatting" {
  assert_eq(
    format_mf2_message(
      ".local $value = {1.9 :integer}\n.match $value\n1 {{integer}}\n* {{other}}",
      "en-US",
      [],
      test_formatter(),
    ),
    Ok("integer"),
  )
  assert_eq(
    format_mf2_message(
      ".input {$value :offset add=1}\n.match $value\n2 {{offset}}\n* {{other}}",
      "en-US",
      [{ name: "value", value: IntValue(1) }],
      test_formatter(),
    ),
    Ok("offset"),
  )
}

///|
test "resolution and formatter failures remain structured" {
  assert_true(
    format_mf2_message(
      "{$x}",
      "en-US",
      [
        { name: "x", value: TextValue("a") },
        { name: "x", value: TextValue("b") },
      ],
      test_formatter(),
    )
    is Err(_),
  )
  assert_true(
    format_mf2_message(
      ".input {$x :number}\n{{{$x}}}",
      "en-US",
      [],
      test_formatter(),
    )
    is Err(_),
  )
  assert_true(
    format_mf2_message(
      ".local $x = {plain}\n{{{$x}}}",
      "en-US",
      [{ name: "x", value: TextValue("external") }],
      test_formatter(),
    )
    is Err(_),
  )
  assert_true(
    format_mf2_message(
      "{$x :number style=$missing}",
      "en-US",
      [{ name: "x", value: IntValue(1) }],
      test_formatter(),
    )
    is Err(_),
  )
  assert_true(
    format_mf2_message(
      "{$x :number}",
      "en-US",
      [{ name: "x", value: TextValue("not-number") }],
      test_formatter(),
    )
    is Err(_),
  )
  assert_true(
    format_mf2_message(
      "{$x :offset add=nope}",
      "en-US",
      [{ name: "x", value: IntValue(1) }],
      test_formatter(),
    )
    is Err(_),
  )
  assert_true(
    format_mf2_message(
      "{$x :offset subtract=nope}",
      "en-US",
      [{ name: "x", value: IntValue(1) }],
      test_formatter(),
    )
    is Err(_),
  )
  assert_true(
    format_mf2_message(
      "{$x :lampclaw:datetime}",
      "en-US",
      [{ name: "x", value: TextValue("not-an-instant") }],
      test_formatter(),
    )
    is Err(_),
  )
  let failing : Formatter = {
    format_number: (_, _, _) => Err(PlatformFormatterFailure("number failed")),
    format_datetime: (_, _, _) => Err(PlatformFormatterFailure("date failed")),
    plural_category: (_, _, _) => Err(PlatformFormatterFailure("plural failed")),
    format_number_to_parts: (_, _, _) => {
      Err(PlatformFormatterFailure("number failed"))
    },
    format_datetime_value: (_, _, _) => {
      Err(PlatformFormatterFailure("date failed"))
    },
    plural_category_with_options: (_, _, _, _) => {
      Err(PlatformFormatterFailure("plural failed"))
    },
  }
  assert_true(
    format_mf2_message(
      "{$x :number}",
      "en-US",
      [{ name: "x", value: IntValue(1) }],
      failing,
    )
    is Err("number failed"),
  )
  assert_true(
    format_mf2_message(
      "{$x :offset add=1}",
      "en-US",
      [{ name: "x", value: IntValue(1) }],
      failing,
    )
    is Err("number failed"),
  )
  assert_true(
    format_mf2_message(
      "{$x :lampclaw:datetime}",
      "en-US",
      [{ name: "x", value: InstantMillis(1L) }],
      failing,
    )
    is Err("date failed"),
  )
  assert_true(
    format_mf2_message(
      ".input {$x :number}\n.match $x\none {{one}}\n* {{other}}",
      "en-US",
      [{ name: "x", value: IntValue(1) }],
      failing,
    )
    is Err("plural failed"),
  )
}

///|
test "parts merge text safely and resolve markup options" {
  let compiled = match
    compile_mf2_message(
      "left{$empty}{#icon label=$label /}right",
      MessageContract::new(
        [{ name: "empty", typ: "String" }, { name: "label", typ: "String" }],
        allowed_tags=["icon"],
      ),
    ) {
    Ok(value) => value
    Err(_) => fail("parts source should compile")
  }
  assert_eq(
    format_parts(
      compiled,
      "en-US",
      [
        { name: "empty", value: TextValue("") },
        { name: "label", value: TextValue("star") },
      ],
      test_formatter(),
    ),
    Ok([
      Text("left"),
      Standalone("icon", [{ name: "label", value: "star" }]),
      Text("right"),
    ]),
  )
  assert_true(format_text(compiled, "en-US", [], test_formatter()) is Err(_))
}

///|
test "validation wrappers cover every message value contract" {
  assert_eq(validate_mf2_message("Hello {$name}", ["name"]), Ok(()))
  assert_true(validate_mf2_message("Hello {$missing}", ["name"]) is Err(_))
  assert_eq(
    validate_mf2_message_with_args(
      "{$s} {$i} {$d} {$b} {$t :lampclaw:datetime}",
      [
        { name: "s", value: TextValue("s") },
        { name: "i", value: IntValue(1) },
        { name: "d", value: DoubleValue(1.5) },
        { name: "b", value: BoolValue(true) },
        { name: "t", value: InstantMillis(1L) },
      ],
    ),
    Ok(()),
  )
  assert_true(validate_mf2_message_with_args("{$missing}", []) is Err(_))
}
