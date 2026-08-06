///|
extern "js" fn format_number_js(
  locale : String,
  value : Double,
  names : Array[String],
  values : Array[String],
) -> String =
  #| (locale, value, names, values) => {
  #|   const options = {};
  #|   for (let i = 0; i < names.length; i++) {
  #|     const name = names[i];
  #|     const raw = values[i];
  #|     if (name === "integer") {
  #|       options.maximumFractionDigits = 0;
  #|     } else if (/^(minimum|maximum)(Fraction|Significant)Digits$/.test(name)) {
  #|       options[name] = Number(raw);
  #|     } else {
  #|       options[name] = raw;
  #|     }
  #|   }
  #|   return new Intl.NumberFormat(locale, options).format(value);
  #| }

///|
extern "js" fn format_datetime_js(
  locale : String,
  value : String,
  names : Array[String],
  values : Array[String],
) -> String =
  #| (locale, value, names, values) => {
  #|   const options = {};
  #|   for (let i = 0; i < names.length; i++) options[names[i]] = values[i];
  #|   const date = new Date(value);
  #|   if (Number.isNaN(date.getTime())) return value;
  #|   return new Intl.DateTimeFormat(locale, options).format(date);
  #| }

///|
extern "js" fn plural_category_js(
  locale : String,
  value : Double,
  ordinal : Bool,
) -> String =
  #| (locale, value, ordinal) => new Intl.PluralRules(
  #|   locale,
  #|   { type: ordinal ? "ordinal" : "cardinal" },
  #| ).select(value)

///|
pub fn formatter() -> @runtime.Formatter {
  {
    format_number: (locale, value, options) => {
      format_number_js(
        locale,
        value,
        options.map(option => option.name),
        options.map(option => option.value),
      )
    },
    format_datetime: (locale, value, options) => {
      format_datetime_js(
        locale,
        value,
        options.map(option => option.name),
        options.map(option => option.value),
      )
    },
    plural_category: (locale, value, ordinal) => {
      plural_category_js(locale, value, ordinal)
    },
  }
}
