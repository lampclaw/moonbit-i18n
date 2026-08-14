///|
fn assert_standard_syntax_ok(source : String) -> Mf2MessageModel raise {
  match parse_mf2_syntax(source) {
    Ok(model) => model
    Err(error) => fail("expected well-formed MF2: \{source}: \{error.message}")
  }
}

///|
fn assert_standard_syntax_error(source : String) -> Unit raise {
  guard parse_mf2_syntax(source) is Err(error) else {
    fail("expected MF2 syntax error: " + source)
  }
  assert_eq(error.kind, Mf2SyntaxError)
  assert_eq(error.code, Mf2SyntaxCode)
}

///|
test "pinned MF2 syntax parses compact messages and normative placeholders" {
  let sources = [
    "", "hello {$place-.}", "{{}}", ".input{$x}{{{$x}}}", ".local $x={:ns:function option=|value| @note=yes}{{{$x}}}",
    ".input{$x :number}.match $x 1{{one}}*{{other}}", "{#button label=$label @role=action}Submit{/button @role=action}",
    "{#open}unbalanced markup is valid MF2", "{/close options=allowed}", "{|literal| @translate=no}",
  ]
  for source in sources {
    ignore(assert_standard_syntax_ok(source))
  }
}

///|
test "pinned MF2 syntax rejects malformed grammar independently of validity" {
  let sources = [
    ".", "{", "}", "{}", "{{", "{{}}}", "missing space {42:number}", "missing space {|foo|@bar}",
    "bad {:placeholder option=}", "bad {:placeholder option}", "bad {:placeholder @attribute=$foo}",
    ".local bar = {|foo|} {{_}}", ".local $bar {|foo|} {{_}}", ".match {{foo}}",
    ".input {$x :x} .match$x * {{foo}}", ".input {$x :x} .match $x* {{foo}}", "{^}",
    "{\u{fdd0}}",
  ]
  for source in sources {
    assert_standard_syntax_error(source)
  }
}

///|
test "well-formed and valid MF2 are distinct with stable data-model codes" {
  let cases : Array[(String, Mf2ErrorCode)] = [
    (".input {$foo :x} .match $foo * * {{foo}}", Mf2VariantKeyMismatchCode),
    (".input {$foo :x} .match $foo 1 {{foo}}", Mf2MissingFallbackVariantCode),
    (
      ".input {$foo} .match $foo one {{one}} * {{other}}",
      Mf2MissingSelectorAnnotationCode,
    ),
    (
      ".local $foo = {$bar} .local $bar = {42} {{_}}",
      Mf2DuplicateDeclarationCode,
    ),
    ("bad {:placeholder option=x option=x}", Mf2DuplicateOptionNameCode),
    (
      ".input {$var :string} .match $var * {{first}} * {{second}}",
      Mf2DuplicateVariantCode,
    ),
  ]
  for pair in cases {
    let (source, code) = pair
    let model = assert_standard_syntax_ok(source)
    let errors = validate_mf2_model(model)
    assert_true(errors.any(error => error.code == code))
    assert_true(parse_valid_mf2_model(source) is Err(_))
  }
}

///|
test "MF2 names and variant keys compare as if normalized to NFC" {
  let decomposed = "e\u{301}"
  let composed = "é"
  let duplicate_declaration = ".local $\{decomposed} = {one} .local $\{composed} = {two} {{_}}"
  guard parse_valid_mf2_model(duplicate_declaration) is Err(errors) else {
    fail("NFC-equivalent declaration names must be rejected")
  }
  assert_true(errors.any(error => error.code == Mf2DuplicateDeclarationCode))
  let duplicate_variant = ".input {$x :string} .match $x |\{decomposed}| {{one}} |\{composed}| {{two}} * {{other}}"
  guard parse_valid_mf2_model(duplicate_variant) is Err(variant_errors) else {
    fail("NFC-equivalent variant keys must be rejected")
  }
  assert_true(
    variant_errors.any(error => error.code == Mf2DuplicateVariantCode),
  )

  let separator = "\u{1f}"
  let collision_resistant = ".input {$x :string}.input {$y :string}.match $x $y |a\{separator}l:b| c {{first}} a |b\{separator}l:c| {{second}} * * {{other}}"
  guard parse_valid_mf2_model(collision_resistant) is Ok(_) else {
    fail("distinct control-containing key tuples must not collide")
  }
}

///|
test "MF2 syntax model retains expressions attributes and markup without balancing" {
  let model = assert_standard_syntax_ok(
    "start {:ns:function opt=$value @a=first @a=last} {#tag x=1 @flag}",
  )
  guard model is Mf2PatternMessage([], pattern) else {
    fail("expected a pattern message")
  }
  guard pattern.parts[1] is Mf2ModelExpressionPart(expression) else {
    fail("expected expression part")
  }
  assert_eq(expression.arg, None)
  assert_eq(
    expression.function_ref.map(value => value.name),
    Some("ns:function"),
  )
  assert_eq(expression.attributes, [{ name: "a", value: Some("last") }])
  guard pattern.parts[3] is Mf2ModelMarkupPart(markup) else {
    fail("expected markup part")
  }
  assert_eq(markup.kind, Mf2MarkupOpen)
  assert_eq(markup.name, "tag")
  assert_eq(markup.attributes, [{ name: "flag", value: None }])
}

///|
test "MF2 syntax serialization is deterministic and functionally round trips" {
  let source = ".input{$count :number select=cardinal}.local $label={|a \\| label|}.match $count one{{{#b @z @a=2}One {$label}{/b}}}*{{Other \\{value\\}}}"
  let first = match parse_valid_mf2_model(source) {
    Ok(value) => value
    Err(errors) => fail("source model should be valid: " + errors[0].message)
  }
  guard serialize_mf2_model(first) is Ok(serialized) else {
    fail("valid model should serialize")
  }
  assert_true(serialized.contains(".input {$count :number select=cardinal}"))
  assert_true(serialized.contains("@a=2 @z"))
  guard parse_valid_mf2_model(serialized) is Ok(second) else {
    fail("serialized model should parse as valid")
  }
  assert_eq(serialize_mf2_model(second), Ok(serialized))
}

///|
test "MF2 syntax serialization rejects malformed public models" {
  let empty : Mf2ModelExpression = {
    arg: None,
    function_ref: None,
    attributes: [],
    offset: 0,
  }
  assert_true(
    serialize_mf2_model(
      Mf2PatternMessage([], { parts: [Mf2ModelExpressionPart(empty)] }),
    )
    is Err(_),
  )
  let invalid_name : Mf2ModelExpression = {
    arg: Some(Mf2ModelVariable("bad name")),
    function_ref: None,
    attributes: [],
    offset: 0,
  }
  assert_true(
    serialize_mf2_model(
      Mf2PatternMessage([], { parts: [Mf2ModelExpressionPart(invalid_name)] }),
    )
    is Err(_),
  )
}

///|
test "MF2 interchange JSON is deterministic and round trips the normative model" {
  let source = ".input {$count :number select=cardinal}.local $label = {|items|}.match $count one {{{#strong level=|1| @role=emphasis}One {$label}{/strong}}} * {{Other}}"
  let model = match parse_valid_mf2_model(source) {
    Ok(value) => value
    Err(errors) => fail("source model should be valid: " + errors[0].message)
  }
  let encoded = match mf2_model_to_json(model) {
    Ok(value) => value
    Err(errors) => fail("valid model should encode: " + errors[0].message)
  }
  assert_true(encoded.contains("\"type\": \"select\""))
  assert_true(encoded.contains("\"declarations\""))
  assert_true(encoded.contains("\"selectors\""))
  assert_true(encoded.contains("\"variants\""))
  assert_true(encoded.contains("\"type\": \"function\""))
  assert_true(encoded.contains("\"options\""))
  assert_true(encoded.contains("\"attributes\""))
  assert_true(encoded.contains("\"type\": \"markup\""))
  let decoded = match parse_mf2_model_json(encoded) {
    Ok(value) => value
    Err(message) => fail("encoded model should decode: " + message)
  }
  assert_eq(mf2_model_to_json(decoded), Ok(encoded))
  assert_eq(serialize_mf2_model(decoded), serialize_mf2_model(model))
}

///|
test "MF2 interchange JSON ignores extension fields" {
  let source =
    #|{
    #|  "type": "message",
    #|  "declarations": [],
    #|  "pattern": [
    #|    "Hello ",
    #|    {
    #|      "type": "expression",
    #|      "arg": { "type": "variable", "name": "name", "span": [6, 13] },
    #|      "attributes": {},
    #|      "vendor": { "tool": "example" }
    #|    }
    #|  ],
    #|  "span": [0, 13],
    #|  "vendor": true
    #|}
  let model = match parse_mf2_model_json(source) {
    Ok(value) => value
    Err(message) => fail("extension fields should be ignored: " + message)
  }
  assert_eq(serialize_mf2_model(model), Ok("{{Hello {$name}}}"))
}

///|
test "MF2 interchange JSON rejects invalid shapes and invalid models" {
  let sources = [
    "not json", "{}", "{\"type\":1}", "{\"type\":\"unknown\",\"declarations\":[]}",
    "{\"type\":\"message\",\"declarations\":{\"x\":1},\"pattern\":[]}", "{\"type\":\"message\",\"declarations\":[]}",
    "[]", "{\"type\":\"message\",\"declarations\":[],\"pattern\":{}}", "{\"type\":\"message\",\"declarations\":[],\"pattern\":[{}]}",
    "{\"type\":\"message\",\"declarations\":[],\"pattern\":[1]}", "{\"type\":\"select\",\"declarations\":[],\"selectors\":[],\"variants\":[]}",
    "{\"type\":\"select\",\"declarations\":[],\"selectors\":[],\"variants\":[{\"keys\":[],\"value\":[]}]}",
    "{\"type\":\"select\",\"declarations\":[],\"selectors\":{},\"variants\":[]}",
    "{\"type\":\"select\",\"declarations\":[],\"selectors\":[{\"type\":\"literal\",\"value\":\"x\"}],\"variants\":[]}",
    "{\"type\":\"select\",\"declarations\":[],\"selectors\":[{}],\"variants\":[]}",
    "{\"type\":\"select\",\"declarations\":[],\"selectors\":[],\"variants\":{}}",
    "{\"type\":\"select\",\"declarations\":[],\"selectors\":[],\"variants\":[1]}",
    "{\"type\":\"message\",\"declarations\":[],\"pattern\":[{\"type\":\"expression\",\"attributes\":{}}]}",
    "{\"type\":\"message\",\"declarations\":[],\"pattern\":[{\"type\":\"expression\",\"arg\":{},\"attributes\":{}}]}",
    "{\"type\":\"message\",\"declarations\":[],\"pattern\":[{\"type\":\"expression\",\"function\":{},\"attributes\":{}}]}",
    "{\"type\":\"message\",\"declarations\":[],\"pattern\":[{\"type\":\"expression\",\"arg\":{\"type\":\"literal\",\"value\":1},\"attributes\":{}}]}",
    "{\"type\":\"message\",\"declarations\":[],\"pattern\":[{\"type\":\"expression\",\"arg\":{\"type\":\"variable\",\"name\":1},\"attributes\":{}}]}",
    "{\"type\":\"message\",\"declarations\":[],\"pattern\":[{\"type\":\"expression\",\"arg\":{\"type\":\"wat\"},\"attributes\":{}}]}",
    "{\"type\":\"message\",\"declarations\":[],\"pattern\":[{\"type\":\"expression\",\"function\":{\"type\":\"function\",\"name\":1},\"attributes\":{}}]}",
    "{\"type\":\"message\",\"declarations\":[],\"pattern\":[{\"type\":\"expression\",\"function\":{\"type\":\"function\",\"name\":\"f\",\"options\":[]},\"attributes\":{}}]}",
    "{\"type\":\"message\",\"declarations\":[],\"pattern\":[{\"type\":\"expression\",\"function\":{\"type\":\"function\",\"name\":\"f\",\"options\":{\"x\":1}},\"attributes\":{}}]}",
    "{\"type\":\"message\",\"declarations\":[],\"pattern\":[{\"type\":\"expression\",\"arg\":{\"type\":\"literal\",\"value\":\"x\"},\"attributes\":[]}]}",
    "{\"type\":\"message\",\"declarations\":[],\"pattern\":[{\"type\":\"expression\",\"arg\":{\"type\":\"literal\",\"value\":\"x\"},\"attributes\":{\"a\":false}}]}",
    "{\"type\":\"message\",\"declarations\":[],\"pattern\":[{\"type\":\"expression\",\"arg\":{\"type\":\"literal\",\"value\":\"x\"},\"attributes\":{\"a\":{\"type\":\"variable\",\"name\":\"x\"}}}]}",
    "{\"type\":\"message\",\"declarations\":[],\"pattern\":[{\"type\":\"markup\",\"kind\":\"bad\",\"name\":\"tag\"}]}",
    "{\"type\":\"message\",\"declarations\":[],\"pattern\":[{\"type\":\"markup\",\"kind\":\"open\",\"name\":1}]}",
    "{\"type\":\"message\",\"declarations\":[],\"pattern\":[{\"type\":\"markup\",\"kind\":\"open\",\"name\":\"tag\",\"options\":[]}]}",
    "{\"type\":\"message\",\"declarations\":[],\"pattern\":[{\"type\":\"markup\",\"kind\":\"open\",\"name\":\"tag\",\"attributes\":[]}]}",
    "{\"type\":\"message\",\"declarations\":[1],\"pattern\":[]}", "{\"type\":\"message\",\"declarations\":[{\"type\":1,\"name\":\"x\",\"value\":{}}],\"pattern\":[]}",
    "{\"type\":\"message\",\"declarations\":[{\"type\":\"local\",\"name\":1,\"value\":{}}],\"pattern\":[]}",
    "{\"type\":\"message\",\"declarations\":[{\"type\":\"local\",\"name\":\"x\"}],\"pattern\":[]}",
    "{\"type\":\"message\",\"declarations\":[{\"type\":\"bad\",\"name\":\"x\",\"value\":{\"type\":\"expression\",\"arg\":{\"type\":\"literal\",\"value\":\"x\"},\"attributes\":{}}}],\"pattern\":[]}",
    "{\"type\":\"message\",\"declarations\":[{\"type\":\"input\",\"name\":\"x\",\"value\":{\"type\":\"expression\",\"arg\":{\"type\":\"variable\",\"name\":\"y\"},\"attributes\":{}}}],\"pattern\":[]}",
    "{\"type\":\"select\",\"declarations\":[],\"selectors\":[{\"type\":\"variable\",\"name\":\"x\"}],\"variants\":[{\"keys\":{},\"value\":[]}]}",
    "{\"type\":\"select\",\"declarations\":[],\"selectors\":[{\"type\":\"variable\",\"name\":\"x\"}],\"variants\":[{\"keys\":[{\"type\":\"variable\",\"name\":\"x\"}],\"value\":[]}]}",
    "{\"type\":\"select\",\"declarations\":[],\"selectors\":[{\"type\":\"variable\",\"name\":\"x\"}],\"variants\":[{\"keys\":[{}],\"value\":[]}]}",
    "{\"type\":\"select\",\"declarations\":[],\"selectors\":[{\"type\":\"variable\",\"name\":\"x\"}],\"variants\":[{\"keys\":[{\"type\":\"*\"}]}]}",
  ]
  for source in sources {
    assert_true(parse_mf2_model_json(source) is Err(_))
  }
}

///|
test "MF2 syntax and interchange enforce public resource boundaries" {
  guard parse_mf2_syntax("x".repeat(MF2_MAX_MESSAGE_BYTES + 1)) is Err(error) else {
    fail("oversized syntax must fail")
  }
  assert_eq(error.code, Mf2LimitCode)
  assert_standard_syntax_error("bad \u{0} value")
  assert_true(parse_valid_mf2_model("{") is Err(_))
  assert_true(
    parse_mf2_model_json("x".repeat(CATALOG_MAX_SOURCE_BYTES + 1)) is Err(_),
  )
  let oversized_model : Mf2MessageModel = Mf2PatternMessage([], {
    parts: [Mf2ModelText("x".repeat(MF2_MAX_MESSAGE_BYTES + 1))],
  })
  assert_true(serialize_mf2_model(oversized_model) is Err(_))
  assert_true(mf2_model_to_json(oversized_model) is Err(_))
}

///|
test "MF2 model serializers cover multi-selector and standalone structures" {
  let source = ".input {$x :string}.input {$y :string}.local $f = {:custom opt=$x}.match $x $y a b {{{#tag value=$y /}{$f}}} * * {{other}}"
  let model = match parse_valid_mf2_model(source) {
    Ok(value) => value
    Err(errors) => fail("model should be valid: " + errors[0].message)
  }
  guard serialize_mf2_model(model) is Ok(syntax) else {
    fail("multi-selector model should serialize")
  }
  assert_true(syntax.contains(".match $x $y"))
  assert_true(syntax.contains("a b {{"))
  assert_true(syntax.contains("{#tag value=$y /}"))
  guard mf2_model_to_json(model) is Ok(json) else {
    fail("multi-selector model should encode")
  }
  assert_true(json.contains("\"kind\": \"standalone\""))

  let invalid = assert_standard_syntax_ok(
    ".input {$x :string}.match $x * {{one}} * {{two}}",
  )
  assert_true(serialize_mf2_model(invalid) is Err(_))
  assert_true(mf2_model_to_json(invalid) is Err(_))
}
