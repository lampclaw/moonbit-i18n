# Unicode MF2 syntax and interchange data model

[中文](mf2-syntax-data-model.zh-CN.mbt.md)

`0.5.0` adds the standalone profile
`unicode-mf2-ldml48.2-syntax-v1`, pinned to Unicode MessageFormat WG commit
`d115a614079678850aac8b52742360e888b8f027`. It is intended for tooling,
editors, converters, and future standards-mode authoring. It is separate from
the strict-v1 catalog formatter used by generated applications.

## Concepts

- **Well-formedness** means the source follows the complete pinned grammar.
  It says nothing about whether declaration data flow or selector variants are
  valid.
- **Validity** applies the additional data-model rules: declaration binding,
  selector annotation, key arity, fallback variants, and NFC-equivalent
  duplicate detection.
- The **interchange data model** is the specification's logical message tree.
  It removes source-only choices such as whether a literal needed quotes, and
  makes messages portable between parsers, translators, and converters.
- A **cooked literal** has already processed syntax escapes. Serializing it may
  choose a different but functionally equivalent quoted form.
- **NFC equivalence** means canonically equivalent Unicode names compare as the
  same name. Parsed names are normalized with Unicode 16 data; literal text is
  preserved.
- Markup is structural data, not HTML. The MF2 model permits unmatched open or
  close markup. A renderer must decide how to consume it safely.

## API flow

Use `parse_mf2_syntax` when an editor needs a tree even if the message is not
valid. Use `parse_valid_mf2_model` at an interchange or build boundary.

~~~moonbit
let source =
  ".input {$count :number}\n.match $count\none {{One}}\n* {{Other}}"

match @i18n.parse_valid_mf2_model(source) {
  Ok(model) => {
    let canonical_syntax = @i18n.serialize_mf2_model(model)
    let interchange_json = @i18n.mf2_model_to_json(model)
    // Store or transform either deterministic representation.
    ignore(canonical_syntax)
    ignore(interchange_json)
  }
  Err(errors) =>
    for error in errors {
      println(error.to_string())
    }
}
~~~

The public model includes `Mf2MessageModel`, declarations, patterns,
expressions, literal/variable values, functions, options, attributes, markup,
selectors, and variants. Source offsets are a Lampclaw extension and are not
written into normative JSON.

`serialize_mf2_model` emits deterministic, functionally equivalent syntax.
Pattern messages use quoted patterns so leading content can never be confused
with a complex-message keyword. Options and attributes are ordered
deterministically. The serializer validates public model values before writing
anything.

`mf2_model_to_json` and `parse_mf2_model_json` use the normative JSON field
names. Unknown object fields are ignored, as required for model extensions.
Invalid shapes, invalid names, invalid declaration relationships, and invalid
selector models are rejected. JSON output ends with one newline and is stable
for the same logical model.

## Error model

`Mf2Error.kind` provides the broad category and `Mf2Error.code` provides a
stable machine-readable reason. `0.5.0` distinguishes syntax errors plus the
pinned validity categories: variant-key mismatch, missing fallback variant,
missing selector annotation, duplicate declaration, duplicate option name,
and duplicate variant. Resource-limit failures have their own code.

These are parser and validity errors only. Unresolved variables, unknown
functions, bad operands/options/keys, formatting failures, and best-effort
fallback behavior become operational in `0.6.x` and `0.7.x`.

## Provenance and limits

The repository vendors the exact upstream Unicode-licensed `syntax.json`,
`syntax-errors.json`, and `data-model-errors.json` files. Generated MoonBit
tests cover all 114 accepted syntax cases, 133 rejected syntax cases, and 23
data-model cases. Sync and generation scripts verify the pinned commit and
SHA-256 digests; CI rejects stale generated tests.

The parser accepts at most 64 KiB per message, 4,096 declarations, 64
selectors, 4,096 variants, 65,536 parts per pattern model, and 64 options per
expression or markup item. Interchange JSON is also bounded and parsed with a
nesting limit. These implementation limits do not alter which grammar
productions are supported below the limits.

## Deliberate `0.5.0` boundary

This API does not resolve declarations, select variants, format values,
isolate bidirectional text, or invoke a function registry. It does not change
the meaning of existing locale JSON or catalog-v2 files. Applications should
continue using their generated facade until an explicit standards-mode
authoring profile is introduced in `0.8.x`.

Version `0.6.0` adds those target-independent resolution, selection, fallback,
structured-output, and bidi semantics through the separate
`unicode-mf2-ldml48.2-resolution-v1` profile. See the
[resolution guide](mf2-resolution-formatting.mbt.md). The syntax profile itself
remains parse/validate-only so its contract has not changed.
