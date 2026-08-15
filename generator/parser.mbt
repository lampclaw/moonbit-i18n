///|
/// Parses and validates generator configuration JSON.
#warnings("-deprecated")
pub fn parse_config(source : String) -> Result[I18nConfig, String] {
  if @utf8.encode(source).length() > @runtime.CATALOG_MAX_SOURCE_BYTES {
    return Err("i18n config exceeds the input size limit")
  }
  let json = try @json.parse(source, max_nesting_depth=64) catch {
    _ => return Err("invalid i18n config JSON")
  } noraise {
    value => value
  }
  guard json is Object(obj) else {
    return Err("i18n config root must be an object")
  }
  let (message_profile, message_profile_explicit) = match
    obj.get("messageProfile") {
    Some(String(value)) if @runtime.is_supported_message_profile(value) =>
      (value, true)
    Some(String(value)) => return Err("unsupported messageProfile: \{value}")
    Some(_) => return Err("messageProfile must be a string")
    None =>
      return Err(
        "messageProfile is required; choose unicode-mf2-ldml48.2-js-v2, unicode-mf2-ldml48.2-js-v2+experimental-datetime-v1, or an explicit legacy profile",
      )
  }
  let source_locale = match normalized_config_string(obj, "sourceLocale") {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let default_locale = match normalized_config_string(obj, "defaultLocale") {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let fallback_locale = match normalized_config_string(obj, "fallbackLocale") {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let embedded_locales : Array[String] = []
  match obj.get("embeddedLocales") {
    Some(Array(values)) =>
      for value in values {
        guard value is String(code) else {
          return Err("embeddedLocales must contain strings")
        }
        let normalized = match normalize_locale(code, "embeddedLocales") {
          Ok(value) => value
          Err(message) => return Err(message)
        }
        if embedded_locales.contains(normalized) {
          return Err("duplicate embedded locale: \{normalized}")
        }
        embedded_locales.push(normalized)
      }
    _ => return Err("embeddedLocales must be an array")
  }
  let locales : Array[LocaleConfig] = []
  match obj.get("locales") {
    Some(Object(values)) =>
      for pair in values.iter() {
        let (raw_code, raw_metadata) = pair
        let code = match normalize_locale(raw_code, "locales") {
          Ok(value) => value
          Err(message) => return Err(message)
        }
        if find_locale_config(locales, code) is Some(_) {
          return Err("duplicate normalized locale: \{code}")
        }
        if locales.length() >= I18N_MAX_LOCALES {
          return Err("i18n config exceeds the \{I18N_MAX_LOCALES}-locale limit")
        }
        guard raw_metadata is Object(metadata) else {
          return Err("locale metadata must be an object: \{raw_code}")
        }
        let direction = match metadata.get("direction") {
          Some(String("rtl")) => "rtl"
          Some(String("ltr")) | None => "ltr"
          _ => return Err("locale direction must be ltr or rtl: \{raw_code}")
        }
        locales.push({ code, direction })
      }
    _ => return Err("locales must be an object")
  }
  if locales.is_empty() {
    return Err("locales must contain at least one locale")
  }
  locales.sort_by((left, right) => left.code.lexical_compare(right.code))
  match validate_locale_identifier_collisions(locales) {
    Ok(_) => ()
    Err(message) => return Err(message)
  }
  for
    pair in [
      ("sourceLocale", source_locale),
      ("defaultLocale", default_locale),
      ("fallbackLocale", fallback_locale),
    ] {
    if find_locale_config(locales, pair.1) is None {
      return Err("\{pair.0} is not declared in locales: \{pair.1}")
    }
  }
  for code in embedded_locales {
    if find_locale_config(locales, code) is None {
      return Err("embedded locale is not declared in locales: \{code}")
    }
  }
  let minimum_coverage = match obj.get("release") {
    Some(Object(release)) =>
      match release.get("minimumCoverage") {
        Some(Number(value, ..)) => value
        None => 1.0
        _ => return Err("release.minimumCoverage must be a number")
      }
    None => 1.0
    _ => return Err("release must be an object")
  }
  if minimum_coverage < 0.0 || minimum_coverage > 1.0 {
    return Err("release.minimumCoverage must be between 0 and 1")
  }
  Ok({
    message_profile,
    message_profile_explicit,
    source_locale,
    default_locale,
    fallback_locale,
    embedded_locales,
    locales,
    minimum_coverage,
  })
}

///|
/// Parses and validates the typed authoring schema JSON.
#warnings("-deprecated")
pub fn parse_schema(source : String) -> Result[Schema, String] {
  if @utf8.encode(source).length() > @runtime.CATALOG_MAX_SOURCE_BYTES {
    return Err("i18n schema exceeds the input size limit")
  }
  let json = try @json.parse(source, max_nesting_depth=64) catch {
    _ => return Err("invalid i18n schema JSON")
  } noraise {
    value => value
  }
  guard json is Object(obj) else {
    return Err("i18n schema root must be an object")
  }
  let param_map = match obj.get("params") {
    Some(Object(value)) => value
    None => {}
    _ => return Err("schema params must be an object")
  }
  let entries : Array[Entry] = []
  let seen_messages : Map[String, Bool] = Map([])
  match obj.get("messages") {
    Some(Object(group_map)) =>
      for pair in group_map.iter() {
        let (group, raw_keys) = pair
        match validate_resource_name("schema", "group", group) {
          Ok(_) => ()
          Err(message) => return Err(message)
        }
        guard raw_keys is Array(keys) else {
          return Err("schema message group must be an array: \{group}")
        }
        for raw_key in keys {
          guard raw_key is String(key) else {
            return Err("schema message key must be a string: \{group}")
          }
          match validate_resource_name("schema", "key", key) {
            Ok(_) => ()
            Err(message) => return Err(message)
          }
          let id = "\{group}.\{key}"
          if seen_messages.contains(id) {
            return Err("duplicate schema message: \{id}")
          }
          seen_messages[id] = true
          if entries.length() >= @runtime.CATALOG_MAX_MESSAGES {
            return Err(
              "i18n schema exceeds the \{@runtime.CATALOG_MAX_MESSAGES}-message limit",
            )
          }
          let params = match param_map.get(id) {
            Some(Array(values)) =>
              match parse_schema_params(id, values) {
                Ok(value) => value
                Err(message) => return Err(message)
              }
            None => []
            _ => return Err("schema params must be an array: \{id}")
          }
          entries.push({ group, key, text: "", params })
        }
      }
    _ => return Err("schema messages must be an object")
  }
  if entries.is_empty() {
    return Err("schema messages must contain at least one message")
  }
  entries.sort_by((left, right) => {
    message_id(left).lexical_compare(message_id(right))
  })
  match validate_identifier_collisions(entries) {
    Ok(_) => ()
    Err(message) => return Err(message)
  }
  for pair in param_map.iter() {
    if find_entry_by_id(entries, pair.0) is None {
      return Err("schema params reference unknown message: \{pair.0}")
    }
  }
  let descriptions : Array[(String, String)] = []
  match obj.get("descriptions") {
    Some(Object(values)) =>
      for pair in values.iter() {
        let (id, raw) = pair
        if find_entry_by_id(entries, id) is None {
          return Err("schema description references unknown message: \{id}")
        }
        match raw {
          String(value) => descriptions.push((id, value))
          _ => return Err("schema description must be a string: \{id}")
        }
      }
    None => ()
    _ => return Err("schema descriptions must be an object")
  }
  descriptions.sort_by((left, right) => left.0.lexical_compare(right.0))
  let parts : Array[(String, Array[String])] = []
  match obj.get("parts") {
    Some(Object(values)) =>
      for pair in values.iter() {
        let (id, raw_tags) = pair
        if find_entry_by_id(entries, id) is None {
          return Err("schema parts reference unknown message: \{id}")
        }
        guard raw_tags is Array(tags) else {
          return Err("schema parts must be an array: \{id}")
        }
        if tags.length() > I18N_MAX_PART_TAGS_PER_MESSAGE {
          return Err(
            "schema parts exceed the \{I18N_MAX_PART_TAGS_PER_MESSAGE}-tag limit: \{id}",
          )
        }
        let allowed : Array[String] = []
        let seen_tags : Map[String, Bool] = Map([])
        for raw_tag in tags {
          guard raw_tag is String(tag) else {
            return Err("schema part tag must be a string: \{id}")
          }
          match validate_part_tag(id, tag) {
            Ok(_) => ()
            Err(message) => return Err(message)
          }
          if seen_tags.contains(tag) {
            return Err("duplicate schema part tag: \{id}.\{tag}")
          }
          seen_tags[tag] = true
          allowed.push(tag)
        }
        allowed.sort_by((left, right) => left.lexical_compare(right))
        parts.push((id, allowed))
      }
    None => ()
    _ => return Err("schema parts must be an object")
  }
  parts.sort_by((left, right) => left.0.lexical_compare(right.0))
  Ok({ entries, descriptions, parts })
}

///|
/// Parses one locale JSON resource and validates every message against schema.
#warnings("-deprecated")
pub fn parse_locale(
  locale_code : String,
  source : String,
  schema : Schema,
  message_profile? : String = @runtime.CATALOG_PROFILE,
) -> Result[LocaleResource, String] {
  if @utf8.encode(source).length() > @runtime.CATALOG_MAX_SOURCE_BYTES {
    return Err("locale source exceeds the input size limit")
  }
  let locale = match normalize_locale(locale_code, "locale") {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let json = try @json.parse(source, max_nesting_depth=64) catch {
    _ => return Err("invalid JSON in \{locale}")
  } noraise {
    value => value
  }
  guard json is Object(groups) else {
    return Err("locale root must be an object: \{locale}")
  }
  let entries : Array[Entry] = []
  for pair in groups.iter() {
    let (group, raw_group) = pair
    if entries_for(schema.entries, group).is_empty() {
      return Err("unknown message group in \{locale}: \{group}")
    }
    guard raw_group is Object(items) else {
      return Err("group must be an object: \{locale}.\{group}")
    }
    for item in items.iter() {
      let (key, raw) = item
      let schema_entry = match find_entry(schema.entries, group, key) {
        Some(value) => value
        None => return Err("unknown message in \{locale}: \{group}.\{key}")
      }
      let text = match raw {
        String(value) => value
        Object(obj) =>
          match obj.get("text") {
            Some(String(value)) => value
            _ => return Err("missing text: \{locale}.\{group}.\{key}")
          }
        _ =>
          return Err(
            "entry must be a string or object: \{locale}.\{group}.\{key}",
          )
      }
      // Blank values are untranslated authoring placeholders. Omitting them
      // makes completeness and coverage reflect usable messages only.
      if text.trim().is_empty() {
        continue
      }
      if message_profile == @runtime.CATALOG_PROFILE {
        let params = schema_entry.params.map(param => @runtime.MessageParamSpec::{
          name: param.name,
          typ: param.typ,
        })
        let contract = @runtime.MessageContract::new(
          params,
          allowed_tags=schema_allowed_tags(schema, message_id(schema_entry)),
        )
        match @runtime.compile_mf2_message(text, contract) {
          Ok(_) => entries.push({ ..schema_entry, text, })
          Err(errors) =>
            return Err(
              "invalid MF2 message: \{locale}.\{group}.\{key}: \{errors[0].message}",
            )
        }
      } else if is_standard_authoring_profile(message_profile) {
        let model = match @runtime.parse_valid_mf2_model(text) {
          Ok(value) => value
          Err(errors) =>
            return Err(
              "invalid MF2 message: \{locale}.\{group}.\{key}: \{errors[0].message}",
            )
        }
        match
          validate_standard_message_contract(
            model, schema, schema_entry, message_profile,
          ) {
          Ok(_) => entries.push({ ..schema_entry, text, })
          Err(message) =>
            return Err(
              "invalid MF2 message: \{locale}.\{group}.\{key}: \{message}",
            )
        }
      } else {
        return Err("unsupported messageProfile: \{message_profile}")
      }
    }
  }
  entries.sort_by((left, right) => {
    message_id(left).lexical_compare(message_id(right))
  })
  Ok({ locale, entries })
}

///|
fn validate_standard_message_contract(
  model : @runtime.Mf2MessageModel,
  schema : Schema,
  schema_entry : Entry,
  message_profile : String,
) -> Result[Unit, String] {
  let parameter_names = schema_entry.params.map(param => param.name)
  let local_names : Array[String] = []
  let expressions : Array[@runtime.Mf2ModelExpression] = []
  let markups : Array[@runtime.Mf2ModelMarkup] = []
  let patterns : Array[@runtime.Mf2ModelPattern] = []
  let declarations = match model {
    @runtime.Mf2PatternMessage(declarations, pattern) => {
      patterns.push(pattern)
      declarations
    }
    @runtime.Mf2SelectMessage(declarations, _, variants) => {
      for variant in variants {
        patterns.push(variant.value)
      }
      declarations
    }
  }
  for declaration in declarations {
    match declaration {
      @runtime.Mf2ModelInput(name, expression) => {
        if !parameter_names.contains(name) {
          return Err(
            "input variable is not declared in schema params: $\{name}",
          )
        }
        expressions.push(expression)
      }
      @runtime.Mf2ModelLocal(name, expression) => {
        local_names.push(name)
        expressions.push(expression)
      }
    }
  }
  for pattern in patterns {
    for part in pattern.parts {
      match part {
        @runtime.Mf2ModelExpressionPart(expression) =>
          expressions.push(expression)
        @runtime.Mf2ModelMarkupPart(markup) => markups.push(markup)
        @runtime.Mf2ModelText(_) => ()
      }
    }
  }
  for expression in expressions {
    match
      validate_standard_value(expression.arg, parameter_names, local_names) {
      Ok(_) => ()
      Err(message) => return Err(message)
    }
    match expression.function_ref {
      Some(function_ref) => {
        if function_ref.name == "lampclaw:datetime" {
          return Err(
            "private function :lampclaw:datetime is not allowed by the standards profile; migrate to :datetime, :date, or :time",
          )
        }
        if !standard_function_name(
            function_ref.name,
            message_profile_allows_draft_datetime(message_profile),
          ) {
          if function_ref.name == "date" ||
            function_ref.name == "time" ||
            function_ref.name == "datetime" {
            return Err(
              "draft function :\{function_ref.name} requires messageProfile \{@runtime.MF2_EXPERIMENTAL_DATETIME_MESSAGE_PROFILE}",
            )
          }
          return Err(
            "function is not in the pinned default registry: :\{function_ref.name}",
          )
        }
        for option in function_ref.options {
          match
            validate_standard_value(
              Some(option.value),
              parameter_names,
              local_names,
            ) {
            Ok(_) => ()
            Err(message) => return Err(message)
          }
        }
      }
      None => ()
    }
  }
  let allowed_tags = schema_allowed_tags(schema, message_id(schema_entry))
  for markup in markups {
    if !allowed_tags.contains(markup.name) {
      return Err("markup is not declared in schema parts: \{markup.name}")
    }
    for option in markup.options {
      match
        validate_standard_value(
          Some(option.value),
          parameter_names,
          local_names,
        ) {
        Ok(_) => ()
        Err(message) => return Err(message)
      }
    }
  }
  Ok(())
}

///|
fn validate_standard_value(
  value : @runtime.Mf2ModelValue?,
  parameter_names : Array[String],
  local_names : Array[String],
) -> Result[Unit, String] {
  match value {
    Some(@runtime.Mf2ModelVariable(name)) =>
      if parameter_names.contains(name) || local_names.contains(name) {
        Ok(())
      } else {
        Err("variable is not declared in schema params: $\{name}")
      }
    _ => Ok(())
  }
}

///|
fn is_standard_authoring_profile(profile : String) -> Bool {
  profile == @runtime.MF2_STANDARD_MESSAGE_PROFILE ||
  profile == @runtime.MF2_LEGACY_STANDARD_MESSAGE_PROFILE ||
  profile == @runtime.MF2_EXPERIMENTAL_DATETIME_MESSAGE_PROFILE
}

///|
fn message_profile_allows_draft_datetime(profile : String) -> Bool {
  profile == @runtime.MF2_LEGACY_STANDARD_MESSAGE_PROFILE ||
  profile == @runtime.MF2_EXPERIMENTAL_DATETIME_MESSAGE_PROFILE
}

///|
fn standard_function_name(name : String, allow_draft_datetime : Bool) -> Bool {
  let stable = name == "string" ||
    name == "number" ||
    name == "integer" ||
    name == "offset" ||
    name == "currency" ||
    name == "percent"
  stable ||
  (
    allow_draft_datetime &&
    (name == "date" || name == "time" || name == "datetime")
  )
}

///|
fn parse_schema_params(
  id : String,
  values : Array[Json],
) -> Result[Array[Param], String] {
  if values.length() > I18N_MAX_PARAMS_PER_MESSAGE {
    return Err(
      "schema params exceed the \{I18N_MAX_PARAMS_PER_MESSAGE}-parameter limit: \{id}",
    )
  }
  let params : Array[Param] = []
  let seen_names : Map[String, Bool] = Map([])
  for value in values {
    guard value is Object(obj) else {
      return Err("schema param must be an object: \{id}")
    }
    let name = match obj.get("name") {
      Some(String(value)) => value
      _ => return Err("schema param name must be a string: \{id}")
    }
    match validate_param_name(id, name) {
      Ok(_) => ()
      Err(message) => return Err(message)
    }
    if seen_names.contains(name) {
      return Err("duplicate schema param: \{id}.\{name}")
    }
    seen_names[name] = true
    let typ = match obj.get("type") {
      Some(String(value)) => value
      _ => return Err("schema param type must be a string: \{id}.\{name}")
    }
    if !(typ == "String" ||
      typ == "Int" ||
      typ == "Double" ||
      typ == "Bool" ||
      typ == "InstantMillis") {
      return Err("unsupported schema param type: \{id}.\{name} uses \{typ}")
    }
    params.push({ name, typ })
  }
  Ok(params)
}

///|
fn normalized_config_string(
  obj : Map[String, Json],
  key : String,
) -> Result[String, String] {
  match obj.get(key) {
    Some(String(value)) => normalize_locale(value, key)
    _ => Err("\{key} must be a string")
  }
}

///|
fn normalize_locale(code : String, field : String) -> Result[String, String] {
  match @runtime.normalize_locale_code(code) {
    Ok(value) if starts_with_ascii_letter(value) => Ok(value)
    Ok(_) =>
      Err(
        "invalid locale in \{field}: locale code must start with an ASCII letter",
      )
    Err(message) => Err("invalid locale in \{field}: \{message}")
  }
}

///|
fn find_locale_config(
  locales : Array[LocaleConfig],
  code : String,
) -> LocaleConfig? {
  for locale in locales {
    if locale.code == code {
      return Some(locale)
    }
  }
  None
}

///|
fn find_entry(entries : Array[Entry], group : String, key : String) -> Entry? {
  find_entry_by_id(entries, "\{group}.\{key}")
}

///|
fn find_entry_by_id(entries : Array[Entry], id : String) -> Entry? {
  let mut low = 0
  let mut high = entries.length()
  while low < high {
    let middle = low + (high - low) / 2
    let comparison = message_id(entries[middle]).lexical_compare(id)
    if comparison < 0 {
      low = middle + 1
    } else {
      high = middle
    }
  }
  if low < entries.length() && message_id(entries[low]) == id {
    Some(entries[low])
  } else {
    None
  }
}

///|
fn message_id(entry : Entry) -> String {
  "\{entry.group}.\{entry.key}"
}

///|
fn schema_allowed_tags(schema : Schema, id : String) -> Array[String] {
  let mut low = 0
  let mut high = schema.parts.length()
  while low < high {
    let middle = low + (high - low) / 2
    if schema.parts[middle].0.lexical_compare(id) < 0 {
      low = middle + 1
    } else {
      high = middle
    }
  }
  if low < schema.parts.length() && schema.parts[low].0 == id {
    schema.parts[low].1
  } else {
    []
  }
}

///|
fn schema_is_parts(schema : Schema, id : String) -> Bool {
  for part in schema.parts {
    if part.0 == id {
      return true
    }
  }
  false
}

///|
fn validate_part_tag(id : String, tag : String) -> Result[Unit, String] {
  let chars = tag.to_array()
  if chars.is_empty() || !is_ascii_letter(chars[0]) {
    return Err("schema part tag must start with an ASCII letter: \{id}.\{tag}")
  }
  for char in chars {
    if !(is_ascii_letter(char) ||
      is_ascii_digit(char) ||
      char == '_' ||
      char == '-' ||
      char == '.' ||
      char == ':') {
      return Err("invalid schema part tag: \{id}.\{tag}")
    }
  }
  Ok(())
}
