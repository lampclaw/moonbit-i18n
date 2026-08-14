# MessageFormat profiles

[中文](mf2-profile.zh-CN.mbt.md)

Version `0.7.0` exposes four deliberately separate profiles:

- `lampclaw-mf2-strict-v1+lampclaw-datetime-v1` is the unchanged catalog,
  generator, generated-facade, and formatting profile used by existing apps.
- `unicode-mf2-ldml48.2-syntax-v1` covers the complete pinned grammar and
  normative interchange data model.
- `unicode-mf2-ldml48.2-resolution-v1` adds declaration/option resolution,
  selection, fallback, structured output, bidi isolation, and strict BCP 47.
- `unicode-mf2-ldml48.2-default-functions-v1` adds the stable required
  default registry and the public custom-function boundary.

Keeping these contracts separate prevents standards work from silently
changing existing catalog meaning. Canonical JSON authoring and generated
applications still use strict-v1. Explicit catalog `messageProfile` selection
arrives in `0.8.x`.

The upstream point is Unicode MessageFormat WG commit
[`d115a614079678850aac8b52742360e888b8f027`](https://github.com/unicode-org/message-format-wg/commit/d115a614079678850aac8b52742360e888b8f027),
dated 2026-06-11 in the LDML 48.2 era. Immutable sources, hashes, fixtures,
the Unicode license, and the machine-readable profile live under
`tests/unicode-mf2/`. Locale canonicalization separately pins the IANA
Language Subtag Registry dated 2026-08-08.

## Compatibility matrix

| Area | Existing catalog | Syntax | Resolution | Default functions |
|---|---|---|---|---|
| Grammar | Strict project subset | Complete pinned message ABNF | Same model | Same model |
| Validity | Compile/install failure | Parse and validity stages | Whole-message fallback plus errors | Function errors plus usable best-effort values where normative |
| Declarations | Eager strict-v1 | Retained | Source-ordered, at most once | Typed values and option inheritance |
| Selection | Project ranking | Retained | Normative Match/BetterThan | String and numeric exact/plural/ordinal selectors |
| Parts | Legacy rich parts | Interchange data | Inert markup/options/attributes | Host number/date fields in expression parts |
| Unicode | Legacy locale compatibility | NFC names/duplicates | NFC keys, bidi, strict RFC 5646/4647 | Node 26 Intl/CLDR behavior on JavaScript |
| Functions | Project subset plus private datetime | References only | Provider boundary | Stable required defaults plus separately marked draft date/time |
| Extensions | Private catalog functions | Not executed | None public | Namespaced NFC-safe custom registry, excluded from conformance |

See the [syntax/data-model guide](mf2-syntax-data-model.mbt.md),
[resolution guide](mf2-resolution-formatting.mbt.md), and
[default-function guide](mf2-default-functions.mbt.md).

## Conformance statement

The JavaScript backend claims the pinned syntax, validity/data-model,
resolution core, and stable required default-function surfaces. Evidence is:

- 114 well-formed syntax, 133 syntax-error, and 23 data-model cases;
- 67 fallback, pattern-selection, bidi, and Unicode-option cases on Native,
  JavaScript, Wasm, and Wasm-GC; and
- all 124 pinned default-function cases on Node 26 JavaScript.

The stable repertoire is `:string`, `:number`, `:integer`, `:offset`,
`:currency`, and `:percent`. `:date`, `:time`, and `:datetime` are implemented
to satisfy the roadmap but are Draft in the pin and excluded from the stable
claim. Draft `:unit` is deferred. Native/Wasm CLDR output, catalog profile
selection, private-datetime migration, a normative requirement matrix, and
independent differential testing remain outside `0.7.0`.

Therefore `0.7.0` is a materially larger conformance surface, but it still
does not claim complete Unicode MessageFormat conformance.

## Change discipline

All four identifiers are compatibility contracts; the legacy catalog
identifier also participates in catalog contract hashes. A semantic expansion
or incompatible tightening must update its identifier, matrix, pinned
sources, generated tests, and both language versions of the documentation in
one change. CI verifies those relationships and the published archive.
