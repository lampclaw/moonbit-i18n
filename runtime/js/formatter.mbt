///|
extern "js" fn format_number_parts_js(
  locale : String,
  value : Double,
  names : Array[String],
  values : Array[String],
  include_parts : Bool,
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
  #|   const result = (parts) => [
  #|     "ok",
  #|     parts.map(part => part.value).join(""),
  #|     ...parts.flatMap(part => [part.type, part.value]),
  #|   ]
  #|   return (locale, value, names, values, includeParts) => {
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
  #|         "maximumSignificantDigits", "roundingIncrement",
  #|       ])
  #|       const choices = {
  #|         signDisplay: new Set(["auto", "always", "exceptZero", "negative", "never"]),
  #|         trailingZeroDisplay: new Set(["auto", "stripIfInteger"]),
  #|         roundingPriority: new Set(["auto", "morePrecision", "lessPrecision"]),
  #|         roundingMode: new Set([
  #|           "ceil", "floor", "expand", "trunc", "halfCeil", "halfFloor",
  #|           "halfExpand", "halfTrunc", "halfEven",
  #|         ]),
  #|         currencySign: new Set(["standard", "accounting"]),
  #|         currencyDisplay: new Set(["symbol", "narrowSymbol", "code", "name", "never"]),
  #|       }
  #|       let hideCurrency = false
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
  #|           if (!["auto", "always", "never", "min2", "true", "false"].includes(raw)) {
  #|             return ["invalid", "invalid useGrouping"]
  #|           }
  #|           options.useGrouping = raw === "never" || raw === "false"
  #|             ? false
  #|             : raw === "true" ? true : raw
  #|         } else if (name === "style") {
  #|           if (!["decimal", "currency", "percent"].includes(raw)) {
  #|             return ["invalid", "invalid number style"]
  #|           }
  #|           options.style = raw
  #|         } else if (name === "currency") {
  #|           if (!/^[A-Za-z]{3}$/.test(raw)) {
  #|             return ["invalid", "currency must be a three-letter code"]
  #|           }
  #|           options.currency = raw.toUpperCase()
  #|         } else if (Object.hasOwn(choices, name)) {
  #|           if (!choices[name].has(raw)) {
  #|             return ["invalid", `invalid ${name}`]
  #|           }
  #|           if (name === "currencyDisplay" && raw === "never") {
  #|             hideCurrency = true
  #|             options.currencyDisplay = "code"
  #|           } else {
  #|             options[name] = raw
  #|           }
  #|         } else {
  #|           return ["invalid", `unsupported number option: ${name}`]
  #|         }
  #|       }
  #|       const key = `${canonical}\u0000${JSON.stringify(options)}`
  #|       const instance = get(key, () => new Intl.NumberFormat(canonical, options))
  #|       if (!includeParts && !hideCurrency) {
  #|         return ["ok", instance.format(value)]
  #|       }
  #|       let parts = instance.formatToParts(value)
  #|       if (hideCurrency) {
  #|         const remove = new Set()
  #|         for (let i = 0; i < parts.length; i++) {
  #|           if (parts[i].type !== "currency") continue
  #|           remove.add(i)
  #|           if (i > 0 && parts[i - 1].type === "literal" && /^\s+$/.test(parts[i - 1].value)) {
  #|             remove.add(i - 1)
  #|           } else if (i + 1 < parts.length && parts[i + 1].type === "literal" && /^\s+$/.test(parts[i + 1].value)) {
  #|             remove.add(i + 1)
  #|           }
  #|         }
  #|         parts = parts.filter((_part, index) => !remove.has(index))
  #|       }
  #|       return result(parts)
  #|     } catch (error) {
  #|       const kind = error instanceof RangeError || error instanceof TypeError
  #|         ? "unsupported"
  #|         : "platform"
  #|       return [kind, error instanceof Error ? error.message : String(error)]
  #|     }
  #|   }
  #| })()

///|
extern "js" fn format_datetime_parts_js(
  locale : String,
  kind : String,
  raw_value : String,
  names : Array[String],
  values : Array[String],
  include_parts : Bool,
) -> Array[String] =
  #| (() => {
  #|   const cache = new Map()
  #|   const limit = 128
  #|   const componentChoices = {
  #|     weekday: new Set(["long", "short", "narrow"]),
  #|     year: new Set(["numeric", "2-digit"]),
  #|     month: new Set(["numeric", "2-digit", "long", "short", "narrow"]),
  #|     day: new Set(["numeric", "2-digit"]),
  #|     hour: new Set(["numeric", "2-digit"]),
  #|     minute: new Set(["numeric", "2-digit"]),
  #|     second: new Set(["numeric", "2-digit"]),
  #|     timeZoneName: new Set(["long", "short"]),
  #|   }
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
  #|   const localParts = (source) => {
  #|     const match = /^(\d{4})-(\d{2})-(\d{2})(?:T(\d{2}):(\d{2}):(\d{2})(?:\.(\d{1,3}))?)?$/.exec(source)
  #|     if (!match) return null
  #|     return {
  #|       year: Number(match[1]), month: Number(match[2]), day: Number(match[3]),
  #|       hour: Number(match[4] ?? 0), minute: Number(match[5] ?? 0),
  #|       second: Number(match[6] ?? 0), millisecond: Number((match[7] ?? "0").padEnd(3, "0")),
  #|     }
  #|   }
  #|   const wallDate = (source, timeZone) => {
  #|     const wanted = localParts(source)
  #|     if (!wanted) return null
  #|     const target = Date.UTC(
  #|       wanted.year, wanted.month - 1, wanted.day, wanted.hour,
  #|       wanted.minute, wanted.second, wanted.millisecond,
  #|     )
  #|     if (timeZone === "UTC" || timeZone === "Etc/UTC") return new Date(target)
  #|     const reader = new Intl.DateTimeFormat("en-CA-u-ca-iso8601", {
  #|       timeZone, year: "numeric", month: "2-digit", day: "2-digit",
  #|       hour: "2-digit", minute: "2-digit", second: "2-digit", hourCycle: "h23",
  #|     })
  #|     let guess = target
  #|     for (let pass = 0; pass < 4; pass++) {
  #|       const values = Object.fromEntries(
  #|         reader.formatToParts(new Date(guess))
  #|           .filter(part => part.type !== "literal")
  #|           .map(part => [part.type, Number(part.value)]),
  #|       )
  #|       const observed = Date.UTC(
  #|         values.year, values.month - 1, values.day, values.hour,
  #|         values.minute, values.second, wanted.millisecond,
  #|       )
  #|       const delta = target - observed
  #|       guess += delta
  #|       if (delta === 0) break
  #|     }
  #|     return new Date(guess)
  #|   }
  #|   return (locale, kind, rawValue, names, values, includeParts) => {
  #|     let canonical
  #|     try {
  #|       canonical = Intl.getCanonicalLocales(locale)[0]
  #|     } catch (error) {
  #|       return ["platform", error instanceof Error ? error.message : String(error)]
  #|     }
  #|     try {
  #|       const options = {}
  #|       for (let i = 0; i < names.length; i++) {
  #|         const name = names[i]
  #|         const raw = values[i]
  #|         if (Object.hasOwn(componentChoices, name)) {
  #|           if (!componentChoices[name].has(raw)) {
  #|             return ["invalid", `invalid ${name}`]
  #|           }
  #|           options[name] = raw
  #|         } else if (name === "timeZone") {
  #|           options.timeZone = raw
  #|         } else if (name === "hour12") {
  #|           if (raw !== "true" && raw !== "false") {
  #|             return ["invalid", "hour12 must be true or false"]
  #|           }
  #|           options.hour12 = raw === "true"
  #|         } else if (name === "calendar") {
  #|           options.calendar = raw
  #|         } else if (name === "dateStyle" || name === "timeStyle") {
  #|           if (!["full", "long", "medium", "short"].includes(raw)) {
  #|             return ["invalid", `invalid ${name}`]
  #|           }
  #|           options[name] = raw
  #|         } else if (name === "hourCycle") {
  #|           if (!["h11", "h12", "h23", "h24"].includes(raw)) {
  #|             return ["invalid", "invalid hourCycle"]
  #|           }
  #|           options.hourCycle = raw
  #|         } else {
  #|           return ["invalid", `unsupported date/time option: ${name}`]
  #|         }
  #|       }
  #|       let date
  #|       if (kind === "instant") {
  #|         const millis = Number(rawValue)
  #|         date = new Date(millis)
  #|         if (options.timeZone === "input") options.timeZone = "UTC"
  #|       } else {
  #|         const offset = /(Z|[+-]\d{2}:\d{2})$/.exec(rawValue)?.[1]
  #|         if (options.timeZone === "input") {
  #|           if (!offset) return ["invalid", "timeZone=input requires a zoned literal"]
  #|           options.timeZone = offset === "Z" ? "UTC" : offset
  #|         }
  #|         if (offset) {
  #|           date = new Date(rawValue)
  #|         } else {
  #|           date = wallDate(rawValue, options.timeZone ?? "UTC")
  #|         }
  #|       }
  #|       if (!(date instanceof Date) || Number.isNaN(date.getTime())) {
  #|         return ["invalid", "date/time operand is outside the JavaScript Date range"]
  #|       }
  #|       if (options.dateStyle === undefined && options.timeStyle === undefined &&
  #|           !Object.keys(options).some(key => Object.hasOwn(componentChoices, key))) {
  #|         options.year = "numeric"
  #|         options.month = "short"
  #|         options.day = "numeric"
  #|       }
  #|       if (options.timeZone === undefined) options.timeZone = "UTC"
  #|       const key = `${canonical}\u0000${JSON.stringify(options)}`
  #|       const instance = get(key, () => new Intl.DateTimeFormat(canonical, options))
  #|       if (!includeParts) return ["ok", instance.format(date)]
  #|       const parts = instance.formatToParts(date)
  #|       return [
  #|         "ok",
  #|         parts.map(part => part.value).join(""),
  #|         ...parts.flatMap(part => [part.type, part.value]),
  #|       ]
  #|     } catch (error) {
  #|       const kind = error instanceof RangeError || error instanceof TypeError
  #|         ? "invalid"
  #|         : "platform"
  #|       return [kind, error instanceof Error ? error.message : String(error)]
  #|     }
  #|   }
  #| })()

///|
extern "js" fn plural_category_options_js(
  locale : String,
  value : Double,
  ordinal : Bool,
  names : Array[String],
  values : Array[String],
) -> Array[String] =
  #| (() => {
  #|   const cache = new Map()
  #|   const limit = 128
  #|   const numeric = new Set([
  #|     "minimumIntegerDigits", "minimumFractionDigits", "maximumFractionDigits",
  #|     "minimumSignificantDigits", "maximumSignificantDigits", "roundingIncrement",
  #|   ])
  #|   const choices = {
  #|     roundingPriority: new Set(["auto", "morePrecision", "lessPrecision"]),
  #|     roundingMode: new Set([
  #|       "ceil", "floor", "expand", "trunc", "halfCeil", "halfFloor",
  #|       "halfExpand", "halfTrunc", "halfEven",
  #|     ]),
  #|   }
  #|   return (locale, value, ordinal, names, values) => {
  #|     try {
  #|       const canonical = Intl.getCanonicalLocales(locale)[0]
  #|       const options = { type: ordinal ? "ordinal" : "cardinal" }
  #|       for (let i = 0; i < names.length; i++) {
  #|         const name = names[i]
  #|         const raw = values[i]
  #|         if (numeric.has(name)) {
  #|           if (!/^(0|[1-9][0-9]*)$/.test(raw)) {
  #|             return ["invalid", `${name} must be a non-negative integer`]
  #|           }
  #|           options[name] = Number(raw)
  #|         } else if (Object.hasOwn(choices, name)) {
  #|           if (!choices[name].has(raw)) return ["invalid", `invalid ${name}`]
  #|           options[name] = raw
  #|         } else {
  #|           return ["invalid", `unsupported plural option: ${name}`]
  #|         }
  #|       }
  #|       const key = `${canonical}\u0000${JSON.stringify(options)}`
  #|       let instance = cache.get(key)
  #|       if (instance) {
  #|         cache.delete(key)
  #|         cache.set(key, instance)
  #|       } else {
  #|         instance = new Intl.PluralRules(canonical, options)
  #|         cache.set(key, instance)
  #|         if (cache.size > limit) cache.delete(cache.keys().next().value)
  #|       }
  #|       return ["ok", instance.select(value)]
  #|     } catch (error) {
  #|       const kind = error instanceof RangeError || error instanceof TypeError
  #|         ? "unsupported"
  #|         : "platform"
  #|       return [kind, error instanceof Error ? error.message : String(error)]
  #|     }
  #|   }
  #| })()

///|
fn formatter_output_result(
  raw : Array[String],
) -> Result[@runtime.FormatterOutput, @runtime.FormatterIssue] {
  if raw.length() < 2 {
    return Err(@runtime.PlatformFormatterFailure("invalid Intl bridge result"))
  }
  match raw[0] {
    "ok" => {
      let parts : Array[@runtime.FormatterPart] = []
      let mut index = 2
      while index + 1 < raw.length() {
        parts.push({ kind: raw[index], value: raw[index + 1] })
        index = index + 2
      }
      Ok({ value: raw[1], parts })
    }
    "invalid" => Err(@runtime.InvalidFormatterOption(raw[1]))
    "unsupported" => Err(@runtime.UnsupportedOperation(raw[1]))
    _ => Err(@runtime.PlatformFormatterFailure(raw[1]))
  }
}

///|
fn formatter_result(
  raw : Array[String],
) -> Result[String, @runtime.FormatterIssue] {
  match formatter_output_result(raw) {
    Ok(output) => Ok(output.value)
    Err(issue) => Err(issue)
  }
}

///|
fn number_parts(
  locale : String,
  value : Double,
  options : Array[@runtime.FormatOption],
) -> Result[@runtime.FormatterOutput, @runtime.FormatterIssue] {
  formatter_output_result(
    format_number_parts_js(
      locale,
      value,
      options.map(option => option.name),
      options.map(option => option.value),
      true,
    ),
  )
}

///|
fn number_text(
  locale : String,
  value : Double,
  options : Array[@runtime.FormatOption],
) -> Result[String, @runtime.FormatterIssue] {
  formatter_result(
    format_number_parts_js(
      locale,
      value,
      options.map(option => option.name),
      options.map(option => option.value),
      false,
    ),
  )
}

///|
fn datetime_parts(
  locale : String,
  value : @runtime.MessageValue,
  options : Array[@runtime.FormatOption],
) -> Result[@runtime.FormatterOutput, @runtime.FormatterIssue] {
  let (kind, raw) = match value {
    @runtime.InstantMillis(value) => ("instant", value.to_string())
    @runtime.TextValue(value) => ("literal", value)
    _ =>
      return Err(
        @runtime.InvalidFormatterOption(
          "date/time formatter requires InstantMillis or an ISO literal",
        ),
      )
  }
  formatter_output_result(
    format_datetime_parts_js(
      locale,
      kind,
      raw,
      options.map(option => option.name),
      options.map(option => option.value),
      true,
    ),
  )
}

///|
fn datetime_text(
  locale : String,
  value : Int64,
  options : Array[@runtime.FormatOption],
) -> Result[String, @runtime.FormatterIssue] {
  formatter_result(
    format_datetime_parts_js(
      locale,
      "instant",
      value.to_string(),
      options.map(option => option.name),
      options.map(option => option.value),
      false,
    ),
  )
}

///|
fn plural_result(
  locale : String,
  value : Double,
  ordinal : Bool,
  options : Array[@runtime.FormatOption],
) -> Result[String, @runtime.FormatterIssue] {
  formatter_result(
    plural_category_options_js(
      locale,
      value,
      ordinal,
      options.map(option => option.name),
      options.map(option => option.value),
    ),
  )
}

///|
/// Creates the JavaScript `Intl` formatter used by generated JS facades.
pub fn formatter() -> @runtime.Formatter {
  {
    format_number: (locale, value, options) => {
      number_text(locale, value, options)
    },
    format_datetime: (locale, value, options) => {
      datetime_text(locale, value, options)
    },
    plural_category: (locale, value, ordinal) => {
      plural_result(locale, value, ordinal, [])
    },
    format_number_to_parts: number_parts,
    format_datetime_value: datetime_parts,
    plural_category_with_options: plural_result,
  }
}

///|
/// Creates the pinned MF2 default registry backed by JavaScript `Intl`.
pub fn mf2_registry() -> @runtime.Mf2FunctionRegistry {
  @runtime.Mf2FunctionRegistry::new(formatter())
}

///|
/// Formats standalone MF2 source with the JavaScript `Intl` default registry.
pub fn format_mf2(
  source : String,
  context : @runtime.Mf2FormattingContext,
) -> @runtime.Mf2FormatResult {
  @runtime.format_mf2(source, context, mf2_registry())
}

///|
/// Formats a validated MF2 model with the JavaScript `Intl` default registry.
pub fn format_mf2_model(
  model : @runtime.Mf2MessageModel,
  context : @runtime.Mf2FormattingContext,
) -> @runtime.Mf2FormatResult {
  @runtime.format_mf2_model(model, context, mf2_registry())
}
