# MF2 default functions and registry

[中文](mf2-default-functions.zh-CN.mbt.md)

Version `0.7.0` added, and `0.8.0` integrates into generated authoring, the pinned registry profile
`unicode-mf2-ldml48.2-default-functions-v1` on top of the syntax and
resolution profiles. Its reference is Unicode MessageFormat WG commit
`d115a614079678850aac8b52742360e888b8f027` from the LDML 48.2 era.

## Supported repertoire

| Status in the pin | Functions | Current status |
|---|---|---|
| Stable and required | `:string`, `:number`, `:integer`, `:offset`, `:currency`, `:percent` | Implemented, including required operands, options, inheritance, formatting, and selection |
| Draft | `:date`, `:time`, `:datetime` | Implemented because the roadmap requires them, but excluded from the stable conformance claim |
| Draft and recommended | `:unit` | Deferred; resolves as an unknown function |

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

Numeric resolved values retain the applicable semantic options. A later
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

All 124 vendored upstream function cases pass on the Node 26 JavaScript
provider: 12 currency, 7 draft date, 7 draft datetime, 13 integer, 41 number,
16 offset, 13 percent, 9 string, and 6 draft time cases. The exact sources,
hashes, function prose, generated tests, and counts are checked in CI.

Version `0.8.0` completes the planned integration: explicit standards-mode
generated catalogs use this registry, private datetime is confined to the
compatibility profile, every stable function/option is present in the checked
requirement matrix, and Node 26 differential tests compare the behavior with
`messageformat@4.0.0`. This is still not a full Unicode MF2 claim because
draft functions remain separate and the final 1.0 stable target/public
contract freeze belongs to `0.9.x`.
