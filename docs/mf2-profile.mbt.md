# MessageFormat profiles

[中文](mf2-profile.zh-CN.mbt.md)

Version `0.6.0` exposes three deliberately separate profiles:

- `lampclaw-mf2-strict-v1+lampclaw-datetime-v1` is the catalog, generator,
  generated-facade, and formatting profile used by existing applications.
- `unicode-mf2-ldml48.2-syntax-v1` parses and validates the complete pinned
  grammar and normative interchange data model.
- `unicode-mf2-ldml48.2-resolution-v1` adds declaration and option resolution,
  matcher selection, best-effort fallback, structured output, Unicode bidi
  isolation, and strict BCP 47 boundaries to that model.

This separation prevents standards work from silently changing existing
catalog meaning. Canonical JSON authoring and generated applications continue
to use strict-v1; explicit catalog `messageProfile` selection arrives in
`0.8.x`. The standalone APIs are documented in the
[syntax/data-model guide](mf2-syntax-data-model.mbt.md) and
[resolution/formatting guide](mf2-resolution-formatting.mbt.md).

The upstream comparison point is Unicode MessageFormat WG commit
[`d115a614079678850aac8b52742360e888b8f027`](https://github.com/unicode-org/message-format-wg/commit/d115a614079678850aac8b52742360e888b8f027),
dated 2026-06-11 and from the LDML 48.2 era. The immutable pin, vendored
fixtures, Unicode license, and machine-readable matrix live under
`tests/unicode-mf2/`. Locale canonicalization uses the separately pinned IANA
Language Subtag Registry snapshot dated 2026-08-08.

## Compatibility matrix

| Area | Existing catalog profile | Syntax profile | Resolution profile |
|---|---|---|---|
| Grammar | Strict line-oriented project subset | Complete pinned message ABNF | Same complete pinned model |
| Validity | Catalog compile/install failure | Separate parse and validity stages | Invalid models produce whole-message fallback plus errors |
| Declarations | Eager strict-v1 bindings | Retained in interchange data | Source-ordered, at-most-once resolution |
| Selection | Project ranking rules | Retained, not executed | Normative Match/BetterThan multi-selector algorithm |
| Runtime errors | Operation fails | Not applicable | Typed errors plus best-effort output and fallback values |
| Markup | Balanced legacy rich parts | Normative open/close/standalone model | Inert structured events preserving options and attributes |
| NFC | No full identifier/key normalization | Required names and duplicate detection | Required selector-key normalization |
| Locale | Legacy underscore-compatible normalization | Not applicable | Strict RFC 5646 canonicalization and RFC 4647 lookup |
| Bidi | Catalog direction metadata | Syntax controls accepted | Default LRI/RLI/FSI/PDI strategy and structured controls |
| Functions | Project subset and private datetime | References retained only | Unknown until the stable default/public registry in `0.7.x` |

## Conformance statement

The current release claims the pinned syntax, validity/data-model, and
resolution-core surfaces only. The vendored suite proves 114 well-formed
syntax cases, 133 syntax-error cases, 23 data-model cases, and 67 fallback,
pattern-selection, bidi, and Unicode-option cases on all four MoonBit
backends.

It does not claim full Unicode MessageFormat conformance. The stable default
function registry, JavaScript `Intl`/CLDR provider, public custom registry, and
complete function fixtures remain the `0.7.x` gate. Catalog authoring profile
selection, private-datetime migration, a normative requirement matrix, and
differential testing remain the `0.8.x` gate.

## Change discipline

All three identifiers are public compatibility contracts. The legacy catalog
identifier participates in every catalog contract hash. Any semantic expansion
or incompatible tightening changes the relevant identifier and updates the
matrix, pinned fixtures, tests, and both language versions of these documents
in one change. CI verifies generated fixture tests, the pinned MF2 sources,
the pinned IANA registry, profile claims, and archive contents.
