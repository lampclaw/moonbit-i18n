///|
let tooling_schema =
  #|{
  #|  "messages": { "auth": ["welcome"] },
  #|  "params": {
  #|    "auth.welcome": [{ "name": "name", "type": "String" }]
  #|  },
  #|  "descriptions": { "auth.welcome": "Greeting <shown>" }
  #|}

///|
let tooling_source = "{ \"auth\": { \"welcome\": \"Hello {$name}\" } }"

///|
test "strict XLIFF 2.1 export and import preserve MF2 messages" {
  let target = "{ \"auth\": { \"welcome\": \"你好 {$name}\" } }"
  guard export_xliff(
      tooling_schema,
      "en_US",
      tooling_source,
      "zh_CN",
      Some(target),
    )
    is Ok(xliff) else {
    fail("XLIFF export should succeed")
  }
  assert_true(xliff.contains("version=\"2.1\""))
  assert_true(xliff.contains("srcLang=\"en-US\""))
  assert_true(xliff.contains("trgLang=\"zh-CN\""))
  assert_true(xliff.contains("<note>Greeting &lt;shown&gt;</note>"))
  guard import_xliff(tooling_schema, "en-US", tooling_source, "zh-CN", xliff)
    is Ok(imported) else {
    fail("XLIFF import should succeed")
  }
  assert_true(imported.contains("你好 {$name}"))
  assert_eq(validate_generated_xliff_budget("界", 3), Ok(()))
  assert_true(validate_generated_xliff_budget("界a", 3) is Err(_))
}

///|
test "XLIFF parser handles entities, CDATA, namespaces, and layout" {
  let schema = "{ \"messages\": { \"common\": [\"save\"] } }"
  let source = "{ \"common\": { \"save\": \"Save & close\" } }"
  let xliff =
    #|<?xml version="1.0"?>
    #|<x:xliff xmlns:x="urn:oasis:names:tc:xliff:document:2.0"
    #|  version="2.1" srcLang="en-US" trgLang="fr">
    #|  <x:file id="messages">
    #|    <x:unit id="common.save">
    #|      <x:segment>
    #|        <x:source>Save &amp; close</x:source>
    #|        <x:target state="translated"><![CDATA[Enregistrer & fermer]]></x:target>
    #|      </x:segment>
    #|    </x:unit>
    #|  </x:file>
    #|</x:xliff>
  guard import_xliff(schema, "en-US", source, "fr", xliff) is Ok(resource) else {
    fail("namespace-aware XLIFF should import")
  }
  assert_true(resource.contains("Enregistrer & fermer"))
}

///|
test "XLIFF import rejects stale source, duplicates, and DOCTYPE" {
  let schema = "{ \"messages\": { \"common\": [\"save\"] } }"
  let source = "{ \"common\": { \"save\": \"Save\" } }"
  let stale =
    #|<xliff xmlns="urn:oasis:names:tc:xliff:document:2.0" version="2.1" srcLang="en-US" trgLang="fr">
    #|  <file id="messages"><unit id="common.save"><segment>
    #|    <source>Old Save</source><target>Enregistrer</target>
    #|  </segment></unit></file>
    #|</xliff>
  guard import_xliff(schema, "en-US", source, "fr", stale) is Err(message) else {
    fail("stale source must fail")
  }
  assert_true(message.contains("stale XLIFF source"))
  let duplicate = stale
    .replace_all(old="Old Save", new="Save")
    .replace_all(
      old="</file>",
      new="<unit id=\"common.save\"><segment><source>Save</source><target>Bis</target></segment></unit></file>",
    )
  guard import_xliff(schema, "en-US", source, "fr", duplicate) is Err(dup) else {
    fail("duplicate units must fail")
  }
  assert_true(dup.contains("duplicate XLIFF unit id"))
  let doctype =
    #|<!DOCTYPE xliff [<!ENTITY x "Save">]>
    #|<xliff xmlns="urn:oasis:names:tc:xliff:document:2.0" version="2.1" srcLang="en-US" trgLang="fr">
    #|  <file id="messages"><unit id="common.save"><segment><source>&x;</source><target>Ok</target></segment></unit></file>
    #|</xliff>
  assert_true(
    import_xliff(schema, "en-US", source, "fr", doctype)
    is Err("DOCTYPE is not allowed in XLIFF"),
  )
}

///|
test "XLIFF validates source and target locale metadata" {
  let schema = "{ \"messages\": { \"common\": [\"save\"] } }"
  let source = "{ \"common\": { \"save\": \"Save\" } }"
  let xliff =
    #|<xliff xmlns="urn:oasis:names:tc:xliff:document:2.0" version="2.1" srcLang="de" trgLang="fr">
    #|  <file id="messages"><unit id="common.save"><segment><source>Save</source><target>Speichern</target></segment></unit></file>
    #|</xliff>
  guard import_xliff(schema, "en-US", source, "fr", xliff) is Err(message) else {
    fail("mismatched source locale should fail")
  }
  assert_true(message.contains("source locale mismatch"))
}

///|
test "pseudo locale preserves expressions and robust matcher boundaries" {
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
    #|    "count": ".input {$count :number}\n.match $count\n1 {{Exact}}\n* {{{$count}}}"
    #|  }
    #|}
  guard pseudo_locale(schema, "en-US", source, "en-XA") is Ok(pseudo) else {
    fail("selector pseudo locale should succeed")
  }
  assert_true(pseudo.contains("1 {{[Ëxáct !!!]}}"))
  assert_true(pseudo.contains("* {{[{$count} !!!]}}"))
  guard pseudo_locale(schema, "en-US", source, "ar-XB") is Ok(rtl) else {
    fail("RTL pseudo locale should succeed")
  }
  assert_true(rtl.contains("\u{202e}{$count}\u{202c}"))
}

///|
test "tooling rejects unknown pseudo modes and unsupported XLIFF shapes" {
  let schema = "{ \"messages\": { \"common\": [\"save\"] } }"
  let source = "{ \"common\": { \"save\": \"Save\" } }"
  assert_true(pseudo_locale(schema, "en-US", source, "test") is Err(_))
  let no_namespace =
    #|<xliff version="2.1" srcLang="en-US" trgLang="fr"><file id="messages"/></xliff>
  guard import_xliff(schema, "en-US", source, "fr", no_namespace)
    is Err(message) else {
    fail("namespace-less XLIFF must fail")
  }
  assert_true(message.contains("namespace"))
  assert_true(export_xliff(schema, "en-US", source, "123", None) is Err(_))
}

///|
test "XLIFF profile enforces hierarchy and rejects stray text" {
  let schema = "{ \"messages\": { \"common\": [\"save\"] } }"
  let source = "{ \"common\": { \"save\": \"Save\" } }"
  let direct_source =
    #|<xliff xmlns="urn:oasis:names:tc:xliff:document:2.0" version="2.1" srcLang="en-US" trgLang="fr">
    #|  <file id="messages"><unit id="common.save"><source>Save</source><target>Ok</target></unit></file>
    #|</xliff>
  assert_true(
    import_xliff(schema, "en-US", source, "fr", direct_source) is Err(_),
  )
  let missing_file_id =
    #|<xliff xmlns="urn:oasis:names:tc:xliff:document:2.0" version="2.1" srcLang="en-US" trgLang="fr">
    #|  <file><unit id="common.save"><segment><source>Save</source><target>Ok</target></segment></unit></file>
    #|</xliff>
  assert_true(
    import_xliff(schema, "en-US", source, "fr", missing_file_id)
    is Err("XLIFF file is missing id"),
  )
  let stray_text =
    #|<xliff xmlns="urn:oasis:names:tc:xliff:document:2.0" version="2.1" srcLang="en-US" trgLang="fr">
    #|  stray<file id="messages"><unit id="common.save"><segment><source>Save</source><target>Ok</target></segment></unit></file>
    #|</xliff>
  assert_true(import_xliff(schema, "en-US", source, "fr", stray_text) is Err(_))
}
