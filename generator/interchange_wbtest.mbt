///|
test "state-aware XLIFF round trip preserves identity context state and MF2" {
  let schema =
    #|{
    #|  "messages": { "auth": ["welcome"] },
    #|  "params": {
    #|    "auth.welcome": [{ "name": "name", "type": "String" }]
    #|  },
    #|  "descriptions": { "auth.welcome": "Greeting context" }
    #|}
  let source = "{ \"auth\": { \"welcome\": \"Hello {$name}\" } }"
  let target = "{ \"auth\": { \"welcome\": \"Bonjour {$name}\" } }"
  let xliff =
    #|<xliff xmlns="urn:oasis:names:tc:xliff:document:2.0" version="2.1" srcLang="en-US" trgLang="fr">
    #|  <file id="messages" original="locales/fr.json">
    #|    <unit id="auth.welcome" name="stable-welcome" translate="yes" canResegment="no">
    #|      <notes>
    #|        <note id="source-context" category="description" appliesTo="source">Greeting context</note>
    #|        <note id="translator" category="translator" appliesTo="target" priority="2">Keep the product name</note>
    #|      </notes>
    #|      <segment id="segment-1" state="reviewed" subState="vendor-approved">
    #|        <source xml:space="preserve">Hello {$name}</source>
    #|        <target xml:space="preserve">Bonjour {$name}</target>
    #|      </segment>
    #|    </unit>
    #|  </file>
    #|</xliff>
  guard import_xliff_with_state(schema, "en-US", source, "fr", xliff, None)
    is Ok(first) else {
    fail("state-aware XLIFF import should succeed")
  }
  assert_true(first.locale_source.contains("Bonjour {$name}"))
  assert_true(first.exchange_state.contains("\"state\": \"reviewed\""))
  assert_true(first.exchange_state.contains("Keep the product name"))
  assert_true(first.exchange_state.contains("\"sourceSha256\""))
  assert_true(first.report.contains("\"lossCount\": 0"))
  guard export_xliff_with_state(
      schema,
      "en-US",
      source,
      "fr",
      Some(target),
      Some(first.exchange_state),
    )
    is Ok(exported) else {
    fail("state-aware XLIFF export should succeed")
  }
  assert_true(exported.contains("state=\"reviewed\""))
  assert_true(exported.contains("subState=\"vendor-approved\""))
  assert_true(exported.contains("category=\"translator\""))
  assert_true(exported.contains("Bonjour {$name}"))
  guard import_xliff_with_state(schema, "en-US", source, "fr", exported, None)
    is Ok(second) else {
    fail("round-tripped XLIFF should import")
  }
  assert_eq(second.locale_source, first.locale_source)
  assert_eq(second.exchange_state, first.exchange_state)
}

///|
test "XLIFF lifecycle rejects stale sidecars and stale translated sources" {
  let schema = "{ \"messages\": { \"common\": [\"save\"] } }"
  let source = "{ \"common\": { \"save\": \"Save\" } }"
  let target = "{ \"common\": { \"save\": \"Enregistrer\" } }"
  guard export_xliff(schema, "en-US", source, "fr", Some(target)) is Ok(xliff) else {
    fail("XLIFF export should succeed")
  }
  guard import_xliff_with_state(schema, "en-US", source, "fr", xliff, None)
    is Ok(imported) else {
    fail("XLIFF import should succeed")
  }
  let changed_source = "{ \"common\": { \"save\": \"Save now\" } }"
  guard export_xliff_with_state(
      schema,
      "en-US",
      changed_source,
      "fr",
      Some(target),
      Some(imported.exchange_state),
    )
    is Err(message) else {
    fail("stale exchange state must fail")
  }
  assert_true(message.contains("stale XLIFF exchange state source"))
  let stale_xliff = xliff.replace_all(old="Save", new="Save now")
  guard import_xliff_with_state(
      schema,
      "en-US",
      source,
      "fr",
      stale_xliff,
      None,
    )
    is Err(stale_message) else {
    fail("stale XLIFF source must fail")
  }
  assert_true(stale_message.contains("stale XLIFF source"))
}

///|
test "explicit XLIFF ID migrations safely rename and report removals" {
  let schema = "{ \"messages\": { \"common\": [\"save\"] } }"
  let source = "{ \"common\": { \"save\": \"Save\" } }"
  let xliff =
    #|<xliff xmlns="urn:oasis:names:tc:xliff:document:2.0" version="2.1" srcLang="en-US" trgLang="fr">
    #|  <file id="messages">
    #|    <unit id="legacy.save"><segment state="translated"><source>Save</source><target>Enregistrer</target></segment></unit>
    #|    <unit id="legacy.delete"><segment state="translated"><source>Delete</source><target>Supprimer</target></segment></unit>
    #|  </file>
    #|</xliff>
  let migrations =
    #|{
    #|  "version": 1,
    #|  "renames": { "legacy.save": "common.save" },
    #|  "removed": ["legacy.delete"]
    #|}
  guard import_xliff_with_state(
      schema,
      "en-US",
      source,
      "fr",
      xliff,
      Some(migrations),
    )
    is Ok(imported) else {
    fail("explicit ID migration should succeed")
  }
  assert_true(imported.locale_source.contains("Enregistrer"))
  assert_true(imported.report.contains("\"renamedUnits\": 1"))
  assert_true(imported.report.contains("\"removedUnits\": 1"))
  assert_true(imported.report.contains("I18N_XLIFF_ID_REMOVED"))
  assert_true(imported.report.contains("\"lossCount\": 1"))
  assert_true(
    import_xliff_with_state(schema, "en-US", source, "fr", xliff, None)
    is Err(_),
  )
}

///|
test "XLIFF reports every intentionally discarded metadata item" {
  let schema = "{ \"messages\": { \"common\": [\"save\"] } }"
  let source = "{ \"common\": { \"save\": \"Save\" } }"
  let xliff =
    #|<xliff xmlns="urn:oasis:names:tc:xliff:document:2.0" version="2.1" srcLang="en-US" trgLang="fr" vendor="tool">
    #|  <!-- workflow marker -->
    #|  <file id="messages"><unit id="common.save"><segment state="final">
    #|    <source>Save</source><target custom="value">Enregistrer</target>
    #|  </segment></unit></file>
    #|</xliff>
  guard import_xliff_with_state(schema, "en-US", source, "fr", xliff, None)
    is Ok(imported) else {
    fail("supported XLIFF with discardable metadata should import")
  }
  assert_true(imported.report.contains("xliff@vendor"))
  assert_true(imported.report.contains("target@custom"))
  assert_true(imported.report.contains("discarded XML comment"))
  assert_true(imported.report.contains("\"lossCount\": 3"))
}

///|
test "XLIFF drops namespace-qualified subState with an explicit loss report" {
  let schema = "{ \"messages\": { \"common\": [\"save\"] } }"
  let source = "{ \"common\": { \"save\": \"Save\" } }"
  let xliff =
    #|<xliff xmlns="urn:oasis:names:tc:xliff:document:2.0" xmlns:vendor="https://example.com/xliff/vendor" version="2.1" srcLang="en-US" trgLang="fr">
    #|  <file id="messages"><unit id="common.save"><segment state="reviewed" subState="vendor:approved">
    #|    <source>Save</source><target>Enregistrer</target>
    #|  </segment></unit></file>
    #|</xliff>
  guard import_xliff_with_state(schema, "en-US", source, "fr", xliff, None)
    is Ok(imported) else {
    fail("namespace-qualified XLIFF subState should import with reported loss")
  }
  assert_true(imported.report.contains("segment@subState"))
  assert_true(imported.report.contains("namespace-qualified XLIFF subState"))
  let target = "{ \"common\": { \"save\": \"Enregistrer\" } }"
  guard export_xliff_with_state(
      schema,
      "en-US",
      source,
      "fr",
      Some(target),
      Some(imported.exchange_state),
    )
    is Ok(exported) else {
    fail("state-aware XLIFF export should succeed after dropping the prefix")
  }
  assert_false(exported.contains("subState=\"vendor:approved\""))
}

///|
test "i18next and ARB importers are deterministic and loss-explicit" {
  let schema =
    #|{
    #|  "messages": { "auth": ["welcome"] },
    #|  "params": {
    #|    "auth.welcome": [{ "name": "name", "type": "String" }]
    #|  }
    #|}
  let i18next =
    #|{
    #|  "auth": {
    #|    "welcome": "Hello {{name}}",
    #|    "unused_other": "Unused"
    #|  }
    #|}
  guard import_i18next_json(schema, "en-US", i18next) is Ok(i18next_result) else {
    fail("common i18next JSON should import")
  }
  assert_true(i18next_result.locale_source.contains("Hello {$name}"))
  assert_true(i18next_result.report.contains("plural or context variant"))
  assert_true(i18next_result.report.contains("\"lossCount\": 1"))
  assert_eq(import_i18next_json(schema, "en-US", i18next), Ok(i18next_result))
  let arb =
    #|{
    #|  "@@locale": "fr",
    #|  "welcome": "Bonjour {name}",
    #|  "@welcome": {
    #|    "description": "Greeting",
    #|    "placeholders": { "name": { "type": "String" } }
    #|  }
    #|}
  guard import_flutter_arb(schema, "fr", arb) is Ok(arb_result) else {
    fail("common ARB should import")
  }
  assert_true(arb_result.locale_source.contains("Bonjour {$name}"))
  assert_true(arb_result.report.contains("I18N_ARB_METADATA_DISCARDED"))
  assert_true(arb_result.report.contains("\"lossCount\": 2"))
}

///|
test "interchange rejects unsafe lifecycle metadata and migration maps" {
  let schema = "{ \"messages\": { \"common\": [\"save\"] } }"
  let source = "{ \"common\": { \"save\": \"Save\" } }"
  let invalid_state =
    #|<xliff xmlns="urn:oasis:names:tc:xliff:document:2.0" version="2.1" srcLang="en-US" trgLang="fr">
    #|  <file id="messages"><unit id="common.save"><segment state="approved">
    #|    <source>Save</source><target>Enregistrer</target>
    #|  </segment></unit></file>
    #|</xliff>
  guard import_xliff_with_state(
      schema,
      "en-US",
      source,
      "fr",
      invalid_state,
      None,
    )
    is Err(state_error) else {
    fail("unknown XLIFF states must fail")
  }
  assert_true(state_error.contains("unsupported XLIFF translation state"))
  let invalid_space = invalid_state
    .replace_all(old="state=\"approved\"", new="state=\"reviewed\"")
    .replace_all(old="<source>", new="<source xml:space=\"collapse\">")
  guard import_xliff_with_state(
      schema,
      "en-US",
      source,
      "fr",
      invalid_space,
      None,
    )
    is Err(space_error) else {
    fail("invalid xml:space must fail")
  }
  assert_true(space_error.contains("invalid xml:space"))
  let current_removed =
    #|{ "version": 1, "renames": {}, "removed": ["common.save"] }
  assert_true(
    import_xliff_with_state(
      schema,
      "en-US",
      source,
      "fr",
      invalid_state,
      Some(current_removed),
    )
    is Err(_),
  )
  let colliding_renames =
    #|{
    #|  "version": 1,
    #|  "renames": {
    #|    "old.save": "common.save",
    #|    "older.save": "common.save"
    #|  },
    #|  "removed": []
    #|}
  assert_true(
    import_xliff_with_state(
      schema,
      "en-US",
      source,
      "fr",
      invalid_state,
      Some(colliding_renames),
    )
    is Err(_),
  )
  let wrong_locale_arb =
    #|{ "@@locale": "de", "common.save": "Speichern" }
  guard import_flutter_arb(schema, "fr", wrong_locale_arb) is Err(arb_error) else {
    fail("ARB locale mismatch must fail")
  }
  assert_true(arb_error.contains("ARB locale mismatch"))
}

///|
test "interchange validates public error boundaries and partial migration" {
  let schema = "{ \"messages\": { \"common\": [\"save\"] } }"
  let source = "{ \"common\": { \"save\": \"Save\" } }"
  assert_true(
    export_xliff_with_state("{", "en-US", source, "fr", None, None) is Err(_),
  )
  assert_true(
    export_xliff_with_state(schema, "en-US", "{", "fr", None, None) is Err(_),
  )
  assert_true(
    export_xliff_with_state(
      schema,
      "en-US",
      "{ \"common\": {} }",
      "fr",
      None,
      None,
    )
    is Err(_),
  )
  assert_true(
    export_xliff_with_state(schema, "en-US", source, "fr", Some("{"), None)
    is Err(_),
  )
  guard export_xliff_with_state(schema, "en-US", source, "fr", None, None)
    is Ok(empty_target) else {
    fail("export without a target resource should succeed")
  }
  assert_true(empty_target.contains("state=\"initial\""))
  let translated = empty_target.replace_all(
    old="<target></target>",
    new="<target>Enregistrer</target>",
  )
  guard import_xliff_with_state(schema, "en-US", source, "fr", translated, None)
    is Ok(imported) else {
    fail("translated XLIFF should import")
  }
  let changed_target = "{ \"common\": { \"save\": \"Autre\" } }"
  guard export_xliff_with_state(
      schema,
      "en-US",
      source,
      "fr",
      Some(changed_target),
      Some(imported.exchange_state),
    )
    is Err(stale_target) else {
    fail("changed target must invalidate reviewed exchange metadata")
  }
  assert_true(stale_target.contains("stale XLIFF exchange state target"))
  assert_true(
    import_xliff_with_state(schema, "en-US", source, "fr", "<", None) is Err(_),
  )
  assert_true(import_i18next_json("{", "fr", "{}") is Err(_))
  assert_true(import_i18next_json(schema, "123", "{}") is Err(_))
  assert_true(import_i18next_json(schema, "fr", "{") is Err(_))
  assert_true(import_i18next_json(schema, "fr", "[]") is Err(_))
  guard import_i18next_json(
      schema, "fr", "{ \"common\": { \"save\": 42, \"unknown\": \"x\" } }",
    )
    is Ok(non_string) else {
    fail("lossy i18next migration should return a report")
  }
  assert_true(non_string.report.contains("I18N_MIGRATION_VALUE_DISCARDED"))
  assert_true(non_string.report.contains("discarded unknown message"))
  guard import_i18next_json(
      schema, "fr", "{ \"common\": { \"save\": \"Bad {\" } }",
    )
    is Ok(invalid_mf2) else {
    fail("invalid migrated MF2 should be reported")
  }
  assert_true(invalid_mf2.report.contains("I18N_MIGRATION_MF2_DISCARDED"))
  assert_true(import_flutter_arb(schema, "fr", "{ \"@@locale\": 1 }") is Err(_))
  let ambiguous_schema =
    #|{ "messages": { "first": ["welcome"], "second": ["welcome"] } }
  guard import_flutter_arb(
      ambiguous_schema, "fr", "{ \"welcome\": \"Bonjour\" }",
    )
    is Ok(ambiguous) else {
    fail("ambiguous ARB keys should be loss-reported")
  }
  assert_true(ambiguous.report.contains("discarded unknown message"))
}
