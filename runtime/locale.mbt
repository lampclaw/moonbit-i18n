///|
/// Stable category for strict BCP 47 processing failures.
pub(all) enum LocaleErrorCode {
  /// The locale tag was empty.
  LocaleEmptyTagCode
  /// The locale tag did not match the RFC 5646 grammar.
  LocaleSyntaxCode
  /// A variant subtag occurred more than once.
  LocaleDuplicateVariantCode
  /// An extension singleton occurred more than once.
  LocaleDuplicateExtensionCode
  /// An extended-language subtag was not valid for its primary language.
  LocaleInvalidExtlangCode
  /// Two configured supported tags canonicalized to the same value.
  LocaleDuplicateSupportedCode
} derive(Eq, Debug)

///|
/// Structured strict-locale failure with the zero-based subtag position.
pub(all) struct LocaleError {
  /// Stable machine-readable failure code.
  code : LocaleErrorCode
  /// Human-readable diagnostic detail.
  message : String
  /// Zero-based subtag position, or zero for a whole-tag failure.
  subtag_index : Int
} derive(Eq, Debug)

///|
/// Formats a strict locale failure with its subtag position.
pub fn LocaleError::to_string(self : LocaleError) -> String {
  "\{self.message} (subtag \{self.subtag_index})"
}

///|
priv struct Bcp47Extension {
  singleton : String
  subtags : Array[String]
}

///|
fn locale_error(
  code : LocaleErrorCode,
  message : String,
  subtag_index : Int,
) -> LocaleError {
  { code, message, subtag_index }
}

///|
/// Canonicalizes one strict RFC 5646 language tag using the pinned IANA
/// Language Subtag Registry snapshot.
///
/// The operation rejects underscores, malformed extension/private-use
/// sequences, duplicate variants and duplicate extension singletons. It
/// applies whole-tag, language, extlang, region and variant Preferred-Value
/// mappings, removes registered extlang prefixes, sorts extensions by
/// singleton, and regularizes casing. Extension-specific canonicalization is
/// intentionally owned by each extension specification.
pub fn canonicalize_locale_tag(tag : String) -> Result[String, LocaleError] {
  if tag.is_empty() {
    return Err(
      locale_error(LocaleEmptyTagCode, "locale tag must not be empty", 0),
    )
  }
  if tag.contains("_") {
    return Err(
      locale_error(
        LocaleSyntaxCode,
        "strict BCP 47 locale tags must use '-' separators",
        0,
      ),
    )
  }
  for char in tag.to_array() {
    if !(locale_is_ascii_letter(char) ||
      locale_is_ascii_digit(char) ||
      char == '-') {
      return Err(
        locale_error(
          LocaleSyntaxCode,
          "locale tag contains a non-ASCII-alphanumeric subtag character",
          0,
        ),
      )
    }
  }
  let lower = tag.to_lower()
  match bcp47_preferred_whole_tag(lower) {
    Some(preferred) => return canonicalize_locale_tag(preferred)
    None => ()
  }
  match bcp47_fixed_grandfathered_tag(lower) {
    Some(canonical) => return Ok(canonical)
    None => ()
  }
  let parts : Array[String] = tag
    .split("-")
    .map(part => part.to_owned())
    .collect()
  if parts.is_empty() || parts.any(part => part.is_empty()) {
    return Err(
      locale_error(LocaleSyntaxCode, "locale tag contains an empty subtag", 0),
    )
  }
  if parts[0].to_lower() == "x" {
    if parts.length() == 1 {
      return Err(
        locale_error(
          LocaleSyntaxCode,
          "private-use singleton requires a following subtag",
          0,
        ),
      )
    }
    for i = 1; i < parts.length(); i = i + 1 {
      if !bcp47_valid_private_subtag(parts[i]) {
        return Err(
          locale_error(
            LocaleSyntaxCode,
            "invalid private-use locale subtag: \{parts[i]}",
            i,
          ),
        )
      }
    }
    return Ok(parts.map(part => part.to_lower()).join("-"))
  }
  if !bcp47_valid_language(parts[0]) {
    return Err(
      locale_error(
        LocaleSyntaxCode,
        "invalid primary language subtag: \{parts[0]}",
        0,
      ),
    )
  }
  let original_language = parts[0].to_lower()
  let mut language = bcp47_preferred_language(original_language)
  let mut cursor = 1
  let extlangs : Array[String] = []
  if original_language.length() <= 3 {
    while cursor < parts.length() &&
          parts[cursor].length() == 3 &&
          locale_part_is_ascii_alpha(parts[cursor]) &&
          extlangs.length() < 3 {
      extlangs.push(parts[cursor].to_lower())
      cursor = cursor + 1
    }
  }
  if extlangs.length() > 1 {
    return Err(
      locale_error(
        LocaleInvalidExtlangCode,
        "registered BCP 47 tags cannot contain multiple extlang subtags",
        2,
      ),
    )
  }
  if extlangs.length() == 1 {
    let extlang = extlangs[0]
    let prefix = bcp47_extlang_prefix(extlang)
    let preferred = bcp47_extlang_preferred(extlang)
    if prefix != Some(original_language) || preferred is None {
      return Err(
        locale_error(
          LocaleInvalidExtlangCode,
          "extlang \{extlang} is not registered for \{original_language}",
          1,
        ),
      )
    }
    guard preferred is Some(value) else { abort("checked extlang preferred") }
    language = value.to_lower()
  }
  let mut script : String? = None
  if cursor < parts.length() && bcp47_valid_script(parts[cursor]) {
    script = Some(ascii_title(bcp47_preferred_script(parts[cursor].to_lower())))
    cursor = cursor + 1
  }
  let mut region : String? = None
  if cursor < parts.length() && bcp47_valid_region(parts[cursor]) {
    region = Some(bcp47_preferred_region(parts[cursor].to_upper()))
    cursor = cursor + 1
  }
  let variants : Array[String] = []
  let seen_variants : Map[String, Bool] = Map([])
  while cursor < parts.length() && bcp47_valid_variant(parts[cursor]) {
    let variant = bcp47_preferred_variant(parts[cursor].to_lower())
    if seen_variants.contains(variant) {
      return Err(
        locale_error(
          LocaleDuplicateVariantCode,
          "duplicate locale variant: \{parts[cursor]}",
          cursor,
        ),
      )
    }
    seen_variants[variant] = true
    variants.push(variant)
    cursor = cursor + 1
  }
  let extensions : Array[Bcp47Extension] = []
  let seen_singletons : Map[String, Bool] = Map([])
  while cursor < parts.length() &&
        bcp47_valid_extension_singleton(parts[cursor]) {
    let singleton_index = cursor
    let singleton = parts[cursor].to_lower()
    if seen_singletons.contains(singleton) {
      return Err(
        locale_error(
          LocaleDuplicateExtensionCode,
          "duplicate locale extension singleton: \{parts[cursor]}",
          cursor,
        ),
      )
    }
    seen_singletons[singleton] = true
    cursor = cursor + 1
    let subtags : Array[String] = []
    while cursor < parts.length() && bcp47_valid_extension_subtag(parts[cursor]) {
      subtags.push(parts[cursor].to_lower())
      cursor = cursor + 1
    }
    if subtags.is_empty() {
      return Err(
        locale_error(
          LocaleSyntaxCode,
          "locale extension singleton requires a following subtag",
          singleton_index,
        ),
      )
    }
    extensions.push({ singleton, subtags })
  }
  let private_use : Array[String] = []
  if cursor < parts.length() && parts[cursor].to_lower() == "x" {
    let private_index = cursor
    cursor = cursor + 1
    while cursor < parts.length() && bcp47_valid_private_subtag(parts[cursor]) {
      private_use.push(parts[cursor].to_lower())
      cursor = cursor + 1
    }
    if private_use.is_empty() {
      return Err(
        locale_error(
          LocaleSyntaxCode,
          "private-use singleton requires a following subtag",
          private_index,
        ),
      )
    }
  }
  if cursor != parts.length() {
    return Err(
      locale_error(
        LocaleSyntaxCode,
        "invalid or misplaced locale subtag: \{parts[cursor]}",
        cursor,
      ),
    )
  }
  extensions.sort_by((left, right) => {
    left.singleton.lexical_compare(right.singleton)
  })
  let result : Array[String] = [language]
  match script {
    Some(value) => result.push(value)
    None => ()
  }
  match region {
    Some(value) => result.push(value)
    None => ()
  }
  for variant in variants {
    result.push(variant)
  }
  for extension in extensions {
    result.push(extension.singleton)
    for subtag in extension.subtags {
      result.push(subtag)
    }
  }
  if !private_use.is_empty() {
    result.push("x")
    for subtag in private_use {
      result.push(subtag)
    }
  }
  Ok(result.join("-"))
}

///|
/// Returns the RFC 4647 lookup sequence for one strict BCP 47 tag.
pub fn strict_locale_lookup_chain(
  tag : String,
) -> Result[Array[String], LocaleError] {
  let canonical = match canonicalize_locale_tag(tag) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  Ok(locale_chain_from_canonical(canonical))
}

///|
/// Performs strict RFC 4647 lookup over ordered requested and supported tags.
///
/// Every configured tag is validated and canonicalized. The `*` requested
/// range is skipped as required by lookup. If no request matches, the optional
/// canonical fallback is returned even when it is not in `supported`; `None`
/// means that the caller owns the no-match policy.
pub fn negotiate_locale_code(
  requested : Array[String],
  supported : Array[String],
  fallback? : String? = None,
) -> Result[String?, LocaleError] {
  let canonical_supported : Array[String] = []
  let seen : Map[String, Bool] = Map([])
  for i = 0; i < supported.length(); i = i + 1 {
    let canonical = match canonicalize_locale_tag(supported[i]) {
      Ok(value) => value
      Err(error) =>
        return Err({
          ..error,
          message: "invalid supported locale \{supported[i]}: \{error.message}",
        })
    }
    if seen.contains(canonical) {
      return Err(
        locale_error(
          LocaleDuplicateSupportedCode,
          "supported locales canonicalize to a duplicate: \{canonical}",
          i,
        ),
      )
    }
    seen[canonical] = true
    canonical_supported.push(canonical)
  }
  for request in requested {
    if request == "*" {
      continue
    }
    let chain = match strict_locale_lookup_chain(request) {
      Ok(value) => value
      Err(error) => return Err(error)
    }
    for candidate in chain {
      if canonical_supported.contains(candidate) {
        return Ok(Some(candidate))
      }
    }
  }
  match fallback {
    Some(value) =>
      match canonicalize_locale_tag(value) {
        Ok(canonical) => Ok(Some(canonical))
        Err(error) => Err(error)
      }
    None => Ok(None)
  }
}

///|
/// Normalizes a legacy project locale code.
///
/// This compatibility entry point accepts `_` separators and retains the
/// broad alphanumeric-subtag behavior shipped before 0.6. Strict MF2 and new
/// integrations should use `canonicalize_locale_tag` instead.
pub fn normalize_locale_code(code : String) -> Result[String, String] {
  let normalized = code.replace_all(old="_", new="-")
  match canonicalize_locale_tag(normalized) {
    Ok(value) => return Ok(value)
    Err(_) => ()
  }
  let parts : Array[String] = normalized
    .split("-")
    .map(part => part.to_owned())
    .collect()
  if parts.is_empty() || parts[0].is_empty() {
    return Err("locale code must not be empty")
  }
  let out : Array[String] = []
  for i = 0; i < parts.length(); i = i + 1 {
    let part = parts[i]
    if part.is_empty() || !locale_part_is_ascii_alnum(part) {
      return Err("invalid locale code: \{code}")
    }
    if i == 0 {
      out.push(ascii_lower(part))
    } else if part.length() == 4 {
      out.push(ascii_title(part))
    } else if part.length() == 2 || (part.length() == 3 && part_is_digits(part)) {
      out.push(ascii_upper(part))
    } else {
      out.push(ascii_lower(part))
    }
  }
  Ok(out.join("-"))
}

///|
/// Returns progressively less-specific RFC 4647 lookup candidates while
/// retaining the pre-0.6 compatibility input surface.
pub fn locale_lookup_chain(code : String) -> Array[String] {
  let normalized = match normalize_locale_code(code) {
    Ok(value) => value
    Err(_) => return []
  }
  locale_chain_from_canonical(normalized)
}

///|
/// Resolves ordered requested locales against supported locales and a default.
/// Invalid entries are skipped for compatibility. New integrations that need
/// explicit configuration failures should use `negotiate_locale_code`.
pub fn resolve_locale_code(
  requested : Array[String],
  supported : Array[String],
  fallback : String,
) -> String {
  let normalized_supported : Array[String] = []
  for code in supported {
    match normalize_locale_code(code) {
      Ok(value) if !normalized_supported.contains(value) =>
        normalized_supported.push(value)
      _ => ()
    }
  }
  for code in requested {
    for candidate in locale_lookup_chain(code) {
      if normalized_supported.contains(candidate) {
        return candidate
      }
    }
  }
  match normalize_locale_code(fallback) {
    Ok(value) if normalized_supported.contains(value) => value
    _ =>
      if normalized_supported.is_empty() {
        fallback
      } else {
        normalized_supported[0]
      }
  }
}

///|
fn locale_chain_from_canonical(canonical : String) -> Array[String] {
  let parts : Array[String] = canonical
    .split("-")
    .map(part => part.to_owned())
    .collect()
  let result : Array[String] = []
  let mut end = parts.length()
  while end > 0 {
    let candidate = parts[:end].to_owned().join("-")
    if !candidate.is_empty() && !result.contains(candidate) {
      result.push(candidate)
    }
    end = end - 1
    if end > 0 && parts[end - 1].length() == 1 {
      end = end - 1
    }
  }
  result
}

///|
fn bcp47_valid_language(value : String) -> Bool {
  locale_part_is_ascii_alpha(value) &&
  (value.length() >= 2 && value.length() <= 8) &&
  value.length() != 1
}

///|
fn bcp47_valid_script(value : String) -> Bool {
  value.length() == 4 && locale_part_is_ascii_alpha(value)
}

///|
fn bcp47_valid_region(value : String) -> Bool {
  (value.length() == 2 && locale_part_is_ascii_alpha(value)) ||
  (value.length() == 3 && part_is_digits(value))
}

///|
fn bcp47_valid_variant(value : String) -> Bool {
  if !locale_part_is_ascii_alnum(value) {
    return false
  }
  (value.length() >= 5 && value.length() <= 8) ||
  (value.length() == 4 && locale_is_ascii_digit(value.to_array()[0]))
}

///|
fn bcp47_valid_extension_singleton(value : String) -> Bool {
  value.length() == 1 &&
  value.to_lower() != "x" &&
  locale_part_is_ascii_alnum(value)
}

///|
fn bcp47_valid_extension_subtag(value : String) -> Bool {
  value.length() >= 2 &&
  value.length() <= 8 &&
  locale_part_is_ascii_alnum(value)
}

///|
fn bcp47_valid_private_subtag(value : String) -> Bool {
  value.length() >= 1 &&
  value.length() <= 8 &&
  locale_part_is_ascii_alnum(value)
}

///|
fn locale_part_is_ascii_alpha(value : String) -> Bool {
  if value.is_empty() {
    return false
  }
  for char in value.to_array() {
    if !locale_is_ascii_letter(char) {
      return false
    }
  }
  true
}

///|
fn locale_part_is_ascii_alnum(value : String) -> Bool {
  if value.is_empty() {
    return false
  }
  for char in value.to_array() {
    if !(locale_is_ascii_letter(char) || locale_is_ascii_digit(char)) {
      return false
    }
  }
  true
}

///|
fn part_is_digits(value : String) -> Bool {
  if value.is_empty() {
    return false
  }
  for char in value.to_array() {
    if !locale_is_ascii_digit(char) {
      return false
    }
  }
  true
}

///|
fn ascii_lower(value : String) -> String {
  value.to_lower()
}

///|
fn ascii_upper(value : String) -> String {
  value.to_upper()
}

///|
fn ascii_title(value : String) -> String {
  let chars = value.to_array()
  let out = StringBuilder::new()
  for i = 0; i < chars.length(); i = i + 1 {
    out.write_char(
      if i == 0 {
        chars[i].to_ascii_uppercase()
      } else {
        chars[i].to_ascii_lowercase()
      },
    )
  }
  out.to_string()
}

///|
fn locale_is_ascii_letter(char : Char) -> Bool {
  match char {
    'a'..='z' | 'A'..='Z' => true
    _ => false
  }
}

///|
fn locale_is_ascii_digit(char : Char) -> Bool {
  match char {
    '0'..='9' => true
    _ => false
  }
}
