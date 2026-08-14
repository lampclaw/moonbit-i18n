# MF2 resolution and formatting core

[中文](mf2-resolution-formatting.zh-CN.mbt.md)

The profile `unicode-mf2-ldml48.2-resolution-v1`, introduced in `0.6.0`,
remains the target-independent resolution core in `0.7.0`. It builds on the
pinned syntax/interchange model and now feeds the separately versioned
`unicode-mf2-ldml48.2-default-functions-v1` registry without changing the
existing catalog profile or canonical JSON authoring workflow.

This phase implements the target-independent semantics between parsing and the
default function registry:

- declarations are resolved in source order and each expression is evaluated
  at most once;
- literals, variables, options, `u:id`, and `u:dir` follow the pinned
  resolution rules;
- multi-selector variants use the normative Match/BetterThan comparison
  algorithm and NFC-normalized keys;
- syntax, data-model, resolution, and message-function errors remain
  discoverable while valid messages produce best-effort output;
- expression and whole-message fallback values use their normative printable
  representations;
- plain-text output uses the default Unicode bidi-isolation strategy unless a
  caller explicitly selects no isolation; and
- structured output retains markup, attributes, resolved options, IDs, value
  direction, and isolation controls as inert data.

`format_mf2_standalone` now uses the portable default registry. It handles
locale-neutral strings and basic numbers, while CLDR-dependent behavior emits
an explicit unsupported-operation error. JavaScript applications should use
`@runtime_js.format_mf2`, or pass `@runtime_js.mf2_registry()` to
`@runtime.format_mf2`, for complete Node 26 `Intl` behavior and public custom
functions. See the [default-function guide](mf2-default-functions.mbt.md).

## Basic use

Create a strict context, then format source or an already parsed model:

~~~moonbit
let context = match @runtime.Mf2FormattingContext::new(
  locale="en-US",
  inputs=[
    @runtime.Mf2Input::new(
      "name",
      @runtime.TextValue("MoonBit"),
      direction=@runtime.Mf2LeftToRight,
    ),
  ],
  direction=@runtime.Mf2LeftToRight,
) {
  Ok(value) => value
  Err(error) => abort(error.to_string())
}

let result = @runtime.format_mf2_standalone("Hello, {$name}!", context)
println(result.value)
for error in result.errors {
  println(error.to_string())
}
~~~

The default strategy omits isolation only when an expression is explicitly
left-to-right, the message is left-to-right, and `u:dir` did not require
isolation. It otherwise uses LRI, RLI, or FSI followed by PDI. Direction is
metadata supplied by the caller or a function provider; it is never guessed by
scanning formatted text. Use `Mf2NoBidiIsolation` only when the presentation
layer provides an equivalent isolation mechanism.

## Best-effort result contract

`Mf2FormatResult` always carries three fields:

- `value` is concatenated plain text; markup contributes an empty string;
- `parts` is a renderer-independent sequence of text, expression, markup, and
  bidi-isolation records; and
- `errors` is the deterministically ordered list discovered for that
  operation.

For example, a missing `$name` formats as `{$name}` and reports
`Mf2UnresolvedVariableCode`. A failed literal function operand formats as
`{|literal|}`. An invalid message formats as `{�}`, or uses the context's
non-empty message fallback inside braces. Syntax and data-model errors take
priority over runtime errors.

Markup is never executed. `Mf2FormattedMarkup` exposes its kind, identifier,
resolved inert options, source attributes, and optional `u:id`. The runtime
does not construct HTML, invoke callbacks, balance intentionally unbalanced
MF2 markup, or provide a DOM renderer. Applications must map known markup
identifiers through their own allowlisted renderer.

## BCP 47 and lookup boundaries

`canonicalize_locale_tag` is the strict entry point. It implements RFC 5646
syntax and canonicalization using the pinned IANA Language Subtag Registry
snapshot dated `2026-08-08`:

- whole-tag and subtag Preferred-Value mappings;
- registered extlang replacement and prefix validation;
- regularized language/script/region casing;
- duplicate variant and extension-singleton rejection;
- canonical extension ordering; and
- private-use preservation.

It rejects `_` separators. The earlier `normalize_locale_code` API retains its
wide underscore/alphanumeric compatibility surface for existing catalogs.
New standards-facing code should not use that compatibility behavior.

`strict_locale_lookup_chain` implements RFC 4647 lookup truncation, including
removing a singleton together with its nearest trailing subtag.
`negotiate_locale_code` canonicalizes every configured tag, rejects supported
tags that collide after canonicalization, processes each requested range in
order, skips `*`, and returns the caller-owned optional default only after all
requests fail. It does not infer linguistic fallback relationships.

The registry snapshot and its SHA-256 identity are available as
`BCP47_REGISTRY_DATE` and `BCP47_REGISTRY_SHA256`. Updating them requires a
reviewed registry diff and regeneration through
`scripts/sync-bcp47-registry.mjs`; runtime behavior never depends on live IANA
network access.

## Conformance and limits

The pin remains Unicode MessageFormat WG commit
`d115a614079678850aac8b52742360e888b8f027`. In addition to the 270 syntax and
data-model cases from `0.5.0`, all 67 pinned fallback, pattern-selection, bidi,
and Unicode-option cases pass on Native, JavaScript, Wasm, and Wasm-GC using
the test suite's specified conformance functions.

These cases continue to prove the named resolution-core profile. Version
`0.7.0` separately adds all 124 pinned default-function cases on Node 26,
stable required functions, structured host fields, and the public registry.
Catalog profile selection, a normative matrix, and independent differential
testing remain outside the claim.

Contexts accept at most 64 inputs. Source and formatted output are each
limited to 64 KiB, and the existing declaration, selector, variant, option,
and pattern-part limits still apply. A limit failure is reported and produces
the bounded whole-message fallback instead of partial unsafe output.
