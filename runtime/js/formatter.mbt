///|
extern "js" fn format_number_js(
  locale : String,
  value : Double,
  names : Array[String],
  values : Array[String],
) -> Array[String] =
  #| (() => {
  #|   const cache = new Map()
  #|   const limit = 128
  #|   const get = (key, create) => {
  #|     if (cache.has(key)) {
  #|       const value = cache.get(key)
  #|       cache.delete(key)
  #|       cache.set(key, value)
  #|       return value
  #|     }
  #|     const value = create()
  #|     cache.set(key, value)
  #|     if (cache.size > limit) cache.delete(cache.keys().next().value)
  #|     return value
  #|   }
  #|   return (locale, value, names, values) => {
  #|     let canonical
  #|     try {
  #|       canonical = Intl.getCanonicalLocales(locale)[0]
  #|     } catch (error) {
  #|       return ["platform", error instanceof Error ? error.message : String(error)]
  #|     }
  #|     try {
  #|       const options = {}
  #|       const numeric = new Set([
  #|         "minimumIntegerDigits", "minimumFractionDigits",
  #|         "maximumFractionDigits", "minimumSignificantDigits",
  #|         "maximumSignificantDigits",
  #|       ])
  #|       for (let i = 0; i < names.length; i++) {
  #|         const name = names[i]
  #|         const raw = values[i]
  #|         if (name === "integer") {
  #|           options.maximumFractionDigits = 0
  #|         } else if (numeric.has(name)) {
  #|           if (!/^(0|[1-9][0-9]*)$/.test(raw)) {
  #|             return ["invalid", `${name} must be a non-negative integer`]
  #|           }
  #|           options[name] = Number(raw)
  #|         } else if (name === "useGrouping") {
  #|           if (raw !== "true" && raw !== "false") {
  #|             return ["invalid", "useGrouping must be true or false"]
  #|           }
  #|           options.useGrouping = raw === "true"
  #|         } else if (name === "style") {
  #|           if (!new Set(["decimal", "currency", "percent"]).has(raw)) {
  #|             return ["invalid", "style must be decimal, currency, or percent"]
  #|           }
  #|           options.style = raw
  #|         } else if (name === "currency") {
  #|           if (!/^[A-Za-z]{3}$/.test(raw)) {
  #|             return ["invalid", "currency must be a three-letter code"]
  #|           }
  #|           options.currency = raw
  #|         } else if (name === "currencyDisplay") {
  #|           if (!new Set(["symbol", "narrowSymbol", "code", "name"]).has(raw)) {
  #|             return ["invalid", "invalid currencyDisplay"]
  #|           }
  #|           options.currencyDisplay = raw
  #|         } else {
  #|           return ["invalid", `unsupported number option: ${name}`]
  #|         }
  #|       }
  #|       const key = `${canonical}\u0000${JSON.stringify(options)}`
  #|       const instance = get(key, () => new Intl.NumberFormat(canonical, options))
  #|       return ["ok", instance.format(value)]
  #|     } catch (error) {
  #|       const kind = error instanceof RangeError || error instanceof TypeError
  #|         ? "invalid"
  #|         : "platform"
  #|       return [kind, error instanceof Error ? error.message : String(error)]
  #|     }
  #|   }
  #| })()

///|
extern "js" fn format_datetime_js(
  locale : String,
  value : Int64,
  names : Array[String],
  values : Array[String],
) -> Array[String] =
  #| (() => {
  #|   const cache = new Map()
  #|   const limit = 128
  #|   const allowed = new Set(["dateStyle", "timeStyle", "timeZone", "hourCycle"])
  #|   const get = (key, create) => {
  #|     if (cache.has(key)) {
  #|       const value = cache.get(key)
  #|       cache.delete(key)
  #|       cache.set(key, value)
  #|       return value
  #|     }
  #|     const value = create()
  #|     cache.set(key, value)
  #|     if (cache.size > limit) cache.delete(cache.keys().next().value)
  #|     return value
  #|   }
  #|   return (locale, value, names, values) => {
  #|     let canonical
  #|     try {
  #|       canonical = Intl.getCanonicalLocales(locale)[0]
  #|     } catch (error) {
  #|       return ["platform", error instanceof Error ? error.message : String(error)]
  #|     }
  #|     try {
  #|       const options = {}
  #|       for (let i = 0; i < names.length; i++) {
  #|         if (!allowed.has(names[i])) {
  #|           return ["invalid", `unsupported date/time option: ${names[i]}`]
  #|         }
  #|         const name = names[i]
  #|         const raw = values[i]
  #|         if ((name === "dateStyle" || name === "timeStyle") &&
  #|             !new Set(["full", "long", "medium", "short"]).has(raw)) {
  #|           return ["invalid", `${name} must be full, long, medium, or short`]
  #|         }
  #|         if (name === "hourCycle" &&
  #|             !new Set(["h11", "h12", "h23", "h24"]).has(raw)) {
  #|           return ["invalid", "hourCycle must be h11, h12, h23, or h24"]
  #|         }
  #|         options[name] = raw
  #|       }
  #|       if (options.dateStyle === undefined && options.timeStyle === undefined) {
  #|         options.dateStyle = "medium"
  #|       }
  #|       if (options.timeZone === undefined) options.timeZone = "UTC"
  #|       const millis = Number(value)
  #|       const date = new Date(millis)
  #|       if (!Number.isFinite(millis) || Number.isNaN(date.getTime())) {
  #|         return ["invalid", "InstantMillis is outside the JavaScript Date range"]
  #|       }
  #|       const key = `${canonical}\u0000${JSON.stringify(options)}`
  #|       const instance = get(key, () => new Intl.DateTimeFormat(canonical, options))
  #|       return ["ok", instance.format(date)]
  #|     } catch (error) {
  #|       const kind = error instanceof RangeError || error instanceof TypeError
  #|         ? "invalid"
  #|         : "platform"
  #|       return [kind, error instanceof Error ? error.message : String(error)]
  #|     }
  #|   }
  #| })()

///|
extern "js" fn plural_category_js(
  locale : String,
  value : Double,
  ordinal : Bool,
) -> Array[String] =
  #| (() => {
  #|   const cache = new Map()
  #|   const limit = 128
  #|   return (locale, value, ordinal) => {
  #|     try {
  #|       const canonical = Intl.getCanonicalLocales(locale)[0]
  #|       const key = `${canonical}\u0000${ordinal ? "ordinal" : "cardinal"}`
  #|       let instance = cache.get(key)
  #|       if (instance) {
  #|         cache.delete(key)
  #|         cache.set(key, instance)
  #|       } else {
  #|         instance = new Intl.PluralRules(canonical, {
  #|           type: ordinal ? "ordinal" : "cardinal",
  #|         })
  #|         cache.set(key, instance)
  #|         if (cache.size > limit) cache.delete(cache.keys().next().value)
  #|       }
  #|       return ["ok", instance.select(value)]
  #|     } catch (error) {
  #|       return ["platform", error instanceof Error ? error.message : String(error)]
  #|     }
  #|   }
  #| })()

///|
fn formatter_result(
  raw : Array[String],
) -> Result[String, @runtime.FormatterIssue] {
  if raw.length() < 2 {
    return Err(@runtime.PlatformFormatterFailure("invalid Intl bridge result"))
  }
  match raw[0] {
    "ok" => Ok(raw[1])
    "invalid" => Err(@runtime.InvalidFormatterOption(raw[1]))
    _ => Err(@runtime.PlatformFormatterFailure(raw[1]))
  }
}

///|
/// Creates the JavaScript `Intl` formatter used by generated JS facades.
pub fn formatter() -> @runtime.Formatter {
  {
    format_number: (locale, value, options) => {
      formatter_result(
        format_number_js(
          locale,
          value,
          options.map(option => option.name),
          options.map(option => option.value),
        ),
      )
    },
    format_datetime: (locale, value, options) => {
      formatter_result(
        format_datetime_js(
          locale,
          value,
          options.map(option => option.name),
          options.map(option => option.value),
        ),
      )
    },
    plural_category: (locale, value, ordinal) => {
      formatter_result(plural_category_js(locale, value, ordinal))
    },
  }
}
