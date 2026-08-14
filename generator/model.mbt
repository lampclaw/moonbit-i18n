///|
/// Maximum number of locale resources accepted by one generator run.
pub const I18N_MAX_LOCALES : Int = 1000

///|
/// Maximum aggregate UTF-8 size of locale resources in one generator run.
pub const I18N_MAX_TOTAL_LOCALE_BYTES : Int = 67108864

///|
/// Maximum UTF-8 size of generated MoonBit source.
pub const I18N_MAX_GENERATED_CODE_BYTES : Int = 67108864

///|
/// Maximum typed parameters accepted by one generated message signature.
pub const I18N_MAX_PARAMS_PER_MESSAGE : Int = @runtime.MF2_MAX_CONTRACT_PARAMS

///|
/// Maximum rich-markup names accepted by one generated message contract.
pub const I18N_MAX_PART_TAGS_PER_MESSAGE : Int = @runtime.MF2_MAX_CONTRACT_TAGS

///|
/// A named parameter in the authoring schema.
pub(all) struct Param {
  /// Parameter name used by generated MoonBit and MF2 variables.
  name : String
  /// Supported generator type name.
  typ : String
} derive(Eq, Debug)

///|
/// One schema or locale message entry.
pub(all) struct Entry {
  /// Message group used in the dotted identifier and generated enum.
  group : String
  /// Message key within the group.
  key : String
  /// MF2 source; empty on schema-only entries.
  text : String
  /// Typed parameters declared for this message.
  params : Array[Param]
} derive(Eq, Debug)

///|
/// Canonical, validated message schema used by generation and tooling.
pub(all) struct Schema {
  /// Sorted message entries.
  entries : Array[Entry]
  /// Sorted dotted identifiers and translator-facing descriptions.
  descriptions : Array[(String, String)]
  /// Sorted dotted identifiers and allowed rich-markup names.
  parts : Array[(String, Array[String])]
} derive(Eq, Debug)

///|
/// One normalized locale declared by the generator configuration.
pub(all) struct LocaleConfig {
  /// Normalized locale code.
  code : String
  /// Text direction, `ltr` or `rtl`.
  direction : String
} derive(Eq, Debug)

///|
/// Canonical, validated generator configuration.
pub(all) struct I18nConfig {
  /// Catalog authoring/runtime profile selected for generated messages.
  message_profile : String
  /// Whether `messageProfile` was explicitly present in the source config.
  /// This distinguishes intentional compatibility mode from the temporary
  /// pre-1.0 default used for older projects.
  message_profile_explicit : Bool
  /// Locale that defines authoring completeness.
  source_locale : String
  /// Locale selected when negotiation finds no requested match.
  default_locale : String
  /// Locale used for missing-message fallback.
  fallback_locale : String
  /// Locales compiled directly into the generated facade.
  embedded_locales : Array[String]
  /// All supported locales and their directions.
  locales : Array[LocaleConfig]
  /// Minimum translated fraction required during release generation.
  minimum_coverage : Double
} derive(Eq, Debug)

///|
/// Raw locale resource supplied to the in-memory generator API.
pub(all) struct LocaleSource {
  /// Locale code associated with `source`.
  code : String
  /// UTF-8 JSON locale resource.
  source : String
} derive(Eq, Debug)

///|
/// Parsed and schema-validated locale resource.
pub(all) struct LocaleResource {
  /// Normalized locale code.
  locale : String
  /// Sorted translated entries present in this resource.
  entries : Array[Entry]
} derive(Eq, Debug)
