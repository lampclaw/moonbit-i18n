///|
const XLIFF_EXCHANGE_STATE_VERSION : Int = 1

///|
const INTERCHANGE_REPORT_VERSION : Int = 1

///|
const XLIFF_MAX_NOTES_PER_UNIT : Int = 64

///|
const XLIFF_MAX_DEPTH : Int = 16

///|
const XLIFF_XML_NAMESPACE : String = "http://www.w3.org/XML/1998/namespace"

///|
priv struct ExchangeNote {
  text : String
  id : String
  category : String
  applies_to : String
  priority : String
}

///|
priv struct ExchangeUnit {
  id : String
  source : String
  target : String
  state : String
  sub_state : String
  unit_name : String
  translate : String
  can_resegment : String
  segment_id : String
  source_space : String
  target_space : String
  notes : Array[ExchangeNote]
}

///|
priv struct ExchangeState {
  source_locale : String
  target_locale : String
  file_id : String
  file_original : String
  units : Array[ExchangeUnit]
}

///|
priv struct InterchangeNotice {
  code : String
  severity : String
  id : String
  field : String
  message : String
  loss : Bool
}

///|
priv struct IdMigrations {
  renames : Array[(String, String)]
  removed : Array[String]
}

///|
priv struct ParsedXliff {
  state : ExchangeState
  notices : Array[InterchangeNotice]
  renamed_units : Int
  removed_units : Int
}

///|
/// Files produced by state-aware XLIFF import.
pub(all) struct XliffImportArtifacts {
  /// Canonical locale JSON containing imported MF2 payloads.
  locale_source : String
  /// Versioned lifecycle sidecar for a later state-aware export.
  exchange_state : String
  /// Versioned machine-readable preservation and loss report.
  report : String
} derive(Eq, Debug)

///|
/// Files produced by a deterministic one-way ecosystem migration.
pub(all) struct LocaleMigrationArtifacts {
  /// Canonical locale JSON containing every safely converted message.
  locale_source : String
  /// Versioned machine-readable conversion and loss report.
  report : String
} derive(Eq, Debug)

///|
/// Exports schema-ordered translation units as state-normalized XLIFF 2.1.
/// Use `export_xliff_with_state` to restore reviewed/final states and notes.
pub fn export_xliff(
  schema_source : String,
  source_locale_code : String,
  source_locale_source : String,
  target_locale_code : String,
  target_locale_source : String?,
  message_profile? : String = @runtime.CATALOG_PROFILE,
) -> Result[String, String] {
  export_xliff_with_state(
    schema_source,
    source_locale_code,
    source_locale_source,
    target_locale_code,
    target_locale_source,
    None,
    message_profile~,
  )
}

///|
/// Imports validated XLIFF targets into canonical locale JSON. Use
/// `import_xliff_with_state` when lifecycle metadata and loss reporting must be
/// retained.
pub fn import_xliff(
  schema_source : String,
  source_locale_code : String,
  source_locale_source : String,
  target_locale_code : String,
  xliff_source : String,
  message_profile? : String = @runtime.CATALOG_PROFILE,
) -> Result[String, String] {
  match
    import_xliff_with_state(
      schema_source,
      source_locale_code,
      source_locale_source,
      target_locale_code,
      xliff_source,
      None,
      message_profile~,
    ) {
    Ok(value) => Ok(value.locale_source)
    Err(message) => Err(message)
  }
}

///|
/// Exports XLIFF 2.1 while restoring lifecycle metadata from an optional
/// exchange-state sidecar. The sidecar is rejected when its source or target
/// payload no longer matches the canonical resources.
pub fn export_xliff_with_state(
  schema_source : String,
  source_locale_code : String,
  source_locale_source : String,
  target_locale_code : String,
  target_locale_source : String?,
  exchange_state_source : String?,
  message_profile? : String = @runtime.CATALOG_PROFILE,
) -> Result[String, String] {
  let schema = match parse_schema(schema_source) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let source_locale = match
    parse_locale(
      source_locale_code,
      source_locale_source,
      schema,
      message_profile~,
    ) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  match require_complete(schema, source_locale, "source") {
    Ok(_) => ()
    Err(message) => return Err(message)
  }
  let target_code = match
    normalize_locale(target_locale_code, "target locale") {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let target_locale = match target_locale_source {
    Some(source) =>
      match parse_locale(target_code, source, schema, message_profile~) {
        Ok(value) => Some(value)
        Err(message) => return Err(message)
      }
    None => None
  }
  let prior = match exchange_state_source {
    Some(source) =>
      match parse_exchange_state(source, schema, source_locale, target_code) {
        Ok(value) => Some(value)
        Err(message) => return Err(message)
      }
    None => None
  }
  let state_by_id : Map[String, ExchangeUnit] = Map([])
  let mut file_id = "messages"
  let mut file_original = ""
  match prior {
    Some(value) => {
      file_id = value.file_id
      file_original = value.file_original
      for unit in value.units {
        state_by_id[unit.id] = unit
      }
    }
    None => ()
  }
  let writer = @xml.Writer::new()
  let body = try {
    writer.start_element("xliff", [
      ("xmlns", XLIFF_NAMESPACE),
      ("version", "2.1"),
      ("srcLang", source_locale.locale),
      ("trgLang", target_code),
    ])
    let file_attributes : Array[(String, String)] = [("id", file_id)]
    if !file_original.is_empty() {
      file_attributes.push(("original", file_original))
    }
    writer.start_element("file", file_attributes)
    for schema_entry in schema.entries {
      let id = message_id(schema_entry)
      let source_text = match source_message(source_locale, id) {
        Some(value) => value
        None => return Err("missing source message: \{id}")
      }
      let target_message = match target_locale {
        Some(locale) => source_message(locale, id).unwrap_or("")
        None => ""
      }
      let previous = state_by_id.get(id)
      match previous {
        Some(unit) => {
          if unit.source != source_text ||
            source_digest(unit.source) != source_digest(source_text) {
            return Err("stale XLIFF exchange state source for unit: \{id}")
          }
          if unit.target != target_message {
            return Err("stale XLIFF exchange state target for unit: \{id}")
          }
        }
        None => ()
      }
      let state = match previous {
        Some(unit) => unit.state
        None =>
          if target_message.trim().is_empty() {
            "initial"
          } else {
            "translated"
          }
      }
      let unit_attributes : Array[(String, String)] = [("id", id)]
      let unit_name = match previous {
        Some(unit) if !unit.unit_name.is_empty() => unit.unit_name
        _ => id
      }
      unit_attributes.push(("name", unit_name))
      match previous {
        Some(unit) => {
          push_xml_attribute(unit_attributes, "translate", unit.translate)
          push_xml_attribute(
            unit_attributes,
            "canResegment",
            unit.can_resegment,
          )
        }
        None => ()
      }
      writer.start_element("unit", unit_attributes)
      let notes : Array[ExchangeNote] = []
      match previous {
        Some(unit) =>
          for note in unit.notes {
            notes.push(note)
          }
        None => ()
      }
      match schema_description(schema, id) {
        Some(description) if !has_description_note(notes, description) =>
          notes.push({
            text: description,
            id: "",
            category: "description",
            applies_to: "source",
            priority: "",
          })
        _ => ()
      }
      if !notes.is_empty() {
        writer.start_element("notes", [])
        for note in notes {
          let note_attributes : Array[(String, String)] = []
          push_xml_attribute(note_attributes, "id", note.id)
          push_xml_attribute(note_attributes, "category", note.category)
          push_xml_attribute(note_attributes, "appliesTo", note.applies_to)
          push_xml_attribute(note_attributes, "priority", note.priority)
          writer.start_element("note", note_attributes)
          writer.text(note.text)
          writer.end_element("note")
        }
        writer.end_element("notes")
      }
      let segment_attributes : Array[(String, String)] = []
      let segment_id = match previous {
        Some(unit) if !unit.segment_id.is_empty() => unit.segment_id
        _ => "s1"
      }
      segment_attributes.push(("id", segment_id))
      segment_attributes.push(("state", state))
      match previous {
        Some(unit) =>
          push_xml_attribute(segment_attributes, "subState", unit.sub_state)
        None => ()
      }
      writer.start_element("segment", segment_attributes)
      let source_attributes : Array[(String, String)] = []
      match previous {
        Some(unit) =>
          push_xml_attribute(source_attributes, "xml:space", unit.source_space)
        None => ()
      }
      writer.start_element("source", source_attributes)
      writer.text(source_text)
      writer.end_element("source")
      let target_attributes : Array[(String, String)] = []
      match previous {
        Some(unit) =>
          push_xml_attribute(target_attributes, "xml:space", unit.target_space)
        None => ()
      }
      writer.start_element("target", target_attributes)
      writer.text(target_message)
      writer.end_element("target")
      writer.end_element("segment")
      writer.end_element("unit")
    }
    writer.end_element("file")
    writer.end_element("xliff")
    writer.to_string()
  } catch {
    _ => return Err("failed to serialize XLIFF")
  } noraise {
    value => value
  }
  let output = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n" + body + "\n"
  match validate_generated_xliff_budget(output, XLIFF_MAX_SOURCE_BYTES) {
    Ok(_) => Ok(output)
    Err(message) => Err(message)
  }
}

///|
/// Imports XLIFF 2.1 into canonical locale JSON plus lifecycle state and a
/// complete preservation/loss report. Renames and removals are accepted only
/// through an explicit versioned ID-migration map.
pub fn import_xliff_with_state(
  schema_source : String,
  source_locale_code : String,
  source_locale_source : String,
  target_locale_code : String,
  xliff_source : String,
  id_migrations_source : String?,
  message_profile? : String = @runtime.CATALOG_PROFILE,
) -> Result[XliffImportArtifacts, String] {
  if @utf8.encode(xliff_source).length() > XLIFF_MAX_SOURCE_BYTES {
    return Err("XLIFF exceeds the input size limit")
  }
  let schema = match parse_schema(schema_source) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let source_locale = match
    parse_locale(
      source_locale_code,
      source_locale_source,
      schema,
      message_profile~,
    ) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  match require_complete(schema, source_locale, "source") {
    Ok(_) => ()
    Err(message) => return Err(message)
  }
  let target_code = match
    normalize_locale(target_locale_code, "target locale") {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let migrations = match id_migrations_source {
    Some(source) =>
      match parse_id_migrations(source, schema) {
        Ok(value) => value
        Err(message) => return Err(message)
      }
    None => { renames: [], removed: [] }
  }
  let parsed = match
    parse_xliff_exchange(
      xliff_source,
      source_locale.locale,
      target_code,
      schema,
      source_locale,
      migrations,
    ) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let translated : Array[(String, String)] = []
  for unit in parsed.state.units {
    if !unit.target.trim().is_empty() {
      translated.push((unit.id, unit.target))
    }
  }
  let locale_source = locale_json(schema, translated)
  match parse_locale(target_code, locale_source, schema, message_profile~) {
    Ok(_) => ()
    Err(message) => return Err("invalid imported XLIFF target: \{message}")
  }
  let translated_units = translated.length()
  Ok({
    locale_source,
    exchange_state: exchange_state_json(parsed.state),
    report: interchange_report_json(
      "xliff-import",
      source_locale.locale,
      target_code,
      parsed.state.units.length(),
      translated_units,
      parsed.renamed_units,
      parsed.removed_units,
      parsed.notices,
    ),
  })
}

///|
/// Deterministically imports common two-level or dotted-key i18next JSON.
/// Unsupported plural/context variants and non-string values are omitted and
/// individually recorded in the returned report.
pub fn import_i18next_json(
  schema_source : String,
  locale_code : String,
  input_source : String,
  message_profile? : String = @runtime.CATALOG_PROFILE,
) -> Result[LocaleMigrationArtifacts, String] {
  import_ecosystem_json(
    schema_source,
    locale_code,
    input_source,
    "i18next",
    message_profile~,
  )
}

///|
/// Deterministically imports Flutter ARB messages into canonical locale JSON.
/// ARB metadata which has no canonical locale representation is explicitly
/// reported rather than silently discarded.
pub fn import_flutter_arb(
  schema_source : String,
  locale_code : String,
  input_source : String,
  message_profile? : String = @runtime.CATALOG_PROFILE,
) -> Result[LocaleMigrationArtifacts, String] {
  import_ecosystem_json(
    schema_source,
    locale_code,
    input_source,
    "arb",
    message_profile~,
  )
}

///|
#warnings("-deprecated")
fn import_ecosystem_json(
  schema_source : String,
  locale_code : String,
  input_source : String,
  kind : String,
  message_profile? : String = @runtime.CATALOG_PROFILE,
) -> Result[LocaleMigrationArtifacts, String] {
  if @utf8.encode(input_source).length() > XLIFF_MAX_SOURCE_BYTES {
    return Err("\{kind} input exceeds the input size limit")
  }
  let schema = match parse_schema(schema_source) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let locale = match normalize_locale(locale_code, "migration locale") {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let json = try @json.parse(input_source, max_nesting_depth=64) catch {
    _ => return Err("invalid \{kind} JSON")
  } noraise {
    value => value
  }
  guard json is Object(root) else {
    return Err("\{kind} root must be an object")
  }
  let notices : Array[InterchangeNotice] = []
  let values : Array[(String, Json)] = []
  if kind == "i18next" {
    match flatten_i18next(root, "", 0, values, notices) {
      Ok(_) => ()
      Err(message) => return Err(message)
    }
  } else {
    match root.get("@@locale") {
      Some(String(value)) =>
        match normalize_locale(value, "ARB @@locale") {
          Ok(value) if value == locale => ()
          Ok(value) =>
            return Err("ARB locale mismatch: expected \{locale}, got \{value}")
          Err(message) => return Err(message)
        }
      Some(_) => return Err("ARB @@locale must be a string")
      None => ()
    }
    for key, value in root {
      if key == "@@locale" {
        continue
      }
      values.push((key, value))
    }
  }
  values.sort_by((left, right) => left.0.lexical_compare(right.0))
  let translated : Array[(String, String)] = []
  let seen_ids : Map[String, Bool] = Map([])
  let arb_keys : Map[String, String] = Map([])
  if kind == "arb" {
    for entry in schema.entries {
      match arb_keys.get(entry.key) {
        Some(_) => arb_keys[entry.key] = ""
        None => arb_keys[entry.key] = message_id(entry)
      }
    }
  }
  for pair in values {
    let (key, value) = pair
    if kind == "arb" && key.has_prefix("@") {
      record_arb_metadata_notices(key, value, notices)
      continue
    }
    let id = match resolve_migration_id(schema, key, kind, arb_keys) {
      Some(value) => value
      None => {
        let suffix_kind = if kind == "i18next" && is_i18next_variant(key) {
          "i18next plural or context variant"
        } else {
          "unknown message"
        }
        notices.push(
          notice(
            "I18N_MIGRATION_MESSAGE_DISCARDED",
            "warning",
            key,
            "message",
            "discarded \{suffix_kind}: \{key}",
            true,
          ),
        )
        continue
      }
    }
    if seen_ids.contains(id) {
      notices.push(
        notice(
          "I18N_MIGRATION_ID_COLLISION",
          "warning",
          id,
          "identity",
          "discarded duplicate input mapping for canonical message: \{id}",
          true,
        ),
      )
      continue
    }
    guard value is String(raw_message) else {
      notices.push(
        notice(
          "I18N_MIGRATION_VALUE_DISCARDED",
          "warning",
          id,
          "message",
          "discarded non-string message value: \{key}",
          true,
        ),
      )
      continue
    }
    let entry = find_entry_by_id(schema.entries, id).unwrap()
    let converted = if kind == "i18next" {
      convert_i18next_placeholders(raw_message, entry, notices)
    } else {
      convert_arb_placeholders(raw_message, entry, notices)
    }
    match converted {
      Ok(message) =>
        match
          validate_migrated_message(schema, entry, message, message_profile~) {
          Ok(_) => {
            translated.push((id, message))
            seen_ids[id] = true
          }
          Err(error) =>
            notices.push(
              notice(
                "I18N_MIGRATION_MF2_DISCARDED",
                "warning",
                id,
                "message",
                "discarded message which cannot be represented by the active MF2 profile: \{error}",
                true,
              ),
            )
        }
      Err(message) =>
        notices.push(
          notice(
            "I18N_MIGRATION_SYNTAX_DISCARDED", "warning", id, "message", message,
            true,
          ),
        )
    }
  }
  let locale_source = locale_json(schema, translated)
  match parse_locale(locale, locale_source, schema, message_profile~) {
    Ok(_) => ()
    Err(message) => return Err("invalid generated migration output: \{message}")
  }
  Ok({
    locale_source,
    report: interchange_report_json(
      "\{kind}-import",
      "",
      locale,
      values.length(),
      translated.length(),
      0,
      0,
      notices,
    ),
  })
}

///|
fn parse_xliff_exchange(
  source : String,
  expected_source_locale : String,
  expected_target_locale : String,
  schema : Schema,
  source_locale : LocaleResource,
  migrations : IdMigrations,
) -> Result[ParsedXliff, String] {
  let reader = @xml.NamespaceReader::from_string(source)
  let units : Array[ExchangeUnit] = []
  let notices : Array[InterchangeNotice] = []
  let seen_ids : Map[String, Bool] = Map([])
  let stack : Array[String] = []
  let content = StringBuilder::new()
  let mut capture = 0
  let mut root_seen = false
  let mut file_seen = false
  let mut file_id = ""
  let mut file_original = ""
  let mut raw_id = ""
  let mut current_id = ""
  let mut removed = false
  let mut current_source = ""
  let mut current_target = ""
  let mut current_state = ""
  let mut current_sub_state = ""
  let mut current_unit_name = ""
  let mut current_translate = ""
  let mut current_can_resegment = ""
  let mut current_segment_id = ""
  let mut current_source_space = ""
  let mut current_target_space = ""
  let current_notes : Array[ExchangeNote] = []
  let mut note_id = ""
  let mut note_category = ""
  let mut note_applies_to = ""
  let mut note_priority = ""
  let mut source_seen = false
  let mut target_seen = false
  let mut segment_seen = false
  let mut renamed_units = 0
  let mut removed_units = 0
  while true {
    let event = try reader.read_event() catch {
      error => return Err("invalid XLIFF XML: \{error}")
    } noraise {
      value => value
    }
    match event.kind {
      @xml.Start(element) => {
        match validate_xliff_element(element) {
          Ok(_) => ()
          Err(message) => return Err(message)
        }
        if stack.length() >= XLIFF_MAX_DEPTH {
          return Err("XLIFF exceeds the element nesting limit")
        }
        let name = element.name.local_name
        if capture != 0 {
          return Err(
            "XLIFF source, target, and note must contain text-only data",
          )
        }
        match name {
          "xliff" => {
            if root_seen || !stack.is_empty() {
              return Err("XLIFF must contain exactly one xliff root")
            }
            root_seen = true
            match require_xliff_attribute(element, "version") {
              Some("2.1") => ()
              Some(value) => return Err("unsupported XLIFF version: \{value}")
              None => return Err("XLIFF root is missing version")
            }
            let declared_source = match
              require_xliff_attribute(element, "srcLang") {
              Some(value) =>
                match normalize_locale(value, "XLIFF srcLang") {
                  Ok(code) => code
                  Err(message) => return Err(message)
                }
              None => return Err("XLIFF root is missing srcLang")
            }
            if declared_source != expected_source_locale {
              return Err(
                "XLIFF source locale mismatch: expected \{expected_source_locale}, got \{declared_source}",
              )
            }
            let declared_target = match
              require_xliff_attribute(element, "trgLang") {
              Some(value) =>
                match normalize_locale(value, "XLIFF trgLang") {
                  Ok(code) => code
                  Err(message) => return Err(message)
                }
              None => return Err("XLIFF root is missing trgLang")
            }
            if declared_target != expected_target_locale {
              return Err(
                "XLIFF target locale mismatch: expected \{expected_target_locale}, got \{declared_target}",
              )
            }
            record_discarded_attributes(
              element,
              ["version", "srcLang", "trgLang"],
              "",
              notices,
            )
          }
          "file" => {
            if stack != ["xliff"] || file_seen {
              return Err("XLIFF profile requires one file under xliff")
            }
            file_id = match require_xliff_attribute(element, "id") {
              Some(value) => value
              None => return Err("XLIFF file is missing id")
            }
            file_original = require_xliff_attribute(element, "original").unwrap_or(
              "",
            )
            file_seen = true
            record_discarded_attributes(
              element,
              ["id", "original"],
              "",
              notices,
            )
          }
          "unit" => {
            if stack.is_empty() || stack[stack.length() - 1] != "file" {
              return Err("XLIFF unit must be a child of file")
            }
            if units.length() + removed_units >= XLIFF_MAX_UNITS {
              return Err("XLIFF exceeds the translation-unit limit")
            }
            raw_id = match require_xliff_attribute(element, "id") {
              Some(value) => value
              None => return Err("XLIFF unit is missing id")
            }
            let resolved = resolve_xliff_id(raw_id, schema, migrations)
            match resolved {
              Ok(Some(id)) => {
                current_id = id
                removed = false
                if id != raw_id {
                  renamed_units = renamed_units + 1
                  notices.push(
                    notice(
                      "I18N_XLIFF_ID_RENAMED",
                      "info",
                      id,
                      "identity",
                      "mapped XLIFF unit \{raw_id} to \{id}",
                      false,
                    ),
                  )
                }
                if seen_ids.contains(id) {
                  return Err("duplicate XLIFF unit id after migration: \{id}")
                }
                seen_ids[id] = true
              }
              Ok(None) => {
                current_id = ""
                removed = true
              }
              Err(message) => return Err(message)
            }
            current_source = ""
            current_target = ""
            current_state = ""
            current_sub_state = ""
            current_unit_name = require_xliff_attribute(element, "name").unwrap_or(
              "",
            )
            current_translate = require_xliff_attribute(element, "translate").unwrap_or(
              "",
            )
            current_can_resegment = require_xliff_attribute(
              element, "canResegment",
            ).unwrap_or("")
            match validate_yes_no(current_translate, "unit translate", raw_id) {
              Ok(_) => ()
              Err(message) => return Err(message)
            }
            match
              validate_yes_no(
                current_can_resegment, "unit canResegment", raw_id,
              ) {
              Ok(_) => ()
              Err(message) => return Err(message)
            }
            current_segment_id = ""
            current_source_space = ""
            current_target_space = ""
            current_notes.clear()
            source_seen = false
            target_seen = false
            segment_seen = false
            record_discarded_attributes(
              element,
              ["id", "name", "translate", "canResegment"],
              raw_id,
              notices,
            )
          }
          "notes" =>
            if raw_id.is_empty() ||
              stack.is_empty() ||
              stack[stack.length() - 1] != "unit" {
              return Err("XLIFF notes must be inside a unit")
            }
          "note" => {
            if raw_id.is_empty() ||
              stack.is_empty() ||
              stack[stack.length() - 1] != "notes" {
              return Err("XLIFF note must be inside notes")
            }
            if current_notes.length() >= XLIFF_MAX_NOTES_PER_UNIT {
              return Err(
                "XLIFF unit exceeds the translator-note limit: \{raw_id}",
              )
            }
            note_id = require_xliff_attribute(element, "id").unwrap_or("")
            note_category = require_xliff_attribute(element, "category").unwrap_or(
              "",
            )
            note_applies_to = require_xliff_attribute(element, "appliesTo").unwrap_or(
              "",
            )
            note_priority = require_xliff_attribute(element, "priority").unwrap_or(
              "",
            )
            match
              validate_note_metadata(note_applies_to, note_priority, raw_id) {
              Ok(_) => ()
              Err(message) => return Err(message)
            }
            record_discarded_attributes(
              element,
              ["id", "category", "appliesTo", "priority"],
              raw_id,
              notices,
            )
            capture = 3
            content.reset()
          }
          "segment" => {
            if raw_id.is_empty() ||
              segment_seen ||
              stack.is_empty() ||
              stack[stack.length() - 1] != "unit" {
              return Err("XLIFF profile requires exactly one segment per unit")
            }
            segment_seen = true
            current_segment_id = require_xliff_attribute(element, "id").unwrap_or(
              "",
            )
            current_state = require_xliff_attribute(element, "state").unwrap_or(
              "",
            )
            current_sub_state = require_xliff_attribute(element, "subState").unwrap_or(
              "",
            )
            if current_sub_state.contains(":") {
              notices.push(
                notice(
                  "I18N_XLIFF_METADATA_DISCARDED", "warning", raw_id, "segment@subState",
                  "discarded namespace-qualified XLIFF subState because extension namespace declarations are not retained",
                  true,
                ),
              )
              current_sub_state = ""
            }
            match validate_translation_state(current_state, raw_id) {
              Ok(_) => ()
              Err(message) => return Err(message)
            }
            record_discarded_attributes(
              element,
              ["id", "state", "subState"],
              raw_id,
              notices,
            )
          }
          "source" => {
            if raw_id.is_empty() ||
              source_seen ||
              stack.is_empty() ||
              stack[stack.length() - 1] != "segment" {
              return Err("invalid or duplicate XLIFF source")
            }
            source_seen = true
            match invalid_xml_space_attribute(element) {
              Some(value) =>
                return Err("invalid xml:space value for \{raw_id}: \{value}")
              None => ()
            }
            current_source_space = xml_space_attribute(element).unwrap_or("")
            record_discarded_attributes(
              element,
              [],
              raw_id,
              notices,
              allow_xml_space=true,
            )
            capture = 1
            content.reset()
          }
          "target" => {
            if raw_id.is_empty() ||
              target_seen ||
              stack.is_empty() ||
              stack[stack.length() - 1] != "segment" {
              return Err("invalid or duplicate XLIFF target")
            }
            target_seen = true
            match invalid_xml_space_attribute(element) {
              Some(value) =>
                return Err("invalid xml:space value for \{raw_id}: \{value}")
              None => ()
            }
            current_target_space = xml_space_attribute(element).unwrap_or("")
            let legacy_state = require_xliff_attribute(element, "state").unwrap_or(
              "",
            )
            if current_state.is_empty() && !legacy_state.is_empty() {
              current_state = legacy_state
              notices.push(
                notice(
                  "I18N_XLIFF_LEGACY_TARGET_STATE", "warning", raw_id, "target@state",
                  "normalized legacy target@state to XLIFF 2.1 segment@state", false,
                ),
              )
            }
            match validate_translation_state(current_state, raw_id) {
              Ok(_) => ()
              Err(message) => return Err(message)
            }
            record_discarded_attributes(
              element,
              ["state"],
              raw_id,
              notices,
              allow_xml_space=true,
            )
            capture = 2
            content.reset()
          }
          _ =>
            return Err(
              "element is outside the supported XLIFF profile: \{name}",
            )
        }
        record_discarded_namespaces(element, raw_id, notices)
        stack.push(name)
      }
      @xml.Empty(element) => {
        match validate_xliff_element(element) {
          Ok(_) => ()
          Err(message) => return Err(message)
        }
        let name = element.name.local_name
        if name == "source" {
          if raw_id.is_empty() ||
            source_seen ||
            stack.is_empty() ||
            stack[stack.length() - 1] != "segment" {
            return Err("invalid or duplicate XLIFF source")
          }
          source_seen = true
          current_source = ""
          match invalid_xml_space_attribute(element) {
            Some(value) =>
              return Err("invalid xml:space value for \{raw_id}: \{value}")
            None => ()
          }
          current_source_space = xml_space_attribute(element).unwrap_or("")
          record_discarded_attributes(
            element,
            [],
            raw_id,
            notices,
            allow_xml_space=true,
          )
        } else if name == "target" {
          if raw_id.is_empty() ||
            target_seen ||
            stack.is_empty() ||
            stack[stack.length() - 1] != "segment" {
            return Err("invalid or duplicate XLIFF target")
          }
          target_seen = true
          current_target = ""
          match invalid_xml_space_attribute(element) {
            Some(value) =>
              return Err("invalid xml:space value for \{raw_id}: \{value}")
            None => ()
          }
          current_target_space = xml_space_attribute(element).unwrap_or("")
          let legacy_state = require_xliff_attribute(element, "state").unwrap_or(
            "",
          )
          if current_state.is_empty() {
            current_state = legacy_state
          }
          match validate_translation_state(current_state, raw_id) {
            Ok(_) => ()
            Err(message) => return Err(message)
          }
          record_discarded_attributes(
            element,
            ["state"],
            raw_id,
            notices,
            allow_xml_space=true,
          )
        } else if name == "note" {
          if raw_id.is_empty() ||
            stack.is_empty() ||
            stack[stack.length() - 1] != "notes" {
            return Err("XLIFF note must be inside notes")
          }
          if current_notes.length() >= XLIFF_MAX_NOTES_PER_UNIT {
            return Err(
              "XLIFF unit exceeds the translator-note limit: \{raw_id}",
            )
          }
          let empty_note : ExchangeNote = {
            text: "",
            id: require_xliff_attribute(element, "id").unwrap_or(""),
            category: require_xliff_attribute(element, "category").unwrap_or(""),
            applies_to: require_xliff_attribute(element, "appliesTo").unwrap_or(
              "",
            ),
            priority: require_xliff_attribute(element, "priority").unwrap_or(""),
          }
          match
            validate_note_metadata(
              empty_note.applies_to,
              empty_note.priority,
              raw_id,
            ) {
            Ok(_) => ()
            Err(message) => return Err(message)
          }
          current_notes.push(empty_note)
          record_discarded_attributes(
            element,
            ["id", "category", "appliesTo", "priority"],
            raw_id,
            notices,
          )
        } else {
          return Err(
            "empty element is outside the supported XLIFF profile: \{name}",
          )
        }
        record_discarded_namespaces(element, raw_id, notices)
      }
      @xml.End(name) => {
        match name.local_name {
          "source" => {
            current_source = content.to_string()
            content.reset()
            capture = 0
          }
          "target" => {
            current_target = content.to_string()
            content.reset()
            capture = 0
          }
          "note" => {
            current_notes.push({
              text: content.to_string(),
              id: note_id,
              category: note_category,
              applies_to: note_applies_to,
              priority: note_priority,
            })
            content.reset()
            capture = 0
          }
          "unit" => {
            if !segment_seen || !source_seen || !target_seen {
              return Err(
                "XLIFF unit is missing segment, source, or target: \{raw_id}",
              )
            }
            if current_state.is_empty() {
              current_state = if current_target.trim().is_empty() {
                "initial"
              } else {
                "translated"
              }
              notices.push(
                notice(
                  "I18N_XLIFF_STATE_INFERRED",
                  "info",
                  raw_id,
                  "segment@state",
                  "inferred missing translation state as \{current_state}",
                  false,
                ),
              )
            }
            if removed {
              removed_units = removed_units + 1
              notices.push(
                notice(
                  "I18N_XLIFF_ID_REMOVED",
                  "warning",
                  raw_id,
                  "identity",
                  "discarded explicitly removed XLIFF unit: \{raw_id}",
                  true,
                ),
              )
            } else {
              let expected = match source_message(source_locale, current_id) {
                Some(value) => value
                None => return Err("missing source message: \{current_id}")
              }
              if current_source != expected {
                return Err("stale XLIFF source for unit: \{raw_id}")
              }
              units.push({
                id: current_id,
                source: current_source,
                target: current_target,
                state: current_state,
                sub_state: current_sub_state,
                unit_name: current_unit_name,
                translate: current_translate,
                can_resegment: current_can_resegment,
                segment_id: current_segment_id,
                source_space: current_source_space,
                target_space: current_target_space,
                notes: current_notes.copy(),
              })
            }
            raw_id = ""
            current_id = ""
          }
          _ => ()
        }
        ignore(stack.pop())
      }
      @xml.Text(value) | @xml.CData(value) =>
        if capture != 0 {
          content.write_string(value)
        } else if !value.trim().is_empty() {
          return Err("text is outside an XLIFF source, target, or note")
        }
      @xml.Comment(_) =>
        notices.push(
          notice(
            "I18N_XLIFF_METADATA_DISCARDED", "warning", raw_id, "comment", "discarded XML comment",
            true,
          ),
        )
      @xml.PI(target~, data=_) =>
        notices.push(
          notice(
            "I18N_XLIFF_METADATA_DISCARDED",
            "warning",
            raw_id,
            "processing-instruction",
            "discarded XML processing instruction: \{target}",
            true,
          ),
        )
      @xml.DocType(_) => return Err("DOCTYPE is not allowed in XLIFF")
      @xml.Eof => break
      @xml.Decl(..) => ()
    }
  }
  if !root_seen || !file_seen {
    return Err("XLIFF document is missing the required root or file")
  }
  if units.is_empty() && removed_units == 0 {
    return Err("XLIFF contains no translation units")
  }
  Ok({
    state: {
      source_locale: expected_source_locale,
      target_locale: expected_target_locale,
      file_id,
      file_original,
      units,
    },
    notices,
    renamed_units,
    removed_units,
  })
}

///|
#warnings("-deprecated")
fn parse_exchange_state(
  source : String,
  schema : Schema,
  source_locale : LocaleResource,
  target_locale : String,
) -> Result[ExchangeState, String] {
  if @utf8.encode(source).length() > XLIFF_MAX_SOURCE_BYTES {
    return Err("XLIFF exchange state exceeds the input size limit")
  }
  let json = try @json.parse(source, max_nesting_depth=32) catch {
    _ => return Err("invalid XLIFF exchange-state JSON")
  } noraise {
    value => value
  }
  guard json is Object(root) else {
    return Err("XLIFF exchange-state root must be an object")
  }
  match root.get("stateVersion") {
    Some(Number(value, ..)) if value == XLIFF_EXCHANGE_STATE_VERSION.to_double() =>
      ()
    _ => return Err("unsupported XLIFF exchange-state version")
  }
  let declared_source = match root.get("sourceLocale") {
    Some(String(value)) => value
    _ => return Err("XLIFF exchange state is missing sourceLocale")
  }
  if declared_source != source_locale.locale {
    return Err("XLIFF exchange-state source locale mismatch")
  }
  let declared_target = match root.get("targetLocale") {
    Some(String(value)) => value
    _ => return Err("XLIFF exchange state is missing targetLocale")
  }
  if declared_target != target_locale {
    return Err("XLIFF exchange-state target locale mismatch")
  }
  let file_id = json_optional_string(root, "fileId").unwrap_or("messages")
  let file_original = json_optional_string(root, "fileOriginal").unwrap_or("")
  let units : Array[ExchangeUnit] = []
  let seen : Map[String, Bool] = Map([])
  guard root.get("units") is Some(Array(raw_units)) else {
    return Err("XLIFF exchange state units must be an array")
  }
  if raw_units.length() > XLIFF_MAX_UNITS {
    return Err("XLIFF exchange state exceeds the translation-unit limit")
  }
  for raw_unit in raw_units {
    guard raw_unit is Object(obj) else {
      return Err("XLIFF exchange-state unit must be an object")
    }
    let id = match obj.get("id") {
      Some(String(value)) => value
      _ => return Err("XLIFF exchange-state unit is missing id")
    }
    if find_entry_by_id(schema.entries, id) is None {
      return Err(
        "XLIFF exchange state references removed or unknown unit: \{id}",
      )
    }
    if seen.contains(id) {
      return Err("duplicate XLIFF exchange-state unit: \{id}")
    }
    seen[id] = true
    let unit_source = match obj.get("source") {
      Some(String(value)) => value
      _ => return Err("XLIFF exchange-state unit is missing source: \{id}")
    }
    let digest = match obj.get("sourceSha256") {
      Some(String(value)) => value
      _ =>
        return Err("XLIFF exchange-state unit is missing sourceSha256: \{id}")
    }
    let expected = source_message(source_locale, id).unwrap_or("")
    if unit_source != expected || digest != source_digest(expected) {
      return Err("stale XLIFF exchange state source for unit: \{id}")
    }
    let state = json_optional_string(obj, "state").unwrap_or("initial")
    match validate_translation_state(state, id) {
      Ok(_) => ()
      Err(message) => return Err(message)
    }
    let notes : Array[ExchangeNote] = []
    match obj.get("notes") {
      Some(Array(raw_notes)) => {
        if raw_notes.length() > XLIFF_MAX_NOTES_PER_UNIT {
          return Err(
            "XLIFF exchange-state unit exceeds the translator-note limit: \{id}",
          )
        }
        for raw_note in raw_notes {
          guard raw_note is Object(note) else {
            return Err("XLIFF exchange-state note must be an object: \{id}")
          }
          let text = match note.get("text") {
            Some(String(value)) => value
            _ => return Err("XLIFF exchange-state note is missing text: \{id}")
          }
          let parsed_note : ExchangeNote = {
            text,
            id: json_optional_string(note, "id").unwrap_or(""),
            category: json_optional_string(note, "category").unwrap_or(""),
            applies_to: json_optional_string(note, "appliesTo").unwrap_or(""),
            priority: json_optional_string(note, "priority").unwrap_or(""),
          }
          match
            validate_note_metadata(
              parsed_note.applies_to,
              parsed_note.priority,
              id,
            ) {
            Ok(_) => ()
            Err(message) => return Err(message)
          }
          notes.push(parsed_note)
        }
      }
      None => ()
      _ => return Err("XLIFF exchange-state notes must be an array: \{id}")
    }
    let parsed : ExchangeUnit = {
      id,
      source: unit_source,
      target: json_optional_string(obj, "target").unwrap_or(""),
      state,
      sub_state: json_optional_string(obj, "subState").unwrap_or(""),
      unit_name: json_optional_string(obj, "unitName").unwrap_or(""),
      translate: json_optional_string(obj, "translate").unwrap_or(""),
      can_resegment: json_optional_string(obj, "canResegment").unwrap_or(""),
      segment_id: json_optional_string(obj, "segmentId").unwrap_or(""),
      source_space: json_optional_string(obj, "sourceSpace").unwrap_or(""),
      target_space: json_optional_string(obj, "targetSpace").unwrap_or(""),
      notes,
    }
    match validate_yes_no(parsed.translate, "unit translate", id) {
      Ok(_) => ()
      Err(message) => return Err(message)
    }
    match validate_yes_no(parsed.can_resegment, "unit canResegment", id) {
      Ok(_) => ()
      Err(message) => return Err(message)
    }
    units.push(parsed)
  }
  Ok({
    source_locale: declared_source,
    target_locale: declared_target,
    file_id,
    file_original,
    units,
  })
}

///|
fn exchange_state_json(state : ExchangeState) -> String {
  let units : Array[Json] = []
  for unit in state.units {
    let obj : Map[String, Json] = Map([])
    obj["id"] = Json::string(unit.id)
    obj["source"] = Json::string(unit.source)
    obj["sourceSha256"] = Json::string(source_digest(unit.source))
    obj["target"] = Json::string(unit.target)
    obj["state"] = Json::string(unit.state)
    put_json_string(obj, "subState", unit.sub_state)
    put_json_string(obj, "unitName", unit.unit_name)
    put_json_string(obj, "translate", unit.translate)
    put_json_string(obj, "canResegment", unit.can_resegment)
    put_json_string(obj, "segmentId", unit.segment_id)
    put_json_string(obj, "sourceSpace", unit.source_space)
    put_json_string(obj, "targetSpace", unit.target_space)
    let notes : Array[Json] = []
    for note in unit.notes {
      let note_obj : Map[String, Json] = Map([])
      note_obj["text"] = Json::string(note.text)
      put_json_string(note_obj, "id", note.id)
      put_json_string(note_obj, "category", note.category)
      put_json_string(note_obj, "appliesTo", note.applies_to)
      put_json_string(note_obj, "priority", note.priority)
      notes.push(Json::object(note_obj))
    }
    obj["notes"] = Json::array(notes)
    units.push(Json::object(obj))
  }
  let root : Map[String, Json] = Map([])
  root["stateVersion"] = Json::number(XLIFF_EXCHANGE_STATE_VERSION.to_double())
  root["profile"] = Json::string("xliff-2.1-lampclaw-v1")
  root["sourceLocale"] = Json::string(state.source_locale)
  root["targetLocale"] = Json::string(state.target_locale)
  root["fileId"] = Json::string(state.file_id)
  put_json_string(root, "fileOriginal", state.file_original)
  root["units"] = Json::array(units)
  Json::object(root).stringify(indent=2) + "\n"
}

///|
fn interchange_report_json(
  kind : String,
  source_locale : String,
  target_locale : String,
  input_units : Int,
  imported_units : Int,
  renamed_units : Int,
  removed_units : Int,
  notices : Array[InterchangeNotice],
) -> String {
  let entries : Array[Json] = []
  let mut loss_count = 0
  for item in notices {
    if item.loss {
      loss_count = loss_count + 1
    }
    let obj : Map[String, Json] = Map([])
    obj["code"] = Json::string(item.code)
    obj["severity"] = Json::string(item.severity)
    put_json_string(obj, "id", item.id)
    obj["field"] = Json::string(item.field)
    obj["message"] = Json::string(item.message)
    obj["loss"] = Json::boolean(item.loss)
    entries.push(Json::object(obj))
  }
  let root : Map[String, Json] = Map([])
  root["reportVersion"] = Json::number(INTERCHANGE_REPORT_VERSION.to_double())
  root["kind"] = Json::string(kind)
  put_json_string(root, "sourceLocale", source_locale)
  root["targetLocale"] = Json::string(target_locale)
  root["inputUnits"] = Json::number(input_units.to_double())
  root["importedUnits"] = Json::number(imported_units.to_double())
  root["renamedUnits"] = Json::number(renamed_units.to_double())
  root["removedUnits"] = Json::number(removed_units.to_double())
  root["lossCount"] = Json::number(loss_count.to_double())
  root["entries"] = Json::array(entries)
  Json::object(root).stringify(indent=2) + "\n"
}

///|
#warnings("-deprecated")
fn parse_id_migrations(
  source : String,
  schema : Schema,
) -> Result[IdMigrations, String] {
  if @utf8.encode(source).length() > @runtime.CATALOG_MAX_SOURCE_BYTES {
    return Err("XLIFF ID migration map exceeds the input size limit")
  }
  let json = try @json.parse(source, max_nesting_depth=16) catch {
    _ => return Err("invalid XLIFF ID migration JSON")
  } noraise {
    value => value
  }
  guard json is Object(root) else {
    return Err("XLIFF ID migration root must be an object")
  }
  match root.get("version") {
    Some(Number(value, ..)) if value == 1.0 => ()
    _ => return Err("unsupported XLIFF ID migration version")
  }
  let renames : Array[(String, String)] = []
  let seen_old : Map[String, Bool] = Map([])
  let seen_new : Map[String, Bool] = Map([])
  match root.get("renames") {
    Some(Object(values)) =>
      for old_id, raw_new_id in values {
        guard raw_new_id is String(new_id) else {
          return Err("XLIFF rename target must be a string: \{old_id}")
        }
        if old_id == new_id {
          return Err("XLIFF rename must change the unit id: \{old_id}")
        }
        if find_entry_by_id(schema.entries, old_id) is Some(_) {
          return Err(
            "XLIFF rename source is still a current schema id: \{old_id}",
          )
        }
        if find_entry_by_id(schema.entries, new_id) is None {
          return Err(
            "XLIFF rename target is not a current schema id: \{new_id}",
          )
        }
        if seen_old.contains(old_id) || seen_new.contains(new_id) {
          return Err(
            "duplicate or colliding XLIFF rename: \{old_id} -> \{new_id}",
          )
        }
        seen_old[old_id] = true
        seen_new[new_id] = true
        renames.push((old_id, new_id))
      }
    None => ()
    _ => return Err("XLIFF ID migration renames must be an object")
  }
  renames.sort_by((left, right) => left.0.lexical_compare(right.0))
  let removed : Array[String] = []
  match root.get("removed") {
    Some(Array(values)) =>
      for raw in values {
        guard raw is String(id) else {
          return Err("XLIFF removed IDs must be strings")
        }
        if seen_old.contains(id) || removed.contains(id) {
          return Err(
            "XLIFF ID cannot be renamed and removed or repeated: \{id}",
          )
        }
        if find_entry_by_id(schema.entries, id) is Some(_) {
          return Err("current schema ID cannot be marked removed: \{id}")
        }
        removed.push(id)
      }
    None => ()
    _ => return Err("XLIFF ID migration removed must be an array")
  }
  removed.sort_by((left, right) => left.lexical_compare(right))
  Ok({ renames, removed })
}

///|
fn resolve_xliff_id(
  id : String,
  schema : Schema,
  migrations : IdMigrations,
) -> Result[String?, String] {
  if find_entry_by_id(schema.entries, id) is Some(_) {
    return Ok(Some(id))
  }
  let mut low = 0
  let mut high = migrations.renames.length()
  while low < high {
    let middle = low + (high - low) / 2
    if migrations.renames[middle].0.lexical_compare(id) < 0 {
      low = middle + 1
    } else {
      high = middle
    }
  }
  if low < migrations.renames.length() && migrations.renames[low].0 == id {
    return Ok(Some(migrations.renames[low].1))
  }
  if sorted_strings_contains(migrations.removed, id) {
    return Ok(None)
  }
  Err("unknown XLIFF unit id without an explicit migration: \{id}")
}

///|
fn flatten_i18next(
  object : Map[String, Json],
  prefix : String,
  depth : Int,
  values : Array[(String, Json)],
  notices : Array[InterchangeNotice],
) -> Result[Unit, String] {
  if depth > XLIFF_MAX_DEPTH {
    return Err("i18next input exceeds the object nesting limit")
  }
  for key, value in object {
    let path = if prefix.is_empty() { key } else { "\{prefix}.\{key}" }
    match value {
      Object(child) =>
        match flatten_i18next(child, path, depth + 1, values, notices) {
          Ok(_) => ()
          Err(message) => return Err(message)
        }
      String(_) => values.push((path, value))
      _ => {
        values.push((path, value))
        notices.push(
          notice(
            "I18N_MIGRATION_NON_STRING", "warning", path, "message", "encountered a non-string i18next value",
            false,
          ),
        )
      }
    }
    if values.length() > XLIFF_MAX_UNITS {
      return Err("i18next input exceeds the message limit")
    }
  }
  Ok(())
}

///|
fn resolve_migration_id(
  schema : Schema,
  input_id : String,
  kind : String,
  arb_keys : Map[String, String],
) -> String? {
  if find_entry_by_id(schema.entries, input_id) is Some(_) {
    return Some(input_id)
  }
  if kind == "arb" {
    match arb_keys.get(input_id) {
      Some(id) if !id.is_empty() => return Some(id)
      _ => ()
    }
  }
  None
}

///|
fn validate_migrated_message(
  schema : Schema,
  entry : Entry,
  message : String,
  message_profile? : String = @runtime.CATALOG_PROFILE,
) -> Result[Unit, String] {
  if message_profile == @runtime.CATALOG_PROFILE {
    let params = entry.params.map(param => @runtime.MessageParamSpec::{
      name: param.name,
      typ: param.typ,
    })
    let contract = @runtime.MessageContract::new(
      params,
      allowed_tags=schema_allowed_tags(schema, message_id(entry)),
    )
    match @runtime.compile_mf2_message(message, contract) {
      Ok(_) => Ok(())
      Err(errors) => Err(errors[0].message)
    }
  } else if is_standard_authoring_profile(message_profile) {
    let model = match @runtime.parse_valid_mf2_model(message) {
      Ok(value) => value
      Err(errors) => return Err(errors[0].message)
    }
    validate_standard_message_contract(model, schema, entry, message_profile)
  } else {
    Err("unsupported messageProfile: \{message_profile}")
  }
}

///|
fn sorted_strings_contains(values : Array[String], needle : String) -> Bool {
  let mut low = 0
  let mut high = values.length()
  while low < high {
    let middle = low + (high - low) / 2
    if values[middle].lexical_compare(needle) < 0 {
      low = middle + 1
    } else {
      high = middle
    }
  }
  low < values.length() && values[low] == needle
}

///|
fn is_i18next_variant(id : String) -> Bool {
  for
    suffix in [
      "_zero", "_one", "_two", "_few", "_many", "_other", "_male", "_female",
    ] {
    if id.has_suffix(suffix) {
      return true
    }
  }
  false
}

///|
fn convert_i18next_placeholders(
  source : String,
  entry : Entry,
  notices : Array[InterchangeNotice],
) -> Result[String, String] {
  let chars = source.to_array()
  let out = StringBuilder::new()
  let mut cursor = 0
  while cursor < chars.length() {
    if cursor + 1 < chars.length() &&
      chars[cursor] == '{' &&
      chars[cursor + 1] == '{' {
      let close = find_double_close(chars, cursor + 2)
      guard close is Some(end) else {
        return Err(
          "discarded unterminated i18next interpolation in \{message_id(entry)}",
        )
      }
      let mut body = chars_to_string(chars, cursor + 2, end).trim().to_owned()
      let mut unescaped = false
      if body.has_prefix("-") {
        unescaped = true
        body = body[1:].to_owned().trim().to_owned()
      }
      if body.find(",") is Some(_) {
        return Err(
          "discarded formatted i18next interpolation which has no deterministic MF2 mapping: \{message_id(entry)}",
        )
      }
      if !entry_has_param(entry, body) {
        return Err(
          "discarded unknown i18next interpolation parameter \{body}: \{message_id(entry)}",
        )
      }
      if unescaped {
        notices.push(
          notice(
            "I18N_MIGRATION_ESCAPING_SEMANTICS",
            "warning",
            message_id(entry),
            "interpolation",
            "i18next unescaped interpolation was converted to a typed MF2 variable; renderer escaping remains application-owned",
            true,
          ),
        )
      }
      out.write_string("{$\{body}}")
      cursor = end + 2
    } else {
      out.write_char(chars[cursor])
      cursor = cursor + 1
    }
  }
  Ok(out.to_string())
}

///|
fn convert_arb_placeholders(
  source : String,
  entry : Entry,
  notices : Array[InterchangeNotice],
) -> Result[String, String] {
  let chars = source.to_array()
  let out = StringBuilder::new()
  let mut cursor = 0
  while cursor < chars.length() {
    if chars[cursor] == '{' {
      let close = find_single_close(chars, cursor + 1)
      guard close is Some(end) else {
        return Err(
          "discarded unterminated ARB placeholder in \{message_id(entry)}",
        )
      }
      let body = chars_to_string(chars, cursor + 1, end).trim().to_owned()
      if body.find(",") is Some(_) {
        return Err(
          "discarded ARB ICU plural/select syntax which requires an explicit MF2 migration: \{message_id(entry)}",
        )
      }
      if !entry_has_param(entry, body) {
        return Err(
          "discarded unknown ARB placeholder \{body}: \{message_id(entry)}",
        )
      }
      out.write_string("{$\{body}}")
      cursor = end + 1
    } else {
      out.write_char(chars[cursor])
      cursor = cursor + 1
    }
  }
  ignore(notices)
  Ok(out.to_string())
}

///|
fn record_arb_metadata_notices(
  key : String,
  value : Json,
  notices : Array[InterchangeNotice],
) -> Unit {
  match value {
    Object(metadata) =>
      for field, _ in metadata {
        notices.push(
          notice(
            "I18N_ARB_METADATA_DISCARDED",
            "warning",
            key[1:].to_owned(),
            "@metadata.\{field}",
            "discarded ARB metadata field which is not part of canonical locale JSON: \{field}",
            true,
          ),
        )
      }
    _ =>
      notices.push(
        notice(
          "I18N_ARB_METADATA_DISCARDED",
          "warning",
          key[1:].to_owned(),
          "@metadata",
          "discarded malformed ARB metadata value",
          true,
        ),
      )
  }
}

///|
fn find_double_close(chars : Array[Char], start : Int) -> Int? {
  let mut cursor = start
  while cursor + 1 < chars.length() {
    if chars[cursor] == '}' && chars[cursor + 1] == '}' {
      return Some(cursor)
    }
    cursor = cursor + 1
  }
  None
}

///|
fn find_single_close(chars : Array[Char], start : Int) -> Int? {
  let mut cursor = start
  while cursor < chars.length() {
    if chars[cursor] == '}' {
      return Some(cursor)
    }
    cursor = cursor + 1
  }
  None
}

///|
fn entry_has_param(entry : Entry, name : String) -> Bool {
  for param in entry.params {
    if param.name == name {
      return true
    }
  }
  false
}

///|
fn source_digest(source : String) -> String {
  @crypto.bytes_to_hex_string(@crypto.sha256(@utf8.encode(source)))
}

///|
fn notice(
  code : String,
  severity : String,
  id : String,
  field : String,
  message : String,
  loss : Bool,
) -> InterchangeNotice {
  { code, severity, id, field, message, loss }
}

///|
fn validate_translation_state(
  state : String,
  id : String,
) -> Result[Unit, String] {
  if state.is_empty() ||
    state == "initial" ||
    state == "translated" ||
    state == "reviewed" ||
    state == "final" {
    Ok(())
  } else {
    Err("unsupported XLIFF translation state for \{id}: \{state}")
  }
}

///|
fn validate_yes_no(
  value : String,
  field : String,
  id : String,
) -> Result[Unit, String] {
  if value.is_empty() || value == "yes" || value == "no" {
    Ok(())
  } else {
    Err("\{field} must be yes or no for \{id}")
  }
}

///|
fn validate_note_metadata(
  applies_to : String,
  priority : String,
  id : String,
) -> Result[Unit, String] {
  if !applies_to.is_empty() && applies_to != "source" && applies_to != "target" {
    return Err("XLIFF note appliesTo must be source or target for \{id}")
  }
  if !priority.is_empty() {
    guard ["1", "2", "3", "4", "5", "6", "7", "8", "9", "10"].contains(priority) else {
      return Err("XLIFF note priority must be between 1 and 10 for \{id}")
    }
  }
  Ok(())
}

///|
fn record_discarded_attributes(
  element : @xml.NamespaceElement,
  allowed : Array[String],
  id : String,
  notices : Array[InterchangeNotice],
  allow_xml_space? : Bool = false,
) -> Unit {
  for attribute in element.attributes {
    let plain_allowed = attribute.name.namespace_uri is None &&
      allowed.contains(attribute.name.local_name)
    let space_allowed = allow_xml_space &&
      attribute.name.namespace_uri == Some(XLIFF_XML_NAMESPACE) &&
      attribute.name.local_name == "space"
    if !plain_allowed && !space_allowed {
      notices.push(
        notice(
          "I18N_XLIFF_METADATA_DISCARDED",
          "warning",
          id,
          "\{element.name.local_name}@\{attribute.name.qualified_name}",
          "discarded unsupported XLIFF attribute: \{attribute.name.qualified_name}",
          true,
        ),
      )
    }
  }
}

///|
fn record_discarded_namespaces(
  element : @xml.NamespaceElement,
  id : String,
  notices : Array[InterchangeNotice],
) -> Unit {
  for declaration in element.namespace_declarations {
    if declaration.namespace_uri != XLIFF_NAMESPACE {
      notices.push(
        notice(
          "I18N_XLIFF_METADATA_DISCARDED",
          "warning",
          id,
          "namespace",
          "discarded extension namespace declaration: \{declaration.namespace_uri}",
          true,
        ),
      )
    }
  }
}

///|
fn xml_space_attribute(element : @xml.NamespaceElement) -> String? {
  for attribute in element.attributes {
    if attribute.name.namespace_uri == Some(XLIFF_XML_NAMESPACE) &&
      attribute.name.local_name == "space" {
      if attribute.value == "default" || attribute.value == "preserve" {
        return Some(attribute.value)
      }
      return None
    }
  }
  None
}

///|
fn invalid_xml_space_attribute(element : @xml.NamespaceElement) -> String? {
  for attribute in element.attributes {
    if attribute.name.namespace_uri == Some(XLIFF_XML_NAMESPACE) &&
      attribute.name.local_name == "space" &&
      attribute.value != "default" &&
      attribute.value != "preserve" {
      return Some(attribute.value)
    }
  }
  None
}

///|
fn has_description_note(
  notes : Array[ExchangeNote],
  description : String,
) -> Bool {
  for note in notes {
    if note.category == "description" && note.text == description {
      return true
    }
  }
  false
}

///|
fn push_xml_attribute(
  attributes : Array[(String, String)],
  name : String,
  value : String,
) -> Unit {
  if !value.is_empty() {
    attributes.push((name, value))
  }
}

///|
fn put_json_string(
  object : Map[String, Json],
  name : String,
  value : String,
) -> Unit {
  if !value.is_empty() {
    object[name] = Json::string(value)
  }
}

///|
fn json_optional_string(object : Map[String, Json], name : String) -> String? {
  match object.get(name) {
    Some(String(value)) => Some(value)
    _ => None
  }
}
