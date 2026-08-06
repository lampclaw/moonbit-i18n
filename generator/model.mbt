///|
pub(all) struct Param {
  name : String
  typ : String
} derive(Eq, Debug)

///|
pub(all) struct Entry {
  group : String
  key : String
  text : String
  params : Array[Param]
} derive(Eq, Debug)

///|
pub(all) struct Schema {
  entries : Array[Entry]
  descriptions : Array[(String, String)]
} derive(Eq, Debug)

///|
pub(all) struct LocaleConfig {
  code : String
  direction : String
} derive(Eq, Debug)

///|
pub(all) struct I18nConfig {
  source_locale : String
  default_locale : String
  fallback_locale : String
  embedded_locales : Array[String]
  locales : Array[LocaleConfig]
  minimum_coverage : Double
} derive(Eq, Debug)

///|
pub(all) struct LocaleSource {
  code : String
  source : String
} derive(Eq, Debug)

///|
pub(all) struct LocaleResource {
  locale : String
  entries : Array[Entry]
} derive(Eq, Debug)
