# MF2 default functions and registry

[中文](mf2-default-functions.zh-CN.mbt.md)

Version `0.7.0` added, `0.8.0` integrated, and `0.9.0` freezes the pinned
registry profile `unicode-mf2-ldml48.2-default-functions-v1` on top of the
syntax and resolution profiles. Its normative reference is official tag
`LDML48.2`, commit `7f142fb4f1f5ea6ab1eb34ce2b87e918ca9fd331`.

## Supported repertoire

| Status in the pin | Functions | Current status |
|---|---|---|
| Stable and required | `:string`, `:number`, `:integer`, `:offset`, `:currency`, `:percent` | Implemented, including required operands, options, inheritance, formatting, and selection |
| Draft | `:date`, `:time`, `:datetime` | Implemented only in `unicode-mf2-ldml48.2-js-v2+experimental-datetime-v1`; excluded from stable v2 |
| Draft and recommended | `:unit` | Deferred; resolves as an unknown function |

Stable generated authoring uses `unicode-mf2-ldml48.2-js-v2`; it rejects the
three Draft date/time functions. Applications that deliberately require those
functions must select the separately versioned experimental datetime profile.

The JavaScript provider uses Node 26 `Intl.NumberFormat`,
`Intl.PluralRules`, and `Intl.DateTimeFormat`. It preserves host
`formatToParts()` fields in `Mf2FormattedExpression.fields`. Currency display
`never`, semantic date/time field selection, floating ISO date/time values,
fixed offsets, and the context time zone have compatibility handling where a
direct `Intl` option is insufficient.

Native, Wasm, and Wasm-GC use `Formatter::basic()`. That portable provider
formats strings, plain decimal numbers, integers, and offsets. Operations that
need locale or CLDR data return `Mf2UnsupportedOperationCode`; they are not
silently approximated. These backends are not part of the JavaScript default
function conformance claim.

## JavaScript use

`runtime/js` owns the complete platform registry:

~~~moonbit
let context = match @runtime.Mf2FormattingContext::new(
  locale="en-US",
  inputs=[
    @runtime.Mf2Input::new("price", @runtime.DoubleValue(42.0)),
    @runtime.Mf2Input::new("count", @runtime.IntValue(2)),
  ],
  time_zone="UTC",
  bidi_isolation=@runtime.Mf2NoBidiIsolation,
) {
  Ok(value) => value
  Err(error) => abort(error.to_string())
}

let result = @runtime_js.format_mf2(
  ".input {$count :integer}\n{{{$price :currency currency=EUR} / {$count}}}",
  context,
)

println(result.value)
for error in result.errors {
  println(error.to_string())
}
~~~

Use `@runtime_js.mf2_registry()` when an application needs to add custom
functions before calling `@runtime.format_mf2`. `format_mf2_standalone` uses
the portable default registry and therefore does not provide CLDR output.

Numeric resolved values retain the applicable semantic options and inherit the
formatting context direction, preventing unnecessary isolation around
same-direction formatted values. A later
`:number`, `:integer`, `:offset`, `:currency`, or `:percent` expression applies
the pinned inheritance and discard rules. Numeric selectors try exact keys
before CLDR cardinal or ordinal categories. A non-literal `select` option is a
non-fatal bad option: formatting remains available, while selection is
disabled as required by the specification.

Date/time inputs may be `InstantMillis` or strict ISO date/time strings.
`Mf2FormattingContext.time_zone()` is the default zone and defaults to `UTC`.
The three date/time functions follow the pinned draft semantic-skeleton
options, so their API or output contract may change when Unicode stabilizes a
different repertoire.

## Portable custom functions

Custom identifiers must be namespaced, cannot use the reserved `u` namespace,
and cannot collide after NFC normalization. The registry receives typed raw
operands, lazy formatting, inherited metadata, resolved options, locale and
direction context, and optional selection callbacks:

~~~moonbit
let registry = @runtime_js.mf2_registry()
let echo = @runtime.Mf2FunctionHandler::new(
  name="app:echo",
  resolve=(_context, operand, _options) => {
    guard operand is Some(operand) else {
      return Err(@runtime.Mf2FunctionBadOperand("missing operand"))
    }
    Ok(
      @runtime.Mf2FunctionValue::new(
        raw=operand.raw(),
        direction=operand.direction(),
        format=() => operand.format(),
      ),
    )
  },
)

match registry.register_custom(echo) {
  Ok(_) => ()
  Err(message) => abort(message)
}

let result = @runtime.format_mf2(
  "{hello :app:echo}",
  context,
  registry,
)
~~~

Custom functions are application behavior and are always excluded from the
Unicode conformance statement. A custom handler reports one of the typed
`Mf2FunctionFailure` variants. It may also return non-fatal issues alongside a
usable value.

## Evidence and boundary

All 104 stable vendored function cases pass on the Node 26 JavaScript provider:
12 currency, 13 integer, 41 number, 16 offset, 13 percent, and 9 string. The
experimental profile separately passes 20 Draft cases: 7 date, 7 datetime, and
6 time. The exact sources, hashes, function prose, generated tests, and counts
are checked in CI and repeated in Chromium, Firefox, and WebKit.

Version `0.9.0` completes the conformance-candidate integration: stable v2
cannot accidentally author Draft functions, private datetime is confined to
the compatibility profile, all 6 stable functions and 40 stable options appear
in the 77-row anchored requirement matrix, and 20 stable differential cases
are separated from 4 experimental date/time cases. Draft and custom functions,
and non-JavaScript CLDR output, remain outside the stable claim.
