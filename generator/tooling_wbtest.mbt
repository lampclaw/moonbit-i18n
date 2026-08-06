///|
test "XLIFF export and import preserve MF2 messages" {
  let schema =
    #|{
    #|  "messages": { "auth": ["welcome"] },
    #|  "params": {
    #|    "auth.welcome": [{ "name": "name", "type": "String" }]
    #|  },
    #|  "descriptions": { "auth.welcome": "Greeting <shown>" }
    #|}
  let source = "{ \"auth\": { \"welcome\": \"Hello {$name}\" } }"
  let target = "{ \"auth\": { \"welcome\": \"你好 {$name}\" } }"
  guard export_xliff(schema, "en_US", source, "zh_CN", Some(target))
    is Ok(xliff) else {
    fail("XLIFF export should succeed")
  }
  assert_true(xliff.contains("version=\"2.1\""))
  assert_true(xliff.contains("srcLang=\"en-US\" trgLang=\"zh-CN\""))
  assert_true(xliff.contains("<note>Greeting &lt;shown&gt;</note>"))
  guard import_xliff(schema, "zh-CN", xliff) is Ok(imported) else {
    fail("XLIFF import should succeed")
  }
  assert_true(imported.contains("你好 {$name}"))
}

///|
test "pseudo locale preserves MF2 expressions" {
  let schema =
    #|{
    #|  "messages": { "auth": ["welcome"] },
    #|  "params": {
    #|    "auth.welcome": [{ "name": "name", "type": "String" }]
    #|  }
    #|}
  let source = "{ \"auth\": { \"welcome\": \"Hello {$name}\" } }"
  guard pseudo_locale(schema, "en-US", source, "en-XA") is Ok(pseudo) else {
    fail("pseudo locale should succeed")
  }
  assert_true(pseudo.contains("[Hëllõ {$name} !!!]"))
  guard pseudo_locale(schema, "en-US", source, "ar-XB") is Ok(rtl) else {
    fail("RTL pseudo locale should succeed")
  }
  assert_true(rtl.contains("\u{202e}Hëllõ {$name}\u{202c}"))
}

///|
test "pseudo locale preserves MF2 declarations and selector syntax" {
  let schema =
    #|{
    #|  "messages": { "counter": ["count"] },
    #|  "params": {
    #|    "counter.count": [{ "name": "count", "type": "Int" }]
    #|  }
    #|}
  let source =
    #|{
    #|  "counter": {
    #|    "count": ".input {$count :number}\n.match $count\none {{One active}}\n* {{{$count} active}}"
    #|  }
    #|}
  guard pseudo_locale(schema, "en-US", source, "en-XA") is Ok(pseudo) else {
    fail("selector pseudo locale should succeed")
  }
  assert_true(pseudo.contains(".input {$count :number}\\n.match $count"))
  assert_true(pseudo.contains("one {{[Õnë áctïvë !!!]}}"))
  assert_true(pseudo.contains("* {{[{$count} áctïvë !!!]}}"))
}

///|
test "tooling rejects unknown pseudo modes and XLIFF units" {
  let schema = "{ \"messages\": { \"common\": [\"save\"] } }"
  let source = "{ \"common\": { \"save\": \"Save\" } }"
  assert_true(pseudo_locale(schema, "en-US", source, "test") is Err(_))
  let bad_xliff =
    #|<unit id="unknown.key"><segment><target>Value</target></segment></unit>
  guard import_xliff(schema, "fr", bad_xliff) is Err(message) else {
    fail("unknown XLIFF unit should fail")
  }
  assert_true(message.contains("unknown XLIFF unit id"))
  assert_true(export_xliff(schema, "en-US", source, "123", None) is Err(_))
}

///|
test "XLIFF import accepts pretty-printed translation units" {
  let schema = "{ \"messages\": { \"common\": [\"save\"] } }"
  let xliff =
    #|<xliff version="2.1">
    #|  <file id="messages">
    #|    <unit id="common.save">
    #|      <segment>
    #|        <source>Save</source>
    #|        <target state="translated">Enregistrer</target>
    #|      </segment>
    #|    </unit>
    #|  </file>
    #|</xliff>
  guard import_xliff(schema, "fr", xliff) is Ok(resource) else {
    fail("pretty-printed XLIFF should import")
  }
  assert_true(resource.contains("Enregistrer"))
}

///|
test "XLIFF import rejects a mismatched target locale" {
  let schema = "{ \"messages\": { \"common\": [\"save\"] } }"
  let xliff =
    #|<xliff version="2.1" srcLang="en-US" trgLang="fr">
    #|  <unit id="common.save"><target>Enregistrer</target></unit>
    #|</xliff>
  guard import_xliff(schema, "de", xliff) is Err(message) else {
    fail("mismatched XLIFF target locale should fail")
  }
  assert_true(message.contains("target locale mismatch"))
}

///|
test "XLIFF import rejects duplicate units" {
  let schema = "{ \"messages\": { \"common\": [\"save\"] } }"
  let xliff =
    #|<unit id="common.save"><target>Save</target></unit>
    #|<unit id="common.save"><target>Again</target></unit>
  guard import_xliff(schema, "en-US", xliff) is Err(message) else {
    fail("duplicate XLIFF units should fail")
  }
  assert_true(message.contains("duplicate XLIFF unit id"))
}
